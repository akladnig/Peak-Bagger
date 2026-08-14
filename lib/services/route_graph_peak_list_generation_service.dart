import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/manifest_priority.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

typedef RouteGraphPeakListTextReader = Future<String> Function(String path);
typedef RouteGraphPeakListPathResolver = String Function();

abstract class RouteGraphPeakListFileSystem {
  Future<bool> directoryExists(String path);
  Future<void> writeText(String path, String contents);
  Future<void> rename(String sourcePath, String destinationPath);
  Future<void> deleteIfExists(String path);
}

class IoRouteGraphPeakListFileSystem implements RouteGraphPeakListFileSystem {
  const IoRouteGraphPeakListFileSystem();

  @override
  Future<void> deleteIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<void> rename(String sourcePath, String destinationPath) {
    return File(sourcePath).rename(destinationPath);
  }

  @override
  Future<void> writeText(String path, String contents) {
    return File(path).writeAsString(contents);
  }
}

class RouteGraphPeakListGenerationException implements Exception {
  const RouteGraphPeakListGenerationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RouteGraphPeakListGenerationResult {
  const RouteGraphPeakListGenerationResult({
    required this.outputPath,
    required this.matchedPeakCount,
    required this.regionKey,
  });

  final String outputPath;
  final int matchedPeakCount;
  final String regionKey;
}

class RouteGraphPeakListGenerationService {
  RouteGraphPeakListGenerationService({
    RouteGraphPeakListTextReader? textReader,
    RouteGraphPeakListFileSystem? fileSystem,
    RouteGraphPeakListPathResolver? homeDirectoryResolver,
    RouteGraphPeakListPathResolver? repositoryRootResolver,
    RouteGraphPeakListPathResolver? tempSuffixResolver,
  }) : _textReader = textReader ?? _readText,
       _fileSystem = fileSystem ?? const IoRouteGraphPeakListFileSystem(),
       _homeDirectoryResolver = homeDirectoryResolver ?? _resolveHomeDirectory,
       _repositoryRootResolver =
           repositoryRootResolver ?? _resolveRepositoryRoot,
       _tempSuffixResolver = tempSuffixResolver ?? _defaultTempSuffix;

  static const List<String> peakSourceHeaders = [
    'id',
    'osmId',
    'peakbaggerPid',
    'name',
    'altName',
    'elevation',
    'prominence',
    'country',
    'county',
    'range',
    'rating',
    'durationMinutes',
    'durationLabel',
    'difficulty',
    'viaFerrata',
    'notes',
    'latitude',
    'longitude',
    'region',
    'gridZoneDesignator',
    'mgrs100kId',
    'easting',
    'northing',
    'verified',
    'sourceOfTruth',
  ];

  static const _manifestAssetPath = 'assets/region_manifest.json';
  static const _thresholdMeters = 50.0;
  static const _distanceToleranceMeters = 1e-6;

  final RouteGraphPeakListTextReader _textReader;
  final RouteGraphPeakListFileSystem _fileSystem;
  final RouteGraphPeakListPathResolver _homeDirectoryResolver;
  final RouteGraphPeakListPathResolver _repositoryRootResolver;
  final RouteGraphPeakListPathResolver _tempSuffixResolver;

  Future<RouteGraphPeakListGenerationResult> generate({
    required String regionKey,
    String? peakSourcePath,
    String? outputPath,
  }) async {
    final repositoryRoot = _repositoryRootResolver();
    final manifest = await _loadManifest(repositoryRoot);
    final resolvedRegion = _resolveRegion(manifest, regionKey);
    final sourcePath = peakSourcePath ?? _defaultPeakSourcePath();
    final peaks = await _loadPeaks(sourcePath);
    final segments = <_RouteGraphSegment>[];
    for (final highwayPath in resolvedRegion.highwayPaths) {
      final path = p.join(repositoryRoot, highwayPath);
      segments.addAll(await _loadHighwaySegments(path, resolvedRegion.key));
    }

    final matched = <Peak>[];
    final matchedOsmIds = <int>{};
    for (final sourcePeak in peaks) {
      if (!resolvedRegion.eligibleSourceRegions.contains(sourcePeak.region) ||
          !matchedOsmIds.add(sourcePeak.peak.osmId)) {
        continue;
      }
      final peakLocation = Location(
        sourcePeak.peak.latitude,
        sourcePeak.peak.longitude,
      );
      if (segments.any(
        (segment) =>
            distanceFromSegment(peakLocation, segment.start, segment.end)! <=
            _thresholdMeters + _distanceToleranceMeters,
      )) {
        matched.add(sourcePeak.peak);
      } else {
        matchedOsmIds.remove(sourcePeak.peak.osmId);
      }
    }
    matched.sort(PeakListCsvExportService.comparePeaksForCsv);
    final csvText = const CsvEncoder(lineDelimiter: '\n').convert([
      PeakListCsvExportService.csvHeaders,
      ...matched.map(
        (peak) => PeakListCsvExportService.csvRowForPeak(peak, points: 1),
      ),
    ]);

    final targetPath = outputPath ?? _defaultOutputPath(resolvedRegion.key);
    await _writeAtomically(targetPath, csvText, resolvedRegion.key);
    return RouteGraphPeakListGenerationResult(
      outputPath: targetPath,
      matchedPeakCount: matched.length,
      regionKey: resolvedRegion.key,
    );
  }

  Future<List<String>> supportedRegionKeys() async {
    final manifest = await _loadManifest(_repositoryRootResolver());
    final supportedKeys = <String>[];
    for (final region in manifest.values) {
      try {
        _resolveRegion(manifest, region.key);
        supportedKeys.add(region.key);
      } on RouteGraphPeakListGenerationException {
        // A manifest region without usable highways is intentionally omitted.
      }
    }
    supportedKeys.sort();
    return List.unmodifiable(supportedKeys);
  }

  Future<Map<String, _ManifestRegion>> _loadManifest(
    String repositoryRoot,
  ) async {
    final manifestPath = p.join(repositoryRoot, _manifestAssetPath);
    final rawJson = await _readRequiredText(
      manifestPath,
      'Could not read region manifest at $manifestPath',
    );
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) {
        throw const FormatException('expected a top-level object');
      }
      final regions = <String, _ManifestRegion>{};
      for (final entry in decoded.entries) {
        if (entry.key is! String || entry.value is! Map) {
          throw const FormatException(
            'each region must be an object keyed by name',
          );
        }
        final key = _normalize(entry.key as String);
        if (key.isEmpty) {
          throw const FormatException('region key is blank');
        }
        final value = Map<Object?, Object?>.from(entry.value as Map);
        final priority = value['priority'];
        if (priority is! String) {
          throw FormatException('region $key has no priority');
        }
        final highways = _readStringList(value['highways'], 'highways', key);
        final aliases = _readStringList(
          value['peakListFilterAliases'],
          'peakListFilterAliases',
          key,
        ).map(_normalize).where((value) => value.isNotEmpty).toSet();
        regions[key] = _ManifestRegion(
          key: key,
          priority: ManifestPriority.parse(priority, regionKey: key),
          isComposite: value['composite'] == true,
          highways: highways,
          aliases: aliases,
        );
      }
      return regions;
    } on RouteGraphPeakListGenerationException {
      rethrow;
    } catch (error) {
      throw RouteGraphPeakListGenerationException(
        'Could not parse region manifest at $manifestPath: $error',
      );
    }
  }

  _ResolvedRegion _resolveRegion(
    Map<String, _ManifestRegion> manifest,
    String selectedKey,
  ) {
    final canonicalKey = _normalize(selectedKey);
    final selected = manifest[canonicalKey];
    if (selected == null) {
      throw RouteGraphPeakListGenerationException(
        'Unknown route-graph region "$selectedKey".',
      );
    }
    final effectivePaths = _effectiveHighwayPaths(manifest, selected);
    if (effectivePaths.isEmpty) {
      throw RouteGraphPeakListGenerationException(
        'Region ${selected.key} has no effective highways declaration.',
      );
    }
    final eligibleSourceRegions = <String>{};
    if (!selected.isComposite) {
      eligibleSourceRegions.add(selected.key);
      eligibleSourceRegions.addAll(selected.aliases);
    } else {
      final selectedPaths = effectivePaths.toSet();
      for (final region in manifest.values.where(
        (region) => !region.isComposite,
      )) {
        final paths = _effectiveHighwayPaths(manifest, region);
        if (paths.isNotEmpty && paths.every(selectedPaths.contains)) {
          eligibleSourceRegions.add(region.key);
          eligibleSourceRegions.addAll(region.aliases);
        }
      }
    }
    return _ResolvedRegion(
      key: selected.key,
      highwayPaths: effectivePaths,
      eligibleSourceRegions: eligibleSourceRegions,
    );
  }

  List<String> _effectiveHighwayPaths(
    Map<String, _ManifestRegion> manifest,
    _ManifestRegion region,
  ) {
    var priority = region.priority.segments;
    while (priority.isNotEmpty) {
      final ancestor = manifest.values.where(
        (candidate) => _samePriority(candidate.priority.segments, priority),
      );
      if (ancestor.length == 1 && ancestor.single.highways.isNotEmpty) {
        return ancestor.single.highways;
      }
      priority = priority.sublist(0, priority.length - 1);
    }
    return const [];
  }

  Future<List<_SourcePeak>> _loadPeaks(String sourcePath) async {
    final text = await _readRequiredText(
      sourcePath,
      'Could not read peak source at $sourcePath',
    );
    try {
      final rows = const CsvDecoder().convert(text);
      if (rows.isEmpty || !_sameStrings(rows.first, peakSourceHeaders)) {
        throw FormatException(
          'expected exact 25-column header: ${peakSourceHeaders.join(', ')}',
        );
      }
      final peaks = <_SourcePeak>[];
      for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
        final row = rows[rowIndex];
        if (row.length != peakSourceHeaders.length) {
          throw FormatException(
            'CSV row ${rowIndex + 1} must contain 25 columns',
          );
        }
        peaks.add(_parsePeakRow(row, rowIndex + 1));
      }
      return peaks;
    } catch (error) {
      if (error is RouteGraphPeakListGenerationException) {
        rethrow;
      }
      throw RouteGraphPeakListGenerationException(
        'Could not parse peak source at $sourcePath: $error',
      );
    }
  }

  _SourcePeak _parsePeakRow(List<dynamic> row, int rowNumber) {
    String value(int index) => '${row[index]}';
    int requiredPositiveInt(int index) {
      final parsed = int.tryParse(value(index).trim());
      if (parsed == null || parsed <= 0) {
        throw FormatException(
          'CSV row $rowNumber ${peakSourceHeaders[index]} must be a positive integer',
        );
      }
      return parsed;
    }

    int? optionalInt(int index) {
      final raw = value(index).trim();
      if (raw.isEmpty) {
        return null;
      }
      final parsed = int.tryParse(raw);
      if (parsed == null) {
        throw FormatException(
          'CSV row $rowNumber ${peakSourceHeaders[index]} must be an integer',
        );
      }
      return parsed;
    }

    double? optionalFiniteDouble(int index) {
      final raw = value(index).trim();
      if (raw.isEmpty) {
        return null;
      }
      final parsed = double.tryParse(raw);
      if (parsed == null || !parsed.isFinite) {
        throw FormatException(
          'CSV row $rowNumber ${peakSourceHeaders[index]} must be finite',
        );
      }
      return parsed;
    }

    final id = requiredPositiveInt(0);
    final osmId = requiredPositiveInt(1);
    final name = value(3);
    if (name.trim().isEmpty) {
      throw FormatException('CSV row $rowNumber name must not be blank');
    }
    final latitude = optionalFiniteDouble(16);
    if (latitude == null || latitude < -90 || latitude > 90) {
      throw FormatException(
        'CSV row $rowNumber latitude must be within -90..90',
      );
    }
    final longitude = optionalFiniteDouble(17);
    if (longitude == null || longitude < -180 || longitude > 180) {
      throw FormatException(
        'CSV row $rowNumber longitude must be within -180..180',
      );
    }
    final verifiedValue = _normalize(value(23));
    final verified = switch (verifiedValue) {
      'true' => true,
      'false' => false,
      _ => throw FormatException(
        'CSV row $rowNumber verified must be true or false',
      ),
    };
    final peak = Peak(
      id: id,
      osmId: osmId,
      peakbaggerPid: optionalInt(2),
      name: name,
      altName: value(4),
      elevation: optionalFiniteDouble(5),
      prominence: optionalFiniteDouble(6),
      country: value(7),
      county: value(8),
      range: value(9),
      rating: optionalFiniteDouble(10),
      durationMinutes: optionalInt(11),
      durationLabel: value(12),
      difficulty: value(13),
      viaFerrata: value(14),
      notes: value(15),
      latitude: latitude,
      longitude: longitude,
      region: _normalize(value(18)),
      gridZoneDesignator: value(19),
      mgrs100kId: value(20),
      easting: value(21),
      northing: value(22),
      verified: verified,
      sourceOfTruth: value(24),
    );
    return _SourcePeak(peak: peak, region: peak.region!);
  }

  Future<List<_RouteGraphSegment>> _loadHighwaySegments(
    String path,
    String selectedRegion,
  ) async {
    final text = await _readRequiredText(
      path,
      'Could not read highway data for region $selectedRegion at $path',
    );
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map || decoded['elements'] is! List) {
        throw const FormatException('expected an object with an elements list');
      }
      final nodes = <int, Location>{};
      final ways = <Map<Object?, Object?>>[];
      for (final element in decoded['elements'] as List) {
        if (element is! Map) {
          continue;
        }
        final typed = Map<Object?, Object?>.from(element);
        if (typed['type'] == 'node') {
          final id = _jsonInt(typed['id']);
          final lat = _jsonCoordinate(typed['lat'], -90, 90);
          final lon = _jsonCoordinate(typed['lon'], -180, 180);
          if (id != null && lat != null && lon != null) {
            nodes[id] = Location(lat, lon);
          }
        } else if (_isEligibleWay(typed)) {
          ways.add(typed);
        }
      }
      final segments = <_RouteGraphSegment>[];
      for (final way in ways) {
        final nodeReferences = way['nodes'];
        if (nodeReferences is! List) {
          continue;
        }
        Location? previous;
        for (final reference in nodeReferences) {
          final nodeId = _jsonInt(reference);
          final point = nodeId == null ? null : nodes[nodeId];
          if (point == null) {
            previous = null;
          } else {
            if (previous != null) {
              segments.add(_RouteGraphSegment(start: previous, end: point));
            }
            previous = point;
          }
        }
      }
      if (segments.isEmpty) {
        throw const FormatException('no usable eligible highway segments');
      }
      return segments;
    } catch (error) {
      throw RouteGraphPeakListGenerationException(
        'Could not parse highway data for region $selectedRegion at $path: $error',
      );
    }
  }

  Future<void> _writeAtomically(
    String targetPath,
    String contents,
    String selectedRegion,
  ) async {
    final parentPath = p.dirname(targetPath);
    if (!await _fileSystem.directoryExists(parentPath)) {
      throw RouteGraphPeakListGenerationException(
        'Output parent directory for region $selectedRegion does not exist: $parentPath',
      );
    }
    final temporaryPath = '$targetPath.tmp-${_tempSuffixResolver()}';
    try {
      await _fileSystem.writeText(temporaryPath, contents);
      await _fileSystem.rename(temporaryPath, targetPath);
    } catch (error) {
      throw RouteGraphPeakListGenerationException(
        'Could not write route-graph peak list for region $selectedRegion at $targetPath: $error',
      );
    } finally {
      await _fileSystem.deleteIfExists(temporaryPath);
    }
  }

  Future<String> _readRequiredText(String path, String prefix) async {
    try {
      return await _textReader(path);
    } catch (error) {
      throw RouteGraphPeakListGenerationException('$prefix: $error');
    }
  }

  String _defaultPeakSourcePath() {
    return p.join(
      _homeDirectoryResolver(),
      'Documents',
      'Bushwalking',
      'Features',
      'peaks.csv',
    );
  }

  String _defaultOutputPath(String regionKey) {
    return p.join(
      _homeDirectoryResolver(),
      'Documents',
      'Bushwalking',
      'Peak_Lists',
      '$regionKey-route-graph-peak-list.csv',
    );
  }
}

class _ManifestRegion {
  const _ManifestRegion({
    required this.key,
    required this.priority,
    required this.isComposite,
    required this.highways,
    required this.aliases,
  });

  final String key;
  final ManifestPriority priority;
  final bool isComposite;
  final List<String> highways;
  final Set<String> aliases;
}

class _ResolvedRegion {
  const _ResolvedRegion({
    required this.key,
    required this.highwayPaths,
    required this.eligibleSourceRegions,
  });

  final String key;
  final List<String> highwayPaths;
  final Set<String> eligibleSourceRegions;
}

class _SourcePeak {
  const _SourcePeak({required this.peak, required this.region});

  final Peak peak;
  final String region;
}

class _RouteGraphSegment {
  const _RouteGraphSegment({required this.start, required this.end});

  final Location start;
  final Location end;
}

List<String> _readStringList(Object? value, String field, String regionKey) {
  if (value == null) {
    return const [];
  }
  if (value is! List || value.any((entry) => entry is! String)) {
    throw FormatException('region $regionKey $field must be a list of strings');
  }
  return value
      .cast<String>()
      .where((value) => value.trim().isNotEmpty)
      .toList();
}

bool _samePriority(List<int> left, List<int> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

bool _sameStrings(Object? value, List<String> expected) {
  if (value is! List || value.length != expected.length) {
    return false;
  }
  for (var index = 0; index < expected.length; index++) {
    if (value[index] != expected[index]) {
      return false;
    }
  }
  return true;
}

bool _isEligibleWay(Map<Object?, Object?> way) {
  final tags = way['tags'];
  return tags is Map &&
      tags['highway'] != null &&
      tags['area'] != 'yes' &&
      tags['place'] != 'square';
}

int? _jsonInt(Object? value) {
  return value is int ||
          value is num && value.isFinite && value == value.roundToDouble()
      ? (value as num).toInt()
      : null;
}

double? _jsonCoordinate(Object? value, double min, double max) {
  if (value is! num) {
    return null;
  }
  final coordinate = value.toDouble();
  return coordinate.isFinite && coordinate >= min && coordinate <= max
      ? coordinate
      : null;
}

String _normalize(String value) => value.trim().toLowerCase();

Future<String> _readText(String path) => File(path).readAsString();

String _resolveHomeDirectory() {
  final home =
      Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null || home.isEmpty) {
    throw const RouteGraphPeakListGenerationException(
      'HOME is unavailable; cannot resolve route-graph peak-list paths.',
    );
  }
  return home;
}

String _resolveRepositoryRoot() => Directory.current.path;

String _defaultTempSuffix() => '${DateTime.now().microsecondsSinceEpoch}-$pid';
