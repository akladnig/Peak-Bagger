import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';

const naturalFeatureSourcePath =
    '/Volumes/Services/Features/tasmania_natural_features.json';

typedef NaturalFeatureFileReader = Future<String> Function(String path);
typedef NaturalFeatureMgrsConverter = PeakMgrsComponents Function(LatLng point);
typedef NaturalFeatureRefreshPersistence =
    void Function(List<NaturalFeature> features);
typedef NaturalFeatureDiagnosticLogger = void Function(String message);

class NaturalFeatureRefreshResult {
  const NaturalFeatureRefreshResult({
    required this.createdCount,
    required this.updatedCount,
    required this.protectedCount,
    required this.skippedCount,
  });

  final int createdCount;
  final int updatedCount;
  final int protectedCount;
  final int skippedCount;
}

/// Orchestrates app-isolate dependencies around the serializable source plan.
class NaturalFeatureRefreshService {
  NaturalFeatureRefreshService(
    this._repository, {
    NaturalFeatureFileReader? fileReader,
    NaturalFeatureMgrsConverter? mgrsConverter,
    NaturalFeatureRefreshPersistence? persistence,
    NaturalFeatureDiagnosticLogger? diagnosticLogger,
  }) : _fileReader = fileReader ?? _readSourceFile,
       _mgrsConverter = mgrsConverter ?? PeakMgrsConverter.fromLatLng,
       _persistence = persistence ?? _repositoryPersistence(_repository),
       _diagnosticLogger = diagnosticLogger ?? _discardDiagnostic;

  final NaturalFeatureRepository _repository;
  final NaturalFeatureFileReader _fileReader;
  final NaturalFeatureMgrsConverter _mgrsConverter;
  final NaturalFeatureRefreshPersistence _persistence;
  final NaturalFeatureDiagnosticLogger _diagnosticLogger;

  static Future<String> _readSourceFile(String path) =>
      File(path).readAsString();

  static NaturalFeatureRefreshPersistence _repositoryPersistence(
    NaturalFeatureRepository repository,
  ) {
    return repository.upsertAllAtomically;
  }

  static void _discardDiagnostic(String _) {}

  Future<NaturalFeatureRefreshResult> refresh() async {
    final sourceText = await _readSourceText();
    final stored = _repository.getAllNaturalFeatures();
    _ensureUniqueStoredIdentities(stored);
    final manualIdentities = stored
        .where((feature) => feature.sourceOfTruth == 'Manual')
        .map((feature) => _identity(feature.osmType, feature.osmId))
        .toList(growable: false);

    final workerResult = await Isolate.run<Map<String, Object?>>(
      () => buildNaturalFeatureRefreshPlan({
        'sourceText': sourceText,
        'manualIdentities': manualIdentities,
      }),
    );
    final geometryErrors = workerResult['geometryErrors']! as List<Object?>;
    for (final error in geometryErrors) {
      _diagnosticLogger(error! as String);
    }

    final existingByIdentity = <String, NaturalFeature>{
      for (final feature in stored)
        _identity(feature.osmType, feature.osmId): feature,
    };
    final upserts = <NaturalFeature>[];
    var skippedCount = workerResult['skippedCount']! as int;
    var createdCount = 0;
    var updatedCount = 0;
    final plannedFeatures = workerResult['features']! as List<Object?>;

    for (final rawFeature in plannedFeatures) {
      final feature = rawFeature! as Map<Object?, Object?>;
      final identity = feature['identity']! as String;
      final existing = existingByIdentity[identity];
      final mgrs = _convertMgrs(feature);
      if (mgrs == null) {
        skippedCount += 1;
        continue;
      }
      final sourceFeature = NaturalFeature(
        name: feature['name']! as String,
        altName: feature['altName']! as String,
        tag: feature['tag']! as String,
        country: 'Australia',
        county: '',
        region: 'Tasmania',
        latitude: (feature['latitude']! as num).toDouble(),
        longitude: (feature['longitude']! as num).toDouble(),
        gridZoneDesignator: mgrs.gridZoneDesignator,
        mgrs100kId: mgrs.mgrs100kId,
        easting: mgrs.easting,
        northing: mgrs.northing,
        osmId: feature['osmId']! as int,
        osmType: feature['osmType']! as String,
        sourceOfTruth: 'OSM',
      );
      if (existing == null) {
        upserts.add(sourceFeature);
        createdCount += 1;
      } else {
        upserts.add(_mergeExisting(existing, sourceFeature));
        updatedCount += 1;
      }
    }

    _persistence(upserts);
    return NaturalFeatureRefreshResult(
      createdCount: createdCount,
      updatedCount: updatedCount,
      protectedCount: workerResult['protectedCount']! as int,
      skippedCount: skippedCount,
    );
  }

  Future<String> _readSourceText() async {
    try {
      return await _fileReader(naturalFeatureSourcePath);
    } catch (_) {
      throw StateError(
        'Error refreshing natural features: source file is unavailable at '
        '$naturalFeatureSourcePath',
      );
    }
  }

  PeakMgrsComponents? _convertMgrs(Map<Object?, Object?> feature) {
    try {
      return _mgrsConverter(
        LatLng(
          (feature['latitude']! as num).toDouble(),
          (feature['longitude']! as num).toDouble(),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  NaturalFeature _mergeExisting(
    NaturalFeature existing,
    NaturalFeature source,
  ) {
    return NaturalFeature(
      id: existing.id,
      name: existing.altName.trim().isEmpty ? source.name : existing.name,
      altName: existing.altName,
      tag: source.tag,
      country: existing.country,
      county: existing.county,
      region: existing.region,
      latitude: source.latitude,
      longitude: source.longitude,
      gridZoneDesignator: source.gridZoneDesignator,
      mgrs100kId: source.mgrs100kId,
      easting: source.easting,
      northing: source.northing,
      osmId: source.osmId,
      osmType: source.osmType,
      sourceOfTruth: 'OSM',
    );
  }
}

String _identity(String osmType, int osmId) => '$osmType:$osmId';

void _ensureUniqueStoredIdentities(List<NaturalFeature> features) {
  final identities = <String>{};
  for (final feature in features) {
    if (!identities.add(_identity(feature.osmType, feature.osmId))) {
      throw StateError('Duplicate stored OSM feature identity');
    }
  }
}

/// Top-level isolate worker: accepts and returns only JSON-compatible values.
Map<String, Object?> buildNaturalFeatureRefreshPlan(
  Map<String, Object?> input,
) {
  final decoded = jsonDecode(input['sourceText']! as String);
  if (decoded is! Map || decoded['elements'] is! List) {
    throw const FormatException('Source JSON must contain an elements array');
  }
  final elements = decoded['elements']! as List;
  final manualIdentities = (input['manualIdentities']! as List<Object?>)
      .cast<String>()
      .toSet();
  final source = _NaturalFeatureSource(elements);
  final features = <Map<String, Object?>>[];
  final identities = <String>{};
  final geometryErrors = <Object?>[];
  var skippedCount = 0;
  var protectedCount = 0;

  for (final rawElement in elements) {
    final candidate = source.candidateFor(rawElement);
    if (candidate == null) {
      continue;
    }
    if (!candidate.isEligible) {
      skippedCount += 1;
      continue;
    }
    final identity = _identity(candidate.type!, candidate.osmId!);
    if (!identities.add(identity)) {
      throw StateError('Duplicate source OSM feature identity');
    }
    if (manualIdentities.contains(identity)) {
      protectedCount += 1;
      continue;
    }
    final geometry = source.geometryFor(candidate, geometryErrors);
    if (geometry == null) {
      skippedCount += 1;
      continue;
    }
    features.add({
      'identity': identity,
      'name': candidate.name!,
      'altName': candidate.altName,
      'tag': candidate.tag!,
      'latitude': geometry.latitude,
      'longitude': geometry.longitude,
      'osmId': candidate.osmId,
      'osmType': candidate.type,
    });
  }
  return {
    'features': features,
    'skippedCount': skippedCount,
    'protectedCount': protectedCount,
    'geometryErrors': geometryErrors,
  };
}

class _NaturalFeatureCandidate {
  const _NaturalFeatureCandidate({
    this.element,
    this.type,
    this.osmId,
    this.name,
    this.tag,
    this.altName = '',
  });

  final Map<Object?, Object?>? element;
  final String? type;
  final int? osmId;
  final String? name;
  final String? tag;
  final String altName;

  bool get isEligible =>
      element != null &&
      type != null &&
      osmId != null &&
      name != null &&
      tag != null;
}

class _NaturalFeatureSource {
  _NaturalFeatureSource(this.elements) {
    for (final rawElement in elements) {
      final element = _asObject(rawElement);
      if (element == null) {
        continue;
      }
      final type = element['type'];
      final id = _positiveId(element['id']);
      if (type == 'node' && id != null) {
        final point = _pointFromElement(element);
        if (point != null) {
          _nodes[id] = point;
        }
      } else if (type == 'way' && id != null) {
        final nodes = _nodeReferences(element['nodes']);
        if (nodes != null) {
          _ways[id] = nodes;
        }
      }
    }
  }

  final List elements;
  final Map<int, _Point> _nodes = {};
  final Map<int, List<int>> _ways = {};

  _NaturalFeatureCandidate? candidateFor(Object? rawElement) {
    final element = _asObject(rawElement);
    if (element == null) {
      return null;
    }
    final tags = _asObject(element['tags']);
    final name = _trimmedTag(tags, 'name');
    final natural = _trimmedTag(tags, 'natural');
    if (name == null && natural == null) {
      return null;
    }
    final type = element['type'];
    final supported = type == 'node' || type == 'way' || type == 'relation';
    if (!supported || name == null || natural == null) {
      return const _NaturalFeatureCandidate();
    }
    final id = _positiveId(element['id']);
    if (id == null) {
      return const _NaturalFeatureCandidate();
    }
    final water = _trimmedTag(tags, 'water');
    return _NaturalFeatureCandidate(
      element: element,
      type: type as String,
      osmId: id,
      name: name,
      tag: natural == 'water' ? (water ?? 'water') : natural,
      altName: _trimmedTag(tags, 'alt_name') ?? '',
    );
  }

  _Point? geometryFor(
    _NaturalFeatureCandidate candidate,
    List<Object?> geometryErrors,
  ) {
    switch (candidate.type) {
      case 'node':
        return _pointFromElement(candidate.element!);
      case 'way':
        return _centroidForWay(candidate.osmId!);
      case 'relation':
        return _centroidForRelation(candidate.element!, geometryErrors);
    }
    return null;
  }

  _Point? _centroidForWay(int id) {
    final coordinates = _coordinatesForWay(id);
    if (coordinates == null) {
      return null;
    }
    return _isClosed(coordinates)
        ? _areaCentroid(coordinates)
        : _lineCentroid(coordinates);
  }

  _Point? _centroidForRelation(
    Map<Object?, Object?> relation,
    List<Object?> geometryErrors,
  ) {
    final members = relation['members'];
    if (members is! List) {
      return null;
    }
    final isMultipolygon =
        _trimmedTag(_asObject(relation['tags']), 'type') == 'multipolygon';
    final wayMembers = <_RelationWayMember>[];
    for (final rawMember in members) {
      final member = _asObject(rawMember);
      if (member == null ||
          member['type'] is! String ||
          member['ref'] is! int) {
        return null;
      }
      final type = member['type']! as String;
      if (type == 'node' || type == 'relation') {
        continue;
      }
      if (type != 'way') {
        return null;
      }
      final role = member['role'];
      if (isMultipolygon &&
          (role is! String || (role != 'outer' && role != 'inner'))) {
        return null;
      }
      if (!isMultipolygon && role != null && role is! String) {
        return null;
      }
      final coordinates = _coordinatesForWay(member['ref']! as int);
      if (coordinates == null) {
        return null;
      }
      wayMembers.add(
        _RelationWayMember(role is String ? role : '', coordinates),
      );
    }
    if (wayMembers.isEmpty) {
      return null;
    }
    if (!isMultipolygon) {
      return _combinedLineCentroid(wayMembers.map((member) => member.points));
    }
    final outerRings = _stitchRings(
      wayMembers
          .where((member) => member.role == 'outer')
          .map((member) => member.points),
    );
    final innerRings = _stitchRings(
      wayMembers
          .where((member) => member.role == 'inner')
          .map((member) => member.points),
    );
    if (outerRings == null || innerRings == null || outerRings.isEmpty) {
      return null;
    }
    for (final inner in innerRings) {
      final containingOuters = outerRings
          .where((outer) => _strictlyContainsRing(outer, inner))
          .toList(growable: false);
      if (containingOuters.length != 1) {
        geometryErrors.add('Invalid multipolygon inner-ring boundary');
        return null;
      }
    }
    return _combinedAreaCentroid(outerRings, innerRings);
  }

  List<_Point>? _coordinatesForWay(int id) {
    final nodes = _ways[id];
    if (nodes == null) {
      return null;
    }
    final points = <_Point>[];
    for (final node in nodes) {
      final point = _nodes[node];
      if (point == null) {
        return null;
      }
      points.add(point);
    }
    return points;
  }
}

class _RelationWayMember {
  const _RelationWayMember(this.role, this.points);

  final String role;
  final List<_Point> points;
}

class _Point {
  const _Point(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool sameAs(_Point other) =>
      latitude == other.latitude && longitude == other.longitude;
}

Map<Object?, Object?>? _asObject(Object? value) =>
    value is Map ? Map<Object?, Object?>.from(value) : null;

String? _trimmedTag(Map<Object?, Object?>? tags, String key) {
  final value = tags?[key];
  if (value is! String) {
    return null;
  }
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

int? _positiveId(Object? value) {
  if (value is! int || value <= 0 || value > 9223372036854775807) {
    return null;
  }
  return value;
}

List<int>? _nodeReferences(Object? value) {
  if (value is! List || value.isEmpty || value.any((node) => node is! int)) {
    return null;
  }
  return value.cast<int>();
}

_Point? _pointFromElement(Map<Object?, Object?> element) {
  final latitude = element['lat'];
  final longitude = element['lon'];
  if (latitude is! num || longitude is! num) {
    return null;
  }
  final point = _Point(latitude.toDouble(), longitude.toDouble());
  if (!point.latitude.isFinite ||
      !point.longitude.isFinite ||
      point.latitude < -90 ||
      point.latitude > 90 ||
      point.longitude < -180 ||
      point.longitude > 180) {
    return null;
  }
  return point;
}

const _earthRadius = 6371008.8;
const _referenceLatitude = -42.0;
const _referenceLongitude = 146.0;

({double x, double y}) _project(_Point point) {
  final latitudeRadians = _referenceLatitude * math.pi / 180;
  return (
    x:
        _earthRadius *
        (point.longitude - _referenceLongitude) *
        math.pi /
        180 *
        math.cos(latitudeRadians),
    y: _earthRadius * (point.latitude - _referenceLatitude) * math.pi / 180,
  );
}

_Point _unproject(double x, double y) {
  final latitudeRadians = _referenceLatitude * math.pi / 180;
  return _Point(
    y * 180 / (_earthRadius * math.pi) + _referenceLatitude,
    x * 180 / (_earthRadius * math.pi * math.cos(latitudeRadians)) +
        _referenceLongitude,
  );
}

bool _isClosed(List<_Point> points) =>
    points.length >= 4 && points.first.sameAs(points.last);

_Point? _lineCentroid(List<_Point> points) {
  if (points.length < 2) {
    return null;
  }
  var length = 0.0;
  var x = 0.0;
  var y = 0.0;
  for (var index = 1; index < points.length; index++) {
    final first = _project(points[index - 1]);
    final second = _project(points[index]);
    final segmentLength = math.sqrt(
      math.pow(second.x - first.x, 2) + math.pow(second.y - first.y, 2),
    );
    if (segmentLength == 0) {
      continue;
    }
    length += segmentLength;
    x += (first.x + second.x) / 2 * segmentLength;
    y += (first.y + second.y) / 2 * segmentLength;
  }
  return length == 0 ? null : _unproject(x / length, y / length);
}

_Point? _combinedLineCentroid(Iterable<List<_Point>> lines) {
  var length = 0.0;
  var x = 0.0;
  var y = 0.0;
  for (final line in lines) {
    if (line.length < 2) {
      return null;
    }
    for (var index = 1; index < line.length; index++) {
      final first = _project(line[index - 1]);
      final second = _project(line[index]);
      final segmentLength = math.sqrt(
        math.pow(second.x - first.x, 2) + math.pow(second.y - first.y, 2),
      );
      if (segmentLength == 0) {
        continue;
      }
      length += segmentLength;
      x += (first.x + second.x) / 2 * segmentLength;
      y += (first.y + second.y) / 2 * segmentLength;
    }
  }
  return length == 0 ? null : _unproject(x / length, y / length);
}

_Point? _areaCentroid(List<_Point> ring) {
  if (!_isClosed(ring)) {
    return null;
  }
  final measurement = _ringMeasurement(ring);
  return measurement.area == 0 ? null : measurement.centroid;
}

({double area, _Point centroid}) _ringMeasurement(List<_Point> ring) {
  var twiceArea = 0.0;
  var x = 0.0;
  var y = 0.0;
  for (var index = 1; index < ring.length; index++) {
    final first = _project(ring[index - 1]);
    final second = _project(ring[index]);
    final cross = first.x * second.y - second.x * first.y;
    twiceArea += cross;
    x += (first.x + second.x) * cross;
    y += (first.y + second.y) * cross;
  }
  final signedArea = twiceArea / 2;
  return (
    area: signedArea.abs(),
    centroid: signedArea == 0
        ? const _Point(0, 0)
        : _unproject(x / (6 * signedArea), y / (6 * signedArea)),
  );
}

_Point? _combinedAreaCentroid(
  List<List<_Point>> outers,
  List<List<_Point>> inners,
) {
  var totalArea = 0.0;
  var latitude = 0.0;
  var longitude = 0.0;
  for (final ring in outers) {
    final measurement = _ringMeasurement(ring);
    if (measurement.area == 0) {
      return null;
    }
    totalArea += measurement.area;
    latitude += measurement.centroid.latitude * measurement.area;
    longitude += measurement.centroid.longitude * measurement.area;
  }
  for (final ring in inners) {
    final measurement = _ringMeasurement(ring);
    if (measurement.area == 0) {
      return null;
    }
    totalArea -= measurement.area;
    latitude -= measurement.centroid.latitude * measurement.area;
    longitude -= measurement.centroid.longitude * measurement.area;
  }
  return totalArea <= 0
      ? null
      : _Point(latitude / totalArea, longitude / totalArea);
}

List<List<_Point>>? _stitchRings(Iterable<List<_Point>> sequences) {
  final remaining = sequences.map(List<_Point>.from).toList(growable: true);
  final rings = <List<_Point>>[];
  while (remaining.isNotEmpty) {
    final ring = remaining.removeAt(0);
    if (ring.length < 2) {
      return null;
    }
    while (!_isClosed(ring)) {
      final end = ring.last;
      final start = ring.first;
      var matchIndex = -1;
      var attachment = _RingAttachment.append;
      for (var index = 0; index < remaining.length; index++) {
        final sequence = remaining[index];
        if (sequence.first.sameAs(end)) {
          matchIndex = index;
          break;
        }
        if (sequence.last.sameAs(end)) {
          matchIndex = index;
          attachment = _RingAttachment.appendReversed;
          break;
        }
        if (sequence.last.sameAs(start)) {
          matchIndex = index;
          attachment = _RingAttachment.prepend;
          break;
        }
        if (sequence.first.sameAs(start)) {
          matchIndex = index;
          attachment = _RingAttachment.prependReversed;
          break;
        }
      }
      if (matchIndex < 0) {
        return null;
      }
      final next = remaining.removeAt(matchIndex);
      switch (attachment) {
        case _RingAttachment.append:
          ring.addAll(next.skip(1));
        case _RingAttachment.appendReversed:
          ring.addAll(next.reversed.skip(1));
        case _RingAttachment.prepend:
          ring.insertAll(0, next.take(next.length - 1));
        case _RingAttachment.prependReversed:
          ring.insertAll(0, next.reversed.take(next.length - 1));
      }
    }
    if (_areaCentroid(ring) == null) {
      return null;
    }
    rings.add(ring);
  }
  return rings;
}

enum _RingAttachment { append, appendReversed, prepend, prependReversed }

bool _strictlyContainsRing(List<_Point> outer, List<_Point> inner) {
  for (var index = 0; index < inner.length - 1; index++) {
    if (!_strictlyContainsPoint(outer, inner[index])) {
      return false;
    }
  }
  for (var outerIndex = 1; outerIndex < outer.length; outerIndex++) {
    for (var innerIndex = 1; innerIndex < inner.length; innerIndex++) {
      if (_segmentsIntersect(
        outer[outerIndex - 1],
        outer[outerIndex],
        inner[innerIndex - 1],
        inner[innerIndex],
      )) {
        return false;
      }
    }
  }
  return true;
}

bool _strictlyContainsPoint(List<_Point> ring, _Point point) {
  final projectedPoint = _project(point);
  var inside = false;
  for (var index = 1; index < ring.length; index++) {
    final first = _project(ring[index - 1]);
    final second = _project(ring[index]);
    if (_pointOnSegment(projectedPoint, first, second)) {
      return false;
    }
    if ((first.y > projectedPoint.y) != (second.y > projectedPoint.y) &&
        projectedPoint.x <
            (second.x - first.x) *
                    (projectedPoint.y - first.y) /
                    (second.y - first.y) +
                first.x) {
      inside = !inside;
    }
  }
  return inside;
}

bool _segmentsIntersect(
  _Point firstStart,
  _Point firstEnd,
  _Point secondStart,
  _Point secondEnd,
) {
  final a = _project(firstStart);
  final b = _project(firstEnd);
  final c = _project(secondStart);
  final d = _project(secondEnd);
  final first = _orientation(a, b, c);
  final second = _orientation(a, b, d);
  final third = _orientation(c, d, a);
  final fourth = _orientation(c, d, b);
  return first * second <= 0 &&
      third * fourth <= 0 &&
      (_pointOnSegment(a, c, d) ||
          _pointOnSegment(b, c, d) ||
          _pointOnSegment(c, a, b) ||
          _pointOnSegment(d, a, b) ||
          (first * second < 0 && third * fourth < 0));
}

double _orientation(
  ({double x, double y}) first,
  ({double x, double y}) second,
  ({double x, double y}) third,
) =>
    (second.x - first.x) * (third.y - first.y) -
    (second.y - first.y) * (third.x - first.x);

bool _pointOnSegment(
  ({double x, double y}) point,
  ({double x, double y}) first,
  ({double x, double y}) second,
) {
  const epsilon = 1e-8;
  return _orientation(first, second, point).abs() < epsilon &&
      point.x >= math.min(first.x, second.x) - epsilon &&
      point.x <= math.max(first.x, second.x) + epsilon &&
      point.y >= math.min(first.y, second.y) - epsilon &&
      point.y <= math.max(first.y, second.y) + epsilon;
}
