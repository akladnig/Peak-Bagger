import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_derived_data.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/tassy_full_peak_list_sync_service.dart';

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
    final index = _peakLists.indexWhere((entry) => entry.peakListId == id);
    if (index == -1) {
      _peakLists = [..._peakLists, stored];
      return stored;
    }

    _peakLists = [
      for (var i = 0; i < _peakLists.length; i++)
        if (i == index) stored else _peakLists[i],
    ];
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
  static const String tassyFullTasmaniaOnlyError =
      'Tassy Full only accepts Tasmanian peaks.';

  PeakListRepository(Store store, {this._peakRepository})
    : _storage = ObjectBoxPeakListStorage(store);

  PeakListRepository.test(PeakListStorage storage, {this._peakRepository})
    : _storage = storage;

  final PeakListStorage _storage;
  final PeakRepository? _peakRepository;

  PeakListStorage get storage => _storage;

  int get peakListCount => _storage.count;

  List<PeakList> getAllPeakLists() {
    return _storage.getAll();
  }

  List<String> findPeakListNamesForPeak(int peakOsmId) {
    final names = <String>{};

    for (final peakList in _storage.getAll()) {
      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        continue;
      }
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

  Peak? findPeakByOsmId(int peakOsmId) {
    return _peakRepository?.findByOsmId(peakOsmId);
  }

  Map<int, String?> peakRegionsByOsmId() {
    final peakRepository = _peakRepository;
    if (peakRepository == null) {
      return const {};
    }

    return {
      for (final peak in peakRepository.getAllPeaks()) peak.osmId: peak.region,
    };
  }

  Future<void> delete(int peakListId) {
    return _storage.delete(peakListId);
  }

  Future<PeakList> save(
    PeakList peakList, {
    void Function()? beforePutForTest,
    bool recomputeDerivedFields = false,
  }) async {
    return saveWithoutSync(
      peakList,
      beforePutForTest: beforePutForTest,
      recomputeDerivedFields: recomputeDerivedFields,
    );
  }

  Future<PeakList> saveWithoutSync(
    PeakList peakList, {
    void Function()? beforePutForTest,
    bool recomputeDerivedFields = false,
  }) async {
    final normalizedPeakList = recomputeDerivedFields
        ? _recomputePeakListDerivedData(peakList)
        : _normalizePeakListForStorage(peakList);
    final existing = _storage.getByName(normalizedPeakList.name);
    if (existing == null) {
      final saved = await _storage.put(normalizedPeakList);
      return _ensureStoredColour(saved);
    }

    final saved = await _storage.replaceByName(
      normalizedPeakList,
      beforePutForTest: beforePutForTest,
    );
    return _ensureStoredColour(saved);
  }

  Future<TassyFullPeakListSyncResult> refreshTassyFullPeakList() {
    return TassyFullPeakListSyncService(this).refresh();
  }

  Future<PeakList> addPeakItem({
    required int peakListId,
    required PeakListItem item,
  }) async {
    return addPeakItems(peakListId: peakListId, items: [item]);
  }

  Future<PeakList> addPeakItems({
    required int peakListId,
    required List<PeakListItem> items,
  }) async {
    final peakList = _requireById(peakListId);
    final existingItems = decodePeakListItems(peakList.peakList);

    _validateAddedPeakItems(
      peakList: peakList,
      existingItems: existingItems,
      addedItems: items,
    );

    return save(
      peakList.copyWith(
        peakList: encodePeakListItems([...existingItems, ...items]),
      ),
      recomputeDerivedFields: true,
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

    return save(peakList.copyWith(peakList: encodePeakListItems(updatedItems)));
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
      recomputeDerivedFields: true,
    );
  }

  Future<bool> backfillStoredPeakLists() async {
    var changed = false;

    for (final peakList in _storage.getAll()) {
      final updated = _tryRecomputePeakListDerivedData(peakList);
      if (updated == null || _peakListDerivedDataMatches(updated, peakList)) {
        continue;
      }

      await _storage.put(updated);
      changed = true;
    }

    return changed;
  }

  Future<int> refreshDerivedDataForPeakOsmIds(Iterable<int> peakOsmIds) async {
    final refreshedOsmIds = peakOsmIds.toSet();
    if (refreshedOsmIds.isEmpty) {
      return 0;
    }

    var changedCount = 0;
    for (final peakList in _storage.getAll()) {
      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        continue;
      }

      if (!items.any((item) => refreshedOsmIds.contains(item.peakOsmId))) {
        continue;
      }

      final updated = _recomputePeakListDerivedDataFromItems(
        _normalizePeakListForStorage(peakList),
        items,
      );
      if (_peakListDerivedDataMatches(updated, peakList)) {
        continue;
      }

      await _storage.put(updated);
      changedCount += 1;
    }

    return changedCount;
  }

  PeakList _requireById(int peakListId) {
    final peakList = findById(peakListId);
    if (peakList == null) {
      throw StateError('Peak list not found');
    }
    return peakList;
  }

  void _validateAddedPeakItems({
    required PeakList peakList,
    required List<PeakListItem> existingItems,
    required List<PeakListItem> addedItems,
  }) {
    final existingPeakIds = existingItems
        .map((entry) => entry.peakOsmId)
        .toSet();
    final addedPeakIds = <int>{};

    for (final item in addedItems) {
      if (!addedPeakIds.add(item.peakOsmId) ||
          existingPeakIds.contains(item.peakOsmId)) {
        throw StateError('Peak already exists in list');
      }
    }

    if (peakList.name != TassyFullPeakListSyncService.targetName) {
      return;
    }

    for (final item in addedItems) {
      if (findPeakByOsmId(item.peakOsmId)?.region != Peak.defaultRegion) {
        throw StateError(tassyFullTasmaniaOnlyError);
      }
    }
  }

  PeakList _normalizePeakListForStorage(PeakList peakList) {
    return peakList.copyWith(
      region: normalizeStoredPeakListRegion(peakList.region),
    );
  }

  PeakList _recomputePeakListDerivedData(PeakList peakList) {
    final normalizedPeakList = _normalizePeakListForStorage(peakList);
    final items = decodePeakListItems(normalizedPeakList.peakList);
    return _recomputePeakListDerivedDataFromItems(normalizedPeakList, items);
  }

  PeakList? _tryRecomputePeakListDerivedData(PeakList peakList) {
    try {
      return _recomputePeakListDerivedData(peakList);
    } catch (_) {
      return null;
    }
  }

  PeakList _recomputePeakListDerivedDataFromItems(
    PeakList peakList,
    List<PeakListItem> items,
  ) {
    final derivedData = derivePeakListDerivedData(
      peakList: peakList,
      items: items,
      peakResolver: findPeakByOsmId,
    );
    return derivedData.applyTo(peakList);
  }

  bool _peakListDerivedDataMatches(PeakList left, PeakList right) {
    return left.region == right.region &&
        left.minLat == right.minLat &&
        left.maxLat == right.maxLat &&
        left.minLng == right.minLng &&
        left.maxLng == right.maxLng;
  }

  Future<PeakList> _ensureStoredColour(PeakList peakList) async {
    if (peakList.colour != 0) {
      return peakList;
    }

    final updated = peakList.copyWith(
      colour: defaultPeakListColourForId(peakList.peakListId),
    );
    return _storage.put(updated);
  }
}
