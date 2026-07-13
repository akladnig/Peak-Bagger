import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class TestTasmapRepository implements TasmapRepository {
  TestTasmapRepository._(List<Tasmap50k> maps)
    : _seedMaps = List<Tasmap50k>.unmodifiable(maps),
      _maps = List<Tasmap50k>.from(maps);

  final List<Tasmap50k> _seedMaps;
  final List<Tasmap50k> _maps;
  int getAllMapsCallCount = 0;
  List<_TestTasmapLookupEntry>? _lookupEntries;

  static Future<TestTasmapRepository> create({List<Tasmap50k>? maps}) async {
    return TestTasmapRepository._(maps ?? [_defaultMap()]);
  }

  @override
  int get mapCount => _maps.length;

  @override
  List<Tasmap50k> getAllMaps() {
    getAllMapsCallCount += 1;
    return List.unmodifiable(_maps);
  }

  @override
  List<Tasmap50k> findByName(String name) {
    final lowered = name.trim().toLowerCase();
    return _maps
        .where((map) => map.name.toLowerCase().contains(lowered))
        .toList(growable: false);
  }

  @override
  List<Tasmap50k> findByMgrs100kId(String mgrsCode) {
    return _maps
        .where((map) => map.mgrs100kIdList.contains(mgrsCode))
        .toList(growable: false);
  }

  @override
  Tasmap50k? findByMgrsCodeAndCoordinates(String mgrsString) {
    final point = _mgrsStringToLatLng(mgrsString);
    if (point == null) {
      return null;
    }
    return findByPoint(point);
  }

  @override
  Tasmap50k? findByPoint(LatLng point) {
    final candidates = _candidateEntriesForPoint(point);
    final matches = <_TestTasmapLookupEntry>[];

    for (final candidate in candidates) {
      try {
        if (polygonContainsPoint(point, candidate.points)) {
          matches.add(candidate);
        }
      } on ArgumentError {
        // Ignore malformed polygons in lookup tests.
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort(_compareLookupEntries);
    return matches.first.map;
  }

  @override
  List<Tasmap50k> findBySeries(String series) {
    return _maps.where((map) => map.series == series).toList(growable: false);
  }

  @override
  List<Tasmap50k> searchMaps(String prefix) {
    final lowered = prefix.trim().toLowerCase();
    if (lowered.isEmpty) {
      return const [];
    }

    return _maps
        .where((map) => map.name.toLowerCase().startsWith(lowered))
        .take(10)
        .toList(growable: false);
  }

  List<Tasmap50k> getAllMapsSortedByName() {
    final maps = getAllMaps();
    maps.sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) {
        return byName;
      }

      final bySeries = a.series.toLowerCase().compareTo(b.series.toLowerCase());
      if (bySeries != 0) {
        return bySeries;
      }

      return a.id.compareTo(b.id);
    });
    return maps;
  }

  @override
  List<LatLng> getMapPolygonPoints(Tasmap50k map) {
    return map.polygonPoints
        .map((point) {
          final coords = mgrs.Mgrs.toPoint('55G$point');
          return LatLng(coords[1], coords[0]);
        })
        .toList(growable: false);
  }

  @override
  LatLng? getMapCenter(Tasmap50k map) {
    final points = getMapPolygonPoints(map);
    if (points.isEmpty) {
      return null;
    }

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    return LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
  }

  @override
  LatLngBounds? getMapBounds(Tasmap50k map) {
    final points = getMapPolygonPoints(map);
    if (points.isEmpty) {
      return null;
    }

    final minLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a > b ? a : b);

    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  @override
  Future<void> addMaps(List<Tasmap50k> maps) async {
    _maps.addAll(maps);
    _invalidateLookupEntries();
  }

  @override
  Future<TasmapCsvImportResult?> loadFromCsvIfEmpty(String csvPath) async {
    if (_maps.isNotEmpty) {
      return null;
    }

    _maps.addAll(_seedMaps);
    _invalidateLookupEntries();
    return TasmapCsvImportResult(
      maps: getAllMaps(),
      importedCount: mapCount,
      skippedCount: 0,
    );
  }

  @override
  Future<TasmapCsvImportResult> clearAndReloadFromCsv(String csvPath) async {
    _maps
      ..clear()
      ..addAll(_seedMaps);
    _invalidateLookupEntries();

    return TasmapCsvImportResult(
      maps: getAllMaps(),
      importedCount: mapCount,
      skippedCount: 0,
    );
  }

  @override
  Future<void> clearAll() async {
    _maps.clear();
    _invalidateLookupEntries();
  }

  @override
  bool isEmpty() => _maps.isEmpty;

  Future<void> dispose() async {}

  static bool _inRange(int value, int min, int max) {
    if (min <= max) {
      return value >= min && value <= max;
    }

    return (value >= min && value <= 99999) || (value >= 0 && value <= max);
  }

  List<_TestTasmapLookupEntry> _entries() {
    return _lookupEntries ??= _maps
        .map(
          (map) => _TestTasmapLookupEntry(
            map: map,
            points: List<LatLng>.unmodifiable(getMapPolygonPoints(map)),
            mgrsCodes: Set<String>.from(map.mgrs100kIdList),
            nameLower: map.name.toLowerCase(),
            seriesLower: map.series.toLowerCase(),
          ),
        )
        .toList(growable: false);
  }

  List<_TestTasmapLookupEntry> _candidateEntriesForPoint(LatLng point) {
    final entries = _entries();
    final mgrsPoint = _pointToMgrsPoint(point);
    if (mgrsPoint == null) {
      return entries;
    }

    final codeMatches = entries
        .where((entry) => entry.mgrsCodes.contains(mgrsPoint.code))
        .toList(growable: false);
    final base = codeMatches.isEmpty ? entries : codeMatches;
    final rangeMatches = base
        .where(
          (entry) =>
              _inRange(
                mgrsPoint.easting,
                entry.map.eastingMin,
                entry.map.eastingMax,
              ) &&
              _inRange(
                mgrsPoint.northing,
                entry.map.northingMin,
                entry.map.northingMax,
              ),
        )
        .toList(growable: false);
    return rangeMatches.isEmpty ? base : rangeMatches;
  }

  LatLng? _mgrsStringToLatLng(String mgrsString) {
    final cleaned = mgrsString.replaceAll(RegExp(r'[\n\s]'), '');
    if (cleaned.length < 15) {
      return null;
    }

    final fullMgrs =
        '${cleaned.substring(0, 5)} ${cleaned.substring(5, 10)} ${cleaned.substring(10)}';
    try {
      final coords = mgrs.Mgrs.toPoint(fullMgrs);
      return LatLng(coords[1], coords[0]);
    } catch (_) {
      return null;
    }
  }

  ({String code, int easting, int northing})? _pointToMgrsPoint(LatLng point) {
    try {
      final cleaned = mgrs.Mgrs.forward([
        point.longitude,
        point.latitude,
      ], 5).replaceAll(RegExp(r'[\n\s]'), '');
      if (cleaned.length < 15) {
        return null;
      }
      return (
        code: cleaned.substring(3, 5),
        easting: int.parse(cleaned.substring(5, 10)),
        northing: int.parse(cleaned.substring(10)),
      );
    } catch (_) {
      return null;
    }
  }

  void _invalidateLookupEntries() {
    _lookupEntries = null;
  }

  static int _compareLookupEntries(
    _TestTasmapLookupEntry left,
    _TestTasmapLookupEntry right,
  ) {
    final byName = left.nameLower.compareTo(right.nameLower);
    if (byName != 0) {
      return byName;
    }

    final bySeries = left.seriesLower.compareTo(right.seriesLower);
    if (bySeries != 0) {
      return bySeries;
    }

    return left.map.id.compareTo(right.map.id);
  }

  static Tasmap50k _defaultMap() {
    return Tasmap50k(
      series: 'TS07',
      name: 'Adamsons',
      parentSeries: '8211',
      mgrs100kIds: 'DM DN',
      eastingMin: 60000,
      eastingMax: 99999,
      northingMin: 80000,
      northingMax: 9999,
      mgrsMid: 'DM',
      eastingMid: 80000,
      northingMid: 95000,
      p1: 'DN6000009999',
      p2: 'DN9999909999',
      p3: 'DM6000080000',
      p4: 'DM9999980000',
    );
  }
}

class _TestTasmapLookupEntry {
  const _TestTasmapLookupEntry({
    required this.map,
    required this.points,
    required this.mgrsCodes,
    required this.nameLower,
    required this.seriesLower,
  });

  final Tasmap50k map;
  final List<LatLng> points;
  final Set<String> mgrsCodes;
  final String nameLower;
  final String seriesLower;
}
