import 'package:peak_bagger/models/peak_list.dart';

import '../objectbox.g.dart';

abstract class PeakListStorage {
  int get count;

  List<PeakList> getAll();

  PeakList? getById(int peakListId);

  PeakList? getByName(String name);

  Future<void> delete(int peakListId);

  Future<PeakList> put(PeakList peakList);

  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  });
}

class ObjectBoxPeakListStorage implements PeakListStorage {
  ObjectBoxPeakListStorage(this._store) : _peakListBox = _store.box<PeakList>();

  final Store _store;
  final Box<PeakList> _peakListBox;

  @override
  int get count => _peakListBox.count();

  @override
  List<PeakList> getAll() => _peakListBox.getAll();

  @override
  PeakList? getById(int peakListId) => _peakListBox.get(peakListId);

  @override
  PeakList? getByName(String name) {
    for (final peakList in _peakListBox.getAll()) {
      if (peakList.name == name) {
        return peakList;
      }
    }

    return null;
  }

  @override
  Future<void> delete(int peakListId) async {
    _peakListBox.remove(peakListId);
  }

  @override
  Future<PeakList> put(PeakList peakList) async {
    final id = _peakListBox.put(peakList);
    peakList.peakListId = id;
    return peakList;
  }

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    final existing = getByName(peakList.name);
    if (existing == null) {
      return put(peakList);
    }

    final updated = peakList.copyWith(peakListId: existing.peakListId);
    _store.runInTransaction(TxMode.write, () {
      _peakListBox.remove(existing.peakListId);
      beforePutForTest?.call();
      _peakListBox.put(updated);
    });
    return updated;
  }
}

class InMemoryPeakListStorage implements PeakListStorage {
  InMemoryPeakListStorage([List<PeakList> peakLists = const []])
    : _peakLists = List<PeakList>.from(peakLists),
      _nextId = peakLists.fold<int>(1, (maxId, peakList) {
        final candidate = peakList.peakListId + 1;
        return candidate > maxId ? candidate : maxId;
      });

  List<PeakList> _peakLists;
  int _nextId;

  @override
  int get count => _peakLists.length;

  @override
  List<PeakList> getAll() => List<PeakList>.unmodifiable(_peakLists);

  @override
  PeakList? getById(int peakListId) {
    for (final peakList in _peakLists) {
      if (peakList.peakListId == peakListId) {
        return peakList;
      }
    }

    return null;
  }

  @override
  PeakList? getByName(String name) {
    for (final peakList in _peakLists) {
      if (peakList.name == name) {
        return peakList;
      }
    }

    return null;
  }

  @override
  Future<void> delete(int peakListId) async {
    _peakLists = _peakLists
        .where((entry) => entry.peakListId != peakListId)
        .toList(growable: false);
  }

  @override
  Future<PeakList> put(PeakList peakList) async {
    final id = peakList.peakListId == 0 ? _nextId++ : peakList.peakListId;
    final stored = peakList.copyWith(peakListId: id);
    _peakLists = [..._peakLists, stored];
    return stored;
  }

  @override
  Future<PeakList> replaceByName(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    final existing = getByName(peakList.name);
    if (existing == null) {
      return put(peakList);
    }

    final snapshot = List<PeakList>.from(_peakLists);
    final nextIdSnapshot = _nextId;
    try {
      _peakLists = _peakLists
          .where((entry) => entry.peakListId != existing.peakListId)
          .toList(growable: false);
      beforePutForTest?.call();
      final updated = peakList.copyWith(peakListId: existing.peakListId);
      _peakLists = [..._peakLists, updated];
      return updated;
    } catch (_) {
      _peakLists = snapshot;
      _nextId = nextIdSnapshot;
      rethrow;
    }
  }
}

class PeakListRepository {
  PeakListRepository(Store store) : _storage = ObjectBoxPeakListStorage(store);

  PeakListRepository.test(PeakListStorage storage) : _storage = storage;

  final PeakListStorage _storage;

  int get peakListCount => _storage.count;

  List<PeakList> getAllPeakLists() {
    return _storage.getAll();
  }

  List<String> findPeakListNamesForPeak(int peakOsmId) {
    final names = <String>{};

    for (final peakList in _storage.getAll()) {
      final items = decodePeakListItems(peakList.peakList);
      if (items.any((item) => item.peakOsmId == peakOsmId)) {
        names.add(peakList.name);
      }
    }

    final result = names.toList()..sort();
    return result;
  }

  PeakList? findByName(String name) {
    return _storage.getByName(name);
  }

  PeakList? findById(int peakListId) {
    return _storage.getById(peakListId);
  }

  Future<void> delete(int peakListId) {
    return _storage.delete(peakListId);
  }

  Future<PeakList> save(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    final existing = _storage.getByName(peakList.name);
    if (existing == null) {
      return _storage.put(peakList);
    }

    return _storage.replaceByName(peakList, beforePutForTest: beforePutForTest);
  }

  Future<PeakList> addPeakItem({
    required int peakListId,
    required PeakListItem item,
  }) async {
    final peakList = _requireById(peakListId);
    final items = decodePeakListItems(peakList.peakList);
    if (items.any((entry) => entry.peakOsmId == item.peakOsmId)) {
      throw StateError('Peak already exists in list');
    }

    return save(
      peakList.copyWith(
        peakList: encodePeakListItems([...items, item]),
      ),
    );
  }

  Future<PeakList> updatePeakItemPoints({
    required int peakListId,
    required int peakOsmId,
    required int points,
  }) async {
    final peakList = _requireById(peakListId);
    final items = decodePeakListItems(peakList.peakList);
    final updatedItems = [
      for (final item in items)
        if (item.peakOsmId == peakOsmId)
          PeakListItem(peakOsmId: item.peakOsmId, points: points)
        else
          item,
    ];

    if (updatedItems.length == items.length &&
        !updatedItems.any((item) => item.peakOsmId == peakOsmId)) {
      throw StateError('Peak not found in list');
    }

    return save(
      peakList.copyWith(peakList: encodePeakListItems(updatedItems)),
    );
  }

  Future<PeakList> removePeakItem({
    required int peakListId,
    required int peakOsmId,
  }) async {
    final peakList = _requireById(peakListId);
    final items = decodePeakListItems(peakList.peakList);
    final updatedItems = items
        .where((item) => item.peakOsmId != peakOsmId)
        .toList(growable: false);

    if (updatedItems.length == items.length) {
      throw StateError('Peak not found in list');
    }

    return save(
      peakList.copyWith(peakList: encodePeakListItems(updatedItems)),
    );
  }

  PeakList _requireById(int peakListId) {
    final peakList = findById(peakListId);
    if (peakList == null) {
      throw StateError('Peak list not found');
    }
    return peakList;
  }
}
