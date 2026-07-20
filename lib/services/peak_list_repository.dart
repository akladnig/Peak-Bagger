import 'dart:developer' as developer;

import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/fab_colour_resolver.dart';
import 'package:peak_bagger/services/peak_list_derived_data.dart';
import 'package:peak_bagger/services/peak_list_visibility.dart';
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

abstract class PeakListItemEntityStorage {
  List<PeakListItemEntity> getAll();

  List<PeakListItemEntity> getByPeakListId(int peakListId);

  Future<void> addForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  );

  Future<bool> updatePointsForPeakListItem({
    required int peakListId,
    required int peakOsmId,
    required int points,
  });

  Future<bool> deletePeakListItem({
    required int peakListId,
    required int peakOsmId,
  });

  Future<void> replaceForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  );

  Future<void> deleteForPeakList(int peakListId);
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

class ObjectBoxPeakListItemEntityStorage implements PeakListItemEntityStorage {
  ObjectBoxPeakListItemEntityStorage(this._store)
    : _itemBox = _store.box<PeakListItemEntity>();

  final Store _store;
  final Box<PeakListItemEntity> _itemBox;

  @override
  List<PeakListItemEntity> getAll() {
    final items = _itemBox.getAll().toList(growable: false);
    items.sort((left, right) => left.id.compareTo(right.id));
    return items;
  }

  @override
  List<PeakListItemEntity> getByPeakListId(int peakListId) {
    final query = _itemBox.query(PeakListItemEntity_.peakList.equals(peakListId)).build();
    try {
      final items = query.find().toList(growable: false);
      items.sort((left, right) => left.id.compareTo(right.id));
      return items;
    } finally {
      query.close();
    }
  }

  @override
  Future<void> addForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  ) async {
    if (items.isEmpty) {
      return;
    }
    _store.runInTransaction(TxMode.write, () {
      _itemBox.putMany(items);
    });
  }

  @override
  Future<bool> updatePointsForPeakListItem({
    required int peakListId,
    required int peakOsmId,
    required int points,
  }) async {
    final existing = getByPeakListId(peakListId).where((item) {
      return item.peak.target?.osmId == peakOsmId;
    }).toList(growable: false);
    if (existing.isEmpty) {
      return false;
    }

    _store.runInTransaction(TxMode.write, () {
      for (final item in existing) {
        item.points = points;
      }
      _itemBox.putMany(existing);
    });
    return true;
  }

  @override
  Future<bool> deletePeakListItem({
    required int peakListId,
    required int peakOsmId,
  }) async {
    final ids = getByPeakListId(peakListId)
        .where((item) => item.peak.target?.osmId == peakOsmId)
        .map((item) => item.id)
        .toList(growable: false);
    if (ids.isEmpty) {
      return false;
    }

    _store.runInTransaction(TxMode.write, () {
      _itemBox.removeMany(ids);
    });
    return true;
  }

  @override
  Future<void> replaceForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  ) async {
    _store.runInTransaction(TxMode.write, () {
      final existingIds = getByPeakListId(peakList.peakListId)
          .map((item) => item.id)
          .toList(growable: false);
      if (existingIds.isNotEmpty) {
        _itemBox.removeMany(existingIds);
      }
      if (items.isNotEmpty) {
        _itemBox.putMany(items);
      }
    });
  }

  @override
  Future<void> deleteForPeakList(int peakListId) async {
    final ids = getByPeakListId(peakListId)
        .map((item) => item.id)
        .toList(growable: false);
    if (ids.isNotEmpty) {
      _itemBox.removeMany(ids);
    }
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

class InMemoryPeakListItemEntityStorage implements PeakListItemEntityStorage {
  InMemoryPeakListItemEntityStorage([List<PeakListItemEntity> items = const []])
    : _items = List<PeakListItemEntity>.from(items),
      _nextId = items.fold<int>(1, (maxId, item) {
        final candidate = item.id + 1;
        return candidate > maxId ? candidate : maxId;
      });

  List<PeakListItemEntity> _items;
  int _nextId;

  @override
  List<PeakListItemEntity> getAll() {
    final items = List<PeakListItemEntity>.from(_items);
    items.sort((left, right) => left.id.compareTo(right.id));
    return List<PeakListItemEntity>.unmodifiable(items);
  }

  @override
  List<PeakListItemEntity> getByPeakListId(int peakListId) {
    return getAll()
        .where((item) => item.peakList.target?.peakListId == peakListId)
        .toList(growable: false);
  }

  @override
  Future<void> addForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  ) async {
    if (items.isEmpty) {
      return;
    }

    final storedItems = <PeakListItemEntity>[];
    for (final item in items) {
      final stored = PeakListItemEntity(id: _nextId++, points: item.points)
        ..peakList.target = peakList
        ..peak.target = item.peak.target;
      storedItems.add(stored);
    }
    _items = [..._items, ...storedItems];
  }

  @override
  Future<bool> updatePointsForPeakListItem({
    required int peakListId,
    required int peakOsmId,
    required int points,
  }) async {
    var updated = false;
    _items = [
      for (final item in _items)
        if (item.peakList.target?.peakListId == peakListId &&
            item.peak.target?.osmId == peakOsmId)
          () {
            updated = true;
            return PeakListItemEntity(id: item.id, points: points)
              ..peakList.target = item.peakList.target
              ..peak.target = item.peak.target;
          }()
        else
          item,
    ];
    return updated;
  }

  @override
  Future<bool> deletePeakListItem({
    required int peakListId,
    required int peakOsmId,
  }) async {
    final originalLength = _items.length;
    _items = _items.where((item) {
      return item.peakList.target?.peakListId != peakListId ||
          item.peak.target?.osmId != peakOsmId;
    }).toList(growable: false);
    return _items.length != originalLength;
  }

  @override
  Future<void> replaceForPeakList(
    PeakList peakList,
    List<PeakListItemEntity> items,
  ) async {
    _items = _items
        .where((item) => item.peakList.target?.peakListId != peakList.peakListId)
        .toList(growable: false);
    final storedItems = <PeakListItemEntity>[];
    for (final item in items) {
      final stored = PeakListItemEntity(id: _nextId++, points: item.points)
        ..peakList.target = peakList
        ..peak.target = item.peak.target;
      storedItems.add(stored);
    }
    _items = [..._items, ...storedItems];
  }

  @override
  Future<void> deleteForPeakList(int peakListId) async {
    _items = _items
        .where((item) => item.peakList.target?.peakListId != peakListId)
        .toList(growable: false);
  }
}

class PeakListRepository {
  static const String tassyFullTasmaniaOnlyError =
      'Tassy Full only accepts Tasmanian peaks.';

  PeakListRepository(Store store, {this.peakRepository})
    : _storage = ObjectBoxPeakListStorage(store),
      _itemStorage = ObjectBoxPeakListItemEntityStorage(store);

  PeakListRepository.test(
    PeakListStorage storage, {
    PeakListItemEntityStorage? itemStorage,
    this.peakRepository,
  }) : _storage = storage,
       _itemStorage = itemStorage ?? InMemoryPeakListItemEntityStorage();

  final PeakListStorage _storage;
  final PeakListItemEntityStorage _itemStorage;
  final PeakRepository? peakRepository;

  PeakListStorage get storage => _storage;

  int get peakListCount => _storage.count;

  List<PeakList> getAllPeakLists() {
    return _storage.getAll();
  }

  List<PeakListItem> getPeakListItemsForList(int peakListId) {
    _requireById(peakListId);
    return _loadStoredPeakListItems(peakListId);
  }

  Map<int, List<PeakListItem>> getPeakListItemsByPeakListId() {
    final stopwatch = _peakListsPerfEnabled ? (Stopwatch()..start()) : null;
    final itemsByPeakListId = <int, List<PeakListItem>>{};
    for (final entity in _itemStorage.getAll()) {
      final peakListId = entity.peakList.hasValue
          ? entity.peakList.target?.peakListId ?? 0
          : entity.peakList.targetId;
      final item = _peakListItemFromEntity(entity);
      if (peakListId == 0 || item == null) {
        continue;
      }
      itemsByPeakListId.putIfAbsent(peakListId, () => []).add(item);
    }

    final result = Map<int, List<PeakListItem>>.unmodifiable({
      for (final entry in itemsByPeakListId.entries)
        entry.key: List<PeakListItem>.unmodifiable(entry.value),
    });
    stopwatch.logPeakListsPerf(
      'Grouped ${result.length} peak lists from ${itemsByPeakListId.values.fold<int>(0, (sum, items) => sum + items.length)} memberships',
    );
    return result;
  }

  List<String> findPeakListNamesForPeak(int peakOsmId) {
    final names = <String>{};

    for (final peakList in _storage.getAll()) {
      final items = _loadStoredPeakListItems(peakList.peakListId);
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
    return peakRepository?.findByOsmId(peakOsmId);
  }

  PeakRepository _requirePeakRepository() {
    final repository = peakRepository;
    if (repository == null) {
      throw StateError('Peak repository is required for peak-list memberships.');
    }
    return repository;
  }

  Map<int, String?> peakRegionsByOsmId() {
    final repository = peakRepository;
    if (repository == null) {
      return const {};
    }

    return {
      for (final peak in repository.getAllPeaks())
        peak.osmId: canonicalPeakRegionKey(peak),
    };
  }

  Future<void> delete(int peakListId) async {
    await _itemStorage.deleteForPeakList(peakListId);
    await _storage.delete(peakListId);
  }

  Future<PeakList> save(
    PeakList peakList, {
    List<PeakListItem>? items,
    void Function()? beforePutForTest,
    bool recomputeDerivedFields = false,
  }) async {
    return saveWithoutSync(
      peakList,
      items: items,
      beforePutForTest: beforePutForTest,
      recomputeDerivedFields: recomputeDerivedFields,
    );
  }

  Future<PeakList> saveWithoutSync(
    PeakList peakList, {
    List<PeakListItem>? items,
    void Function()? beforePutForTest,
    bool recomputeDerivedFields = false,
  }) async {
    final normalizedPeakList = _normalizePeakListForStorage(peakList);
    if (items != null) {
      return _savePeakListWithItems(
        normalizedPeakList,
        items,
        beforePutForTest: beforePutForTest,
        recomputeDerivedFields: recomputeDerivedFields,
      );
    }

    var nextPeakList = normalizedPeakList;
    if (recomputeDerivedFields) {
      nextPeakList = _recomputePeakListDerivedDataFromItems(
        nextPeakList,
        _loadExistingPeakListItems(nextPeakList),
      );
    }

    final saved = await _savePeakListMetadata(
      nextPeakList,
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
    final existingItems = _loadStoredPeakListItems(peakListId);

    _validateAddedPeakItems(
      peakList: peakList,
      existingItems: existingItems,
      addedItems: items,
    );

    final savedPeakList = await _savePeakListMembershipMetadata(
      peakList: peakList,
      items: [...existingItems, ...items],
      recomputeDerivedFields: true,
    );
    final storedItems = [
      for (final item in items)
        _buildStoredItemEntity(peakList: savedPeakList, item: item),
    ];
    await _itemStorage.addForPeakList(savedPeakList, storedItems);
    return savedPeakList;
  }

  Future<PeakList> updatePeakItemPoints({
    required int peakListId,
    required int peakOsmId,
    required int points,
  }) async {
    final peakList = _requireById(peakListId);
    final items = _loadStoredPeakListItems(peakListId);
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

    final updated = await _itemStorage.updatePointsForPeakListItem(
      peakListId: peakListId,
      peakOsmId: peakOsmId,
      points: points,
    );
    if (!updated) {
      throw StateError('Peak not found in list');
    }
    return _ensureStoredColour(peakList);
  }

  Future<PeakList> removePeakItem({
    required int peakListId,
    required int peakOsmId,
  }) async {
    final peakList = _requireById(peakListId);
    final items = _loadStoredPeakListItems(peakListId);
    final updatedItems = items
        .where((item) => item.peakOsmId != peakOsmId)
        .toList(growable: false);

    if (updatedItems.length == items.length) {
      throw StateError('Peak not found in list');
    }

    final deleted = await _itemStorage.deletePeakListItem(
      peakListId: peakListId,
      peakOsmId: peakOsmId,
    );
    if (!deleted) {
      throw StateError('Peak not found in list');
    }
    return _savePeakListMembershipMetadata(
      peakList: peakList,
      items: updatedItems,
      recomputeDerivedFields: true,
    );
  }

  Future<bool> backfillStoredPeakLists() async {
    var changed = false;

    for (final peakList in _storage.getAll()) {
      final items = _loadStoredPeakListItems(peakList.peakListId);
      final updated = _recomputePeakListDerivedDataFromItems(
        _normalizePeakListForStorage(peakList),
        items,
      );
      if (_peakListDerivedDataMatches(updated, peakList)) {
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
      final items = _loadStoredPeakListItems(peakList.peakListId);

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
      final peak = findPeakByOsmId(item.peakOsmId);
      if (peak == null || canonicalPeakRegionKey(peak) != Peak.defaultRegion) {
        throw StateError(tassyFullTasmaniaOnlyError);
      }
    }
  }

  PeakList _normalizePeakListForStorage(PeakList peakList) {
    return peakList.copyWith(
      region: normalizeStoredPeakListRegion(peakList.region),
    );
  }

  List<PeakListItem> _loadExistingPeakListItems(PeakList peakList) {
    if (peakList.peakListId != 0) {
      return _loadStoredPeakListItems(peakList.peakListId);
    }

    final existing = _storage.getByName(peakList.name);
    if (existing == null) {
      return const <PeakListItem>[];
    }

    return _loadStoredPeakListItems(existing.peakListId);
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

  Future<PeakList> _savePeakListMembershipMetadata({
    required PeakList peakList,
    required List<PeakListItem> items,
    required bool recomputeDerivedFields,
  }) async {
    var nextPeakList = _normalizePeakListForStorage(peakList);
    if (recomputeDerivedFields) {
      nextPeakList = _recomputePeakListDerivedDataFromItems(nextPeakList, items);
    }
    final saved = await _savePeakListMetadata(nextPeakList);
    return _ensureStoredColour(saved);
  }

  Future<PeakList> _savePeakListMetadata(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    final existing = _storage.getByName(peakList.name);
    if (existing == null) {
      return _storage.put(peakList);
    }

    return _storage.replaceByName(
      peakList.copyWith(peakListId: existing.peakListId),
      beforePutForTest: beforePutForTest,
    );
  }

  Future<PeakList> _savePeakListWithItems(
    PeakList peakList,
    List<PeakListItem> items, {
    void Function()? beforePutForTest,
    bool recomputeDerivedFields = false,
  }) async {
    _requireResolvedPeaks(items);
    var nextPeakList = _normalizePeakListForStorage(peakList);
    if (recomputeDerivedFields) {
      nextPeakList = _recomputePeakListDerivedDataFromItems(nextPeakList, items);
    }
    final saved = await _savePeakListMetadata(
      nextPeakList,
      beforePutForTest: beforePutForTest,
    );
    final storedItems = [
      for (final item in items) _buildStoredItemEntity(peakList: saved, item: item),
    ];
    await _itemStorage.replaceForPeakList(saved, storedItems);
    return _ensureStoredColour(saved);
  }

  PeakListItemEntity _buildStoredItemEntity({
    required PeakList peakList,
    required PeakListItem item,
  }) {
    final peak = _requirePeakRepository().findByOsmId(item.peakOsmId);
    if (peak == null) {
      throw StateError('Peak not found for osmId ${item.peakOsmId}');
    }
    return PeakListItemEntity(points: item.points)
      ..peakList.target = peakList
      ..peak.target = peak;
  }

  void _requireResolvedPeaks(List<PeakListItem> items) {
    final repository = _requirePeakRepository();
    for (final item in items) {
      if (repository.findByOsmId(item.peakOsmId) == null) {
        throw StateError('Peak not found for osmId ${item.peakOsmId}');
      }
    }
  }

  List<PeakListItem> _loadStoredPeakListItems(int peakListId) {
    final entityRows = _itemStorage.getByPeakListId(peakListId);
    final items = <PeakListItem>[];
    for (final entity in entityRows) {
      final item = _peakListItemFromEntity(entity);
      if (item == null) {
        continue;
      }
      items.add(item);
    }
    return List<PeakListItem>.unmodifiable(items);
  }

  PeakListItem? _peakListItemFromEntity(PeakListItemEntity entity) {
    final peak = entity.peak.target;
    if (peak == null || peak.osmId == 0) {
      return null;
    }
    return PeakListItem(peakOsmId: peak.osmId, points: entity.points);
  }
}

const _peakListsPerfEnabled = bool.fromEnvironment('PEAK_LISTS_PERF');

extension on Stopwatch? {
  void logPeakListsPerf(String message) {
    final stopwatch = this;
    if (!_peakListsPerfEnabled || stopwatch == null) {
      return;
    }
    developer.log(
      '$message in ${stopwatch.elapsedMilliseconds}ms',
      name: 'peak_lists_perf',
    );
  }
}
