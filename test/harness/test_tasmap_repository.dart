import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class TestTasmapRepository implements TasmapRepository {
  TestTasmapRepository._(List<Tasmap50k> maps)
    : _seedMaps = List<Tasmap50k>.unmodifiable(maps),
      _maps = List<Tasmap50k>.from(maps);

  final List<Tasmap50k> _seedMaps;
  final List<Tasmap50k> _maps;
  int getAllMapsCallCount = 0;

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
    final cleaned = mgrsString.replaceAll(RegExp(r'[\n\s]'), '');
    if (cleaned.length < 10) return null;

    final code = cleaned.substring(3, 5);
    final easting = int.tryParse(cleaned.substring(5, 10)) ?? 0;
    final northing = int.tryParse(cleaned.substring(10)) ?? 0;

    for (final map in findByMgrs100kId(code)) {
      final validEasting = _inRange(easting, map.eastingMin, map.eastingMax);
      final validNorthing = _inRange(
        northing,
        map.northingMin,
        map.northingMax,
      );
      if (validEasting && validNorthing) {
        return map;
      }
    }

    return null;
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
        .where((map) => map.name.toLowerCase().contains(lowered))
        .take(10)
        .toList(growable: false);
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
  }

  @override
  Future<TasmapCsvImportResult?> loadFromCsvIfEmpty(String csvPath) async {
    if (_maps.isNotEmpty) {
      return null;
    }

    _maps.addAll(_seedMaps);
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

    return TasmapCsvImportResult(
      maps: getAllMaps(),
      importedCount: mapCount,
      skippedCount: 0,
    );
  }

  @override
  Future<void> clearAll() async {
    _maps.clear();
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
