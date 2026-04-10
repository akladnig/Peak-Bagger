import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs_dart;
import 'package:peak_bagger/models/tasmap50k.dart';
import '../objectbox.g.dart';

class TasmapRepository {
  final Box<Tasmap50k> _box;

  TasmapRepository(Store store) : _box = store.box<Tasmap50k>();

  int get mapCount => _box.count();

  List<Tasmap50k> getAllMaps() {
    return _box.getAll();
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
    final mgrsCodes = map.mgrs100kIdList;
    if (mgrsCodes.isEmpty) return null;

    final mgrsCode = mgrsCodes.first;
    final centerEasting = (map.eastingMin + map.eastingMax) ~/ 2;
    final centerNorthing = (map.northingMin + map.northingMax) ~/ 2;
    final paddedEasting = centerEasting.toString().padLeft(5, '0');
    final paddedNorthing = centerNorthing.toString().padLeft(5, '0');
    final fullMgrs =
        '55G${mgrsCode.substring(0, 2)} $paddedEasting $paddedNorthing';

    try {
      final coords = mgrs_dart.Mgrs.toPoint(fullMgrs);
      return LatLng(coords[1], coords[0]);
    } catch (e) {
      return null;
    }
  }

  List<Tasmap50k> findByMgrs100kId(String mgrsCode) {
    final allMaps = _box.getAll();
    return allMaps
        .where((map) => map.mgrs100kIdList.contains(mgrsCode))
        .toList();
  }

  Tasmap50k? findByMgrsCodeAndCoordinates(String mgrsString) {
    // MGRS format: "55GEN\n19400 50699" or "55GEN1940050699"
    // Remove newlines and spaces to get continuous format
    final cleaned = mgrsString.replaceAll(RegExp(r'[\n\s]'), '');

    if (cleaned.length < 10) return null;

    final code = cleaned.substring(3, 5);
    final easting = int.tryParse(cleaned.substring(5, 10)) ?? 0;
    final northing = int.tryParse(cleaned.substring(10)) ?? 0;

    final maps = findByMgrs100kId(code);

    for (final map in maps) {
      bool validEasting = _inRange(easting, map.eastingMin, map.eastingMax);
      bool validNorthing = _inRange(northing, map.northingMin, map.northingMax);
      if (validEasting && validNorthing) {
        return map;
      }
    }
    return null;
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
  }

  Future<void> clearAll() async {
    _box.removeAll();
  }

  bool isEmpty() {
    return _box.isEmpty();
  }
}
