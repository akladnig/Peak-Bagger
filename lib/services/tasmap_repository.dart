import 'dart:io';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs_dart;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';
import '../objectbox.g.dart';

class TasmapRepository {
  final Box<Tasmap50k> _box;
  List<_TasmapLookupEntry>? _lookupEntries;

  TasmapRepository(Store store) : _box = store.box<Tasmap50k>();

  int get mapCount => _box.count();

  List<Tasmap50k> getAllMaps() {
    return _box.getAll();
  }

  List<LatLng> getMapPolygonPoints(Tasmap50k map) {
    final points = <LatLng>[];

    for (final point in map.polygonPoints) {
      final latLng = _pointToLatLng(point);
      if (latLng != null) {
        points.add(latLng);
      }
    }

    return points;
  }

  List<Tasmap50k> findByName(String name) {
    final query = _box
        .query(Tasmap50k_.name.contains(name, caseSensitive: false))
        .build();
    final results = query.find();
    query.close();
    return results;
  }

  List<Tasmap50k> searchMaps(String prefix) {
    if (prefix.isEmpty) return [];
    final allMaps = _box.getAll();
    final lower = prefix.toLowerCase();
    return allMaps
        .where((map) => map.name.toLowerCase().startsWith(lower))
        .take(10)
        .toList();
  }

  LatLng? getMapCenter(Tasmap50k map) {
    final points = getMapPolygonPoints(map);
    if (points.isNotEmpty) {
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

    if (map.mgrsMid.isEmpty) return null;

    final paddedEasting = map.eastingMid.toString().padLeft(5, '0');
    final paddedNorthing = map.northingMid.toString().padLeft(5, '0');
    final fullMgrs = '55G${map.mgrsMid} $paddedEasting $paddedNorthing';

    try {
      final coords = mgrs_dart.Mgrs.toPoint(fullMgrs);
      return LatLng(coords[1], coords[0]);
    } catch (e) {
      return null;
    }
  }

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

  List<Tasmap50k> findByMgrs100kId(String mgrsCode) {
    final allMaps = _box.getAll();
    return allMaps
        .where((map) => map.mgrs100kIdList.contains(mgrsCode))
        .toList();
  }

  Tasmap50k? findByPoint(LatLng point) {
    final candidates = _candidateEntriesForPoint(point);
    final matches = <_TasmapLookupEntry>[];

    for (final candidate in candidates) {
      try {
        if (polygonContainsPoint(point, candidate.points)) {
          matches.add(candidate);
        }
      } on ArgumentError {
        // Ignore malformed polygons when resolving coverage.
      }
    }

    if (matches.isEmpty) {
      return null;
    }

    matches.sort(_compareLookupEntries);
    return matches.first.map;
  }

  Tasmap50k? findByMgrsCodeAndCoordinates(String mgrsString) {
    final point = _mgrsStringToLatLng(mgrsString);
    if (point == null) {
      return null;
    }
    return findByPoint(point);
  }

  bool _inRange(int value, int min, int max) {
    if (min <= max) {
      return value >= min && value <= max;
    } else {
      // Wrap-around range: valid if in [min, 99999] OR [0, max]
      // For example: min=80000, max=9999 means valid if 80000-99999 OR 0-9999
      return (value >= min && value <= 99999) || (value >= 0 && value <= max);
    }
  }

  List<Tasmap50k> findBySeries(String series) {
    final query = _box.query(Tasmap50k_.series.equals(series)).build();
    final results = query.find();
    query.close();
    return results;
  }

  Future<void> addMaps(List<Tasmap50k> maps) async {
    _box.putMany(maps);
    _invalidateLookupEntries();
  }

  Future<TasmapCsvImportResult?> loadFromCsvIfEmpty(String csvPath) async {
    if (!_box.isEmpty()) {
      return null;
    }

    final result = await CsvImporter.importFromCsv(csvPath);
    if (result.maps.isNotEmpty) {
      _box.putMany(result.maps);
      _invalidateLookupEntries();
    }

    await _appendImportLogEntries([
      _describeImportResult(result),
      ...result.logEntries,
    ]);
    return result;
  }

  Future<TasmapCsvImportResult> clearAndReloadFromCsv(String csvPath) async {
    _box.removeAll();
    _invalidateLookupEntries();

    final result = await CsvImporter.importFromCsv(csvPath);
    if (result.maps.isNotEmpty) {
      _box.putMany(result.maps);
      _invalidateLookupEntries();
    }

    await _appendImportLogEntries([
      _describeImportResult(result),
      ...result.logEntries,
    ]);
    return result;
  }

  Future<void> clearAll() async {
    _box.removeAll();
    _invalidateLookupEntries();
  }

  bool isEmpty() {
    return _box.isEmpty();
  }

  Future<void> _appendImportLogEntries(List<String> entries) async {
    if (entries.isEmpty) {
      return;
    }

    final logFile = File(GpxImporter().getImportLogPath());
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString(
      '${entries.join('\n')}\n',
      mode: FileMode.append,
    );
  }

  String _describeImportResult(TasmapCsvImportResult result) {
    final warningText = result.warning == null
        ? 'ok'
        : 'warning: ${result.warning}';
    final timestamp = DateTime.now().toIso8601String();
    return '$timestamp Tasmap import: imported ${result.importedCount}, skipped ${result.skippedCount} ($warningText)';
  }

  LatLng? _pointToLatLng(String point) {
    if (point.length != 12) return null;

    try {
      final coords = mgrs_dart.Mgrs.toPoint('55G$point');
      return LatLng(coords[1], coords[0]);
    } catch (e) {
      return null;
    }
  }

  List<_TasmapLookupEntry> _entries() {
    return _lookupEntries ??= _box
        .getAll()
        .map(
          (map) => _TasmapLookupEntry(
            map: map,
            points: List<LatLng>.unmodifiable(getMapPolygonPoints(map)),
            mgrsCodes: Set<String>.from(map.mgrs100kIdList),
            nameLower: map.name.toLowerCase(),
            seriesLower: map.series.toLowerCase(),
          ),
        )
        .toList(growable: false);
  }

  List<_TasmapLookupEntry> _candidateEntriesForPoint(LatLng point) {
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
      final coords = mgrs_dart.Mgrs.toPoint(fullMgrs);
      return LatLng(coords[1], coords[0]);
    } catch (_) {
      return null;
    }
  }

  ({String code, int easting, int northing})? _pointToMgrsPoint(LatLng point) {
    try {
      final cleaned = mgrs_dart.Mgrs.forward([
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
    _TasmapLookupEntry left,
    _TasmapLookupEntry right,
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
}

class _TasmapLookupEntry {
  const _TasmapLookupEntry({
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
