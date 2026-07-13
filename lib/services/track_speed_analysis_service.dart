import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_motion_analyzer.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:xml/xml.dart';

enum TrackSpeedAnalysisSectionKind {
  trackType,
  hikingDifficulty,
  trackTypeAndHikingDifficulty,
  gradientBand,
}

class TrackSpeedAnalysisReport {
  const TrackSpeedAnalysisReport({required this.sections});

  final List<TrackSpeedAnalysisSection> sections;
}

class TrackSpeedAnalysisSection {
  const TrackSpeedAnalysisSection({required this.kind, required this.rows});

  final TrackSpeedAnalysisSectionKind kind;
  final List<TrackSpeedAnalysisRow> rows;
}

class TrackSpeedAnalysisRow {
  const TrackSpeedAnalysisRow({
    required this.label,
    required this.medianSpeedKmh,
    required this.sampleCount,
    required this.totalMovingDistanceMeters,
    required this.totalMovingTime,
    this.trackType,
    this.hikingDifficultyFamily,
    this.hikingDifficultyValue,
    this.gradientBand,
  });

  final String label;
  final double medianSpeedKmh;
  final int sampleCount;
  final double totalMovingDistanceMeters;
  final Duration totalMovingTime;
  final String? trackType;
  final String? hikingDifficultyFamily;
  final String? hikingDifficultyValue;
  final String? gradientBand;
}

class TrackSpeedAnalysisProgress {
  const TrackSpeedAnalysisProgress({
    required this.processedTracks,
    required this.totalTracks,
  });

  final int processedTracks;
  final int totalTracks;

  String get label => '$processedTracks of $totalTracks tracks processed';
}

class TrackSpeedAnalysisService {
  TrackSpeedAnalysisService({
    required this._gpxTrackRepository,
    required this._routeGraphQueryService,
    this._motionAnalyzer = const GpxTrackMotionAnalyzer(),
    GpxImporter? gpxTrackImporter,
  }) : _gpxTrackImporter = gpxTrackImporter ?? GpxImporter();

  static const _nearestWayToleranceMeters = 20.0;

  final GpxTrackRepository _gpxTrackRepository;
  final RouteGraphQueryService _routeGraphQueryService;
  final GpxTrackMotionAnalyzer _motionAnalyzer;
  final GpxImporter _gpxTrackImporter;

  TrackSpeedAnalysisReport analyze() {
    final tracks = _gpxTrackRepository.getAllTracks();
    final matcher = _RouteGraphNearestWayMatcher.fromQueryService(
      _routeGraphQueryService,
    );
    final observations = _collectObservations(
      tracks: tracks,
      matcher: matcher,
    );

    return _buildReport(observations);
  }

  Future<TrackSpeedAnalysisReport> analyzeWithProgress({
    void Function(TrackSpeedAnalysisProgress progress)? onProgress,
  }) async {
    final tracks = _gpxTrackRepository.getAllTracks();
    final matcher = _RouteGraphNearestWayMatcher.fromQueryService(
      _routeGraphQueryService,
    );
    final observations = <_TrackSpeedObservation>[];

    onProgress?.call(
      TrackSpeedAnalysisProgress(processedTracks: 0, totalTracks: tracks.length),
    );
    if (onProgress != null) {
      await Future<void>.delayed(Duration.zero);
    }

    for (var index = 0; index < tracks.length; index++) {
      observations.addAll(
        _observationsForTrack(track: tracks[index], matcher: matcher),
      );
      onProgress?.call(
        TrackSpeedAnalysisProgress(
          processedTracks: index + 1,
          totalTracks: tracks.length,
        ),
      );
      if (index < tracks.length - 1) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    return _buildReport(observations);
  }

  List<_TrackSpeedObservation> _collectObservations({
    required List<GpxTrack> tracks,
    required _RouteGraphNearestWayMatcher matcher,
  }) {
    final observations = <_TrackSpeedObservation>[];

    for (final track in tracks) {
      observations.addAll(_observationsForTrack(track: track, matcher: matcher));
    }

    return observations;
  }

  List<_TrackSpeedObservation> _observationsForTrack({
    required GpxTrack track,
    required _RouteGraphNearestWayMatcher matcher,
  }) {
    final source = _analysisSourceForTrack(track);
    if (source == null) {
      return const [];
    }

    final observations = <_TrackSpeedObservation>[];
    for (final leg in source.movingLegs) {
      if (!_isTasmanian(leg.startPoint.location) ||
          !_isTasmanian(leg.endPoint.location)) {
        continue;
      }

      final matchedWay = matcher.match(leg.midpoint);
      final trackType = _classifyTrackType(matchedWay?.row.highway);
      final difficulty = _classifyDifficulty(matchedWay);
      final gradientBand = _gradientBandFor(leg);
      final durationMillis = leg.duration.inMilliseconds;
      final speedKmh = durationMillis <= 0
          ? 0.0
          : leg.horizontalDistanceMeters * 3600 / durationMillis;

      observations.add(
        _TrackSpeedObservation(
          trackType: trackType,
          hikingDifficultyFamily: difficulty.family,
          hikingDifficultyValue: difficulty.value,
          gradientBand: gradientBand,
          speedKmh: speedKmh,
          movingDistanceMeters: leg.horizontalDistanceMeters,
          movingTime: leg.duration,
        ),
      );
    }

    return observations;
  }

  TrackSpeedAnalysisReport _buildReport(
    List<_TrackSpeedObservation> observations,
  ) {
    return TrackSpeedAnalysisReport(
      sections: [
        _buildTrackTypeSection(observations),
        _buildHikingDifficultySection(observations),
        _buildCombinedSection(observations),
        _buildGradientSection(observations),
      ],
    );
  }

  _TrackAnalysisSource? _analysisSourceForTrack(GpxTrack track) {
    final filteredTrack = track.filteredTrack.trim();
    if (filteredTrack.isNotEmpty) {
      final filteredSource = _trySourceXml(filteredTrack);
      if (filteredSource != null) {
        return filteredSource;
      }
    }

    final selection = _gpxTrackImporter.selectionForTrack(track);
    return _trySourceXml(selection.xml);
  }

  _TrackAnalysisSource? _trySourceXml(String xml) {
    try {
      final segments = _motionAnalyzer.extractSegmentsFromXml(xml);
      if (!_hasUsableTimedGeometry(segments)) {
        return null;
      }
      return _TrackAnalysisSource(
        movingLegs: _motionAnalyzer.extractMovingLegsForSegments(segments),
      );
    } on FormatException {
      return null;
    } on XmlException {
      return null;
    }
  }

  bool _hasUsableTimedGeometry(List<List<GpxTrackPoint>> segments) {
    for (final segment in segments) {
      final timedPoints = segment.where((point) => point.timeUtc != null).length;
      if (timedPoints >= 2) {
        return true;
      }
    }
    return false;
  }

  bool _isTasmanian(LatLng point) {
    return point.latitude >= GeoConstants.tasmaniaLatMin &&
        point.latitude <= GeoConstants.tasmaniaLatMax &&
        point.longitude >= GeoConstants.tasmaniaLngMin &&
        point.longitude <= GeoConstants.tasmaniaLngMax;
  }

  String _classifyTrackType(String? highway) {
    return switch (highway) {
      'path' => 'path',
      'footway' => 'footway',
      'steps' => 'steps',
      'track' => 'track',
      final value when _roadHighways.contains(value) => 'road',
      null => 'off-track',
      _ => 'other',
    };
  }

  _HikingDifficultyBucket _classifyDifficulty(_MatchedWay? matchedWay) {
    if (matchedWay == null) {
      return const _HikingDifficultyBucket(family: 'off-track', value: 'off-track');
    }

    final tags = matchedWay.tags;
    for (final family in _hikingDifficultyFamilyOrder) {
      if (family == 'off-track' || family == 'unknown') {
        continue;
      }
      final rawValue = tags[family];
      if (rawValue == null) {
        continue;
      }
      final normalized = rawValue.trim().toLowerCase();
      if (normalized.isEmpty) {
        continue;
      }
      return _HikingDifficultyBucket(family: family, value: normalized);
    }

    return const _HikingDifficultyBucket(family: 'unknown', value: 'unknown');
  }

  String _gradientBandFor(GpxMovingLeg leg) {
    if (leg.horizontalDistanceMeters <= 0) {
      return 'gradient unknown';
    }

    final startElevation = leg.startPoint.elevation;
    final endElevation = leg.endPoint.elevation;
    if (startElevation == null || endElevation == null) {
      return 'gradient unknown';
    }

    final grade = ((endElevation - startElevation) / leg.horizontalDistanceMeters) * 100;
    if (grade <= -20) {
      return '<= -20%';
    }
    if (grade < -10) {
      return '-20% to -10%';
    }
    if (grade < -5) {
      return '-10% to -5%';
    }
    if (grade < 5) {
      return '-5% to +5%';
    }
    if (grade < 10) {
      return '+5% to +10%';
    }
    if (grade < 20) {
      return '+10% to +20%';
    }
    return '>= +20%';
  }

  TrackSpeedAnalysisSection _buildTrackTypeSection(List<_TrackSpeedObservation> observations) {
    final grouped = <String, List<_TrackSpeedObservation>>{};
    for (final observation in observations) {
      (grouped[observation.trackType] ??= <_TrackSpeedObservation>[]).add(observation);
    }

    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) => _trackTypeOrder.indexOf(a).compareTo(_trackTypeOrder.indexOf(b)));
    return TrackSpeedAnalysisSection(
      kind: TrackSpeedAnalysisSectionKind.trackType,
      rows: keys.map((key) => _buildMetricsRow(grouped[key]!, label: key, trackType: key)).toList(growable: false),
    );
  }

  TrackSpeedAnalysisSection _buildHikingDifficultySection(List<_TrackSpeedObservation> observations) {
    final grouped = <(String, String), List<_TrackSpeedObservation>>{};
    for (final observation in observations) {
      final key = (observation.hikingDifficultyFamily, observation.hikingDifficultyValue);
      (grouped[key] ??= <_TrackSpeedObservation>[]).add(observation);
    }

    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) {
        final familyComparison = _hikingDifficultyFamilyOrder
            .indexOf(a.$1)
            .compareTo(_hikingDifficultyFamilyOrder.indexOf(b.$1));
        if (familyComparison != 0) {
          return familyComparison;
        }
        return a.$2.compareTo(b.$2);
      });
    return TrackSpeedAnalysisSection(
      kind: TrackSpeedAnalysisSectionKind.hikingDifficulty,
      rows: keys
          .map(
            (key) => _buildMetricsRow(
              grouped[key]!,
              label: _difficultyLabel(key.$1, key.$2),
              hikingDifficultyFamily: key.$1,
              hikingDifficultyValue: key.$2,
            ),
          )
          .toList(growable: false),
    );
  }

  TrackSpeedAnalysisSection _buildCombinedSection(List<_TrackSpeedObservation> observations) {
    final grouped = <(String, String, String), List<_TrackSpeedObservation>>{};
    for (final observation in observations) {
      final key = (
        observation.trackType,
        observation.hikingDifficultyFamily,
        observation.hikingDifficultyValue,
      );
      (grouped[key] ??= <_TrackSpeedObservation>[]).add(observation);
    }

    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) {
        final trackTypeComparison = _trackTypeOrder.indexOf(a.$1).compareTo(_trackTypeOrder.indexOf(b.$1));
        if (trackTypeComparison != 0) {
          return trackTypeComparison;
        }
        final familyComparison = _hikingDifficultyFamilyOrder
            .indexOf(a.$2)
            .compareTo(_hikingDifficultyFamilyOrder.indexOf(b.$2));
        if (familyComparison != 0) {
          return familyComparison;
        }
        return a.$3.compareTo(b.$3);
      });
    return TrackSpeedAnalysisSection(
      kind: TrackSpeedAnalysisSectionKind.trackTypeAndHikingDifficulty,
      rows: keys
          .map(
            (key) => _buildMetricsRow(
              grouped[key]!,
              label: '${key.$1} + ${_difficultyLabel(key.$2, key.$3)}',
              trackType: key.$1,
              hikingDifficultyFamily: key.$2,
              hikingDifficultyValue: key.$3,
            ),
          )
          .toList(growable: false),
    );
  }

  TrackSpeedAnalysisSection _buildGradientSection(List<_TrackSpeedObservation> observations) {
    final grouped = <String, List<_TrackSpeedObservation>>{};
    for (final observation in observations) {
      (grouped[observation.gradientBand] ??= <_TrackSpeedObservation>[]).add(observation);
    }

    final keys = grouped.keys.toList(growable: false)
      ..sort((a, b) => _gradientBandOrder.indexOf(a).compareTo(_gradientBandOrder.indexOf(b)));
    return TrackSpeedAnalysisSection(
      kind: TrackSpeedAnalysisSectionKind.gradientBand,
      rows: keys
          .map(
            (key) => _buildMetricsRow(
              grouped[key]!,
              label: key,
              gradientBand: key,
            ),
          )
          .toList(growable: false),
    );
  }

  TrackSpeedAnalysisRow _buildMetricsRow(
    List<_TrackSpeedObservation> observations, {
    required String label,
    String? trackType,
    String? hikingDifficultyFamily,
    String? hikingDifficultyValue,
    String? gradientBand,
  }) {
    final speeds = observations.map((observation) => observation.speedKmh).toList(growable: false)
      ..sort();
    final totalDistance = observations.fold<double>(
      0,
      (sum, observation) => sum + observation.movingDistanceMeters,
    );
    final totalMillis = observations.fold<int>(
      0,
      (sum, observation) => sum + observation.movingTime.inMilliseconds,
    );
    return TrackSpeedAnalysisRow(
      label: label,
      medianSpeedKmh: _median(speeds),
      sampleCount: observations.length,
      totalMovingDistanceMeters: totalDistance,
      totalMovingTime: Duration(milliseconds: totalMillis),
      trackType: trackType,
      hikingDifficultyFamily: hikingDifficultyFamily,
      hikingDifficultyValue: hikingDifficultyValue,
      gradientBand: gradientBand,
    );
  }

  double _median(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final middle = values.length ~/ 2;
    if (values.length.isOdd) {
      return values[middle];
    }
    return (values[middle - 1] + values[middle]) / 2;
  }

  String _difficultyLabel(String family, String value) {
    if (family == 'off-track' || family == 'unknown') {
      return value;
    }
    return '$family: $value';
  }
}

class _TrackAnalysisSource {
  const _TrackAnalysisSource({required this.movingLegs});

  final List<GpxMovingLeg> movingLegs;
}

class _TrackSpeedObservation {
  const _TrackSpeedObservation({
    required this.trackType,
    required this.hikingDifficultyFamily,
    required this.hikingDifficultyValue,
    required this.gradientBand,
    required this.speedKmh,
    required this.movingDistanceMeters,
    required this.movingTime,
  });

  final String trackType;
  final String hikingDifficultyFamily;
  final String hikingDifficultyValue;
  final String gradientBand;
  final double speedKmh;
  final double movingDistanceMeters;
  final Duration movingTime;
}

class _HikingDifficultyBucket {
  const _HikingDifficultyBucket({required this.family, required this.value});

  final String family;
  final String value;
}

class _MatchedWay {
  const _MatchedWay({required this.row, required this.tags});

  final RouteGraphWayIndex row;
  final Map<String, String> tags;
}

class _RouteGraphNearestWayMatcher {
  _RouteGraphNearestWayMatcher(this._chunkGroups);

  final List<_RouteGraphChunkWayGroup> _chunkGroups;

  factory _RouteGraphNearestWayMatcher.fromQueryService(
    RouteGraphQueryService queryService,
  ) {
    final chunks = queryService.queryChunksForBounds(
      minLat: GeoConstants.tasmaniaLatMin,
      minLon: GeoConstants.tasmaniaLngMin,
      maxLat: GeoConstants.tasmaniaLatMax,
      maxLon: GeoConstants.tasmaniaLngMax,
    );
    final rows = queryService.queryWays(const RouteGraphWayQuery());
    final rowsByWayId = <int, RouteGraphWayIndex>{for (final row in rows) row.osmWayId: row};
    final nodeById = <int, LatLng>{};
    final waysByChunkKey = <String, List<_RouteGraphWayGeometry>>{};

    for (final chunk in chunks) {
      final payload = chunk.decodePayload();
      final elements = payload['elements'];
      if (elements is! List) {
        continue;
      }

      for (final element in elements) {
        if (element is! Map) {
          continue;
        }
        final typed = Map<String, dynamic>.from(element.cast<String, dynamic>());
        if (typed['type'] != 'node') {
          continue;
        }
        final id = typed['id'];
        final lat = typed['lat'];
        final lon = typed['lon'];
        if (id is int && lat is num && lon is num) {
          nodeById[id] = LatLng(lat.toDouble(), lon.toDouble());
        }
      }
    }

    for (final chunk in chunks) {
      final payload = chunk.decodePayload();
      final elements = payload['elements'];
      if (elements is! List) {
        continue;
      }

      for (final element in elements) {
        if (element is! Map) {
          continue;
        }
        final typed = Map<String, dynamic>.from(element.cast<String, dynamic>());
        if (typed['type'] != 'way') {
          continue;
        }
        final wayId = typed['id'];
        final row = wayId is int ? rowsByWayId[wayId] : null;
        if (row == null) {
          continue;
        }
        final nodeIds = typed['nodes'];
        if (nodeIds is! List) {
          continue;
        }
        final points = <LatLng>[];
        for (final nodeId in nodeIds) {
          if (nodeId is! int) {
            continue;
          }
          final point = nodeById[nodeId];
          if (point != null) {
            points.add(point);
          }
        }
        if (points.length < 2) {
          continue;
        }
        (waysByChunkKey[chunk.chunkKey] ??= <_RouteGraphWayGeometry>[]).add(
          _RouteGraphWayGeometry.fromPoints(
            row: row,
            points: points,
            tags: _decodeTags(row.tagsJson),
          ),
        );
      }
    }

    final chunkGroups = <_RouteGraphChunkWayGroup>[];
    for (final chunk in chunks) {
      final ways = waysByChunkKey[chunk.chunkKey];
      if (ways == null || ways.isEmpty) {
        continue;
      }
      chunkGroups.add(_RouteGraphChunkWayGroup(chunk: chunk, ways: ways));
    }

    return _RouteGraphNearestWayMatcher(chunkGroups);
  }

  _MatchedWay? match(LatLng point) {
    _MatchedWay? bestMatch;
    var bestDistanceMeters = double.infinity;
    for (final chunkGroup in _chunkGroups) {
      if (!chunkGroup.contains(point, TrackSpeedAnalysisService._nearestWayToleranceMeters)) {
        continue;
      }
      for (final way in chunkGroup.ways) {
        if (!way.mightContainNearby(
          point,
          TrackSpeedAnalysisService._nearestWayToleranceMeters,
        )) {
          continue;
        }
        final distanceMeters = _distanceToWayMeters(point, way.points);
        if (distanceMeters > TrackSpeedAnalysisService._nearestWayToleranceMeters ||
            distanceMeters >= bestDistanceMeters) {
          continue;
        }
        bestDistanceMeters = distanceMeters;
        bestMatch = _MatchedWay(row: way.row, tags: way.tags);
      }
    }
    return bestMatch;
  }

  double _distanceToWayMeters(LatLng point, List<LatLng> wayPoints) {
    var bestDistance = double.infinity;
    for (var index = 0; index < wayPoints.length - 1; index++) {
      bestDistance = math.min(
        bestDistance,
        _distanceToSegmentMeters(point, wayPoints[index], wayPoints[index + 1]),
      );
    }
    return bestDistance;
  }

  double _distanceToSegmentMeters(LatLng point, LatLng start, LatLng end) {
    final latitudeRadians = point.latitude * math.pi / 180;
    const metersPerDegreeLatitude = 111320.0;
    final metersPerDegreeLongitude = metersPerDegreeLatitude * math.cos(latitudeRadians);

    final startX = (start.longitude - point.longitude) * metersPerDegreeLongitude;
    final startY = (start.latitude - point.latitude) * metersPerDegreeLatitude;
    final endX = (end.longitude - point.longitude) * metersPerDegreeLongitude;
    final endY = (end.latitude - point.latitude) * metersPerDegreeLatitude;

    final deltaX = endX - startX;
    final deltaY = endY - startY;
    final lengthSquared = deltaX * deltaX + deltaY * deltaY;
    if (lengthSquared == 0) {
      return math.sqrt(startX * startX + startY * startY);
    }

    final projection = (-(startX * deltaX) - (startY * deltaY)) / lengthSquared;
    final t = projection.clamp(0.0, 1.0);
    final closestX = startX + deltaX * t;
    final closestY = startY + deltaY * t;
    return math.sqrt(closestX * closestX + closestY * closestY);
  }

  static Map<String, String> _decodeTags(String tagsJson) {
    final decoded = jsonDecode(tagsJson);
    if (decoded is! Map) {
      return const {};
    }

    final tags = <String, String>{};
    for (final entry in decoded.entries) {
      if (entry.key is! String || entry.value == null) {
        continue;
      }
      tags[entry.key as String] = '${entry.value}';
    }
    return tags;
  }
}

class _RouteGraphWayGeometry {
  const _RouteGraphWayGeometry._({
    required this.row,
    required this.points,
    required this.tags,
    required this.minLat,
    required this.minLon,
    required this.maxLat,
    required this.maxLon,
  });

  factory _RouteGraphWayGeometry.fromPoints({
    required RouteGraphWayIndex row,
    required List<LatLng> points,
    required Map<String, String> tags,
  }) {
    var minLat = double.infinity;
    var minLon = double.infinity;
    var maxLat = -double.infinity;
    var maxLon = -double.infinity;
    for (final point in points) {
      minLat = math.min(minLat, point.latitude);
      minLon = math.min(minLon, point.longitude);
      maxLat = math.max(maxLat, point.latitude);
      maxLon = math.max(maxLon, point.longitude);
    }

    return _RouteGraphWayGeometry._(
      row: row,
      points: points,
      tags: tags,
      minLat: minLat,
      minLon: minLon,
      maxLat: maxLat,
      maxLon: maxLon,
    );
  }

  final RouteGraphWayIndex row;
  final List<LatLng> points;
  final Map<String, String> tags;
  final double minLat;
  final double minLon;
  final double maxLat;
  final double maxLon;

  bool mightContainNearby(LatLng point, double toleranceMeters) {
    final latitudeTolerance = toleranceMeters / 111320.0;
    final longitudeTolerance =
        toleranceMeters /
        (111320.0 * math.max(math.cos(point.latitude * math.pi / 180).abs(), 0.01));
    return point.latitude >= minLat - latitudeTolerance &&
        point.latitude <= maxLat + latitudeTolerance &&
        point.longitude >= minLon - longitudeTolerance &&
        point.longitude <= maxLon + longitudeTolerance;
  }
}

class _RouteGraphChunkWayGroup {
  const _RouteGraphChunkWayGroup({required this.chunk, required this.ways});

  final RouteGraphChunk chunk;
  final List<_RouteGraphWayGeometry> ways;

  bool contains(LatLng point, double toleranceMeters) {
    final latitudeTolerance = toleranceMeters / 111320.0;
    final longitudeTolerance =
        toleranceMeters /
        (111320.0 * math.max(math.cos(point.latitude * math.pi / 180).abs(), 0.01));
    return point.latitude >= chunk.minLat - latitudeTolerance &&
        point.latitude <= chunk.maxLat + latitudeTolerance &&
        point.longitude >= chunk.minLon - longitudeTolerance &&
        point.longitude <= chunk.maxLon + longitudeTolerance;
  }
}

const _roadHighways = <String>{
  'service',
  'unclassified',
  'residential',
  'tertiary',
  'secondary',
  'primary',
  'living_street',
};

const _trackTypeOrder = <String>[
  'path',
  'footway',
  'steps',
  'road',
  'track',
  'off-track',
  'other',
];

const _hikingDifficultyFamilyOrder = <String>[
  'sac_scale',
  'trail_visibility',
  'tracktype',
  'surface',
  'off-track',
  'unknown',
];

const _gradientBandOrder = <String>[
  '<= -20%',
  '-20% to -10%',
  '-10% to -5%',
  '-5% to +5%',
  '+5% to +10%',
  '+10% to +20%',
  '>= +20%',
  'gradient unknown',
];
