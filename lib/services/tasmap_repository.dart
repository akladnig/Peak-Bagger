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

  List<Tasmap50k> findByMgrs100kId(String mgrsCode) {
    final allMaps = _box.getAll();
    return allMaps
        .where((map) => map.mgrs100kIdList.contains(mgrsCode))
        .toList();
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
