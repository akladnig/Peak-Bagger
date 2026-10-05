import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/natural_feature.dart';

import '../objectbox.g.dart';

abstract class NaturalFeatureStorage {
  List<NaturalFeature> getAll();

  NaturalFeature? getById(int id);

  int put(NaturalFeature naturalFeature);

  bool remove(int id);

  void reconcileAtomically({
    required List<NaturalFeature> upserts,
    required List<int> deletedIds,
  });
}

enum NaturalFeatureWriteFailure { afterFirstWrite }

class ObjectBoxNaturalFeatureStorage implements NaturalFeatureStorage {
  ObjectBoxNaturalFeatureStorage(Store store, {this.failureForTest})
    : _store = store,
      _box = store.box<NaturalFeature>();

  final Store _store;
  final Box<NaturalFeature> _box;
  final NaturalFeatureWriteFailure? failureForTest;

  @override
  List<NaturalFeature> getAll() => _box.getAll();

  @override
  NaturalFeature? getById(int id) => _box.get(id);

  @override
  int put(NaturalFeature naturalFeature) => _box.put(naturalFeature);

  @override
  bool remove(int id) => _box.remove(id);

  @override
  void reconcileAtomically({
    required List<NaturalFeature> upserts,
    required List<int> deletedIds,
  }) {
    _store.runInTransaction(TxMode.write, () {
      for (final id in deletedIds) {
        _box.remove(id);
      }
      for (var index = 0; index < upserts.length; index++) {
        _box.put(upserts[index]);
        if (failureForTest == NaturalFeatureWriteFailure.afterFirstWrite &&
            index == 0) {
          throw StateError(
            'Injected failure after the first Natural Feature write',
          );
        }
      }
    });
  }
}

class InMemoryNaturalFeatureStorage implements NaturalFeatureStorage {
  InMemoryNaturalFeatureStorage([
    List<NaturalFeature> naturalFeatures = const [],
  ]) : failureForTest = null,
       _naturalFeatures = List<NaturalFeature>.from(naturalFeatures),
       _nextId = _nextGeneratedId(naturalFeatures);

  InMemoryNaturalFeatureStorage.withFailureForTest({
    required List<NaturalFeature> naturalFeatures,
    required this.failureForTest,
  }) : _naturalFeatures = List<NaturalFeature>.from(naturalFeatures),
       _nextId = _nextGeneratedId(naturalFeatures);

  List<NaturalFeature> _naturalFeatures;
  int _nextId;
  final NaturalFeatureWriteFailure? failureForTest;

  static int _nextGeneratedId(List<NaturalFeature> naturalFeatures) {
    return naturalFeatures.fold<int>(1, (nextId, naturalFeature) {
      return naturalFeature.id >= nextId ? naturalFeature.id + 1 : nextId;
    });
  }

  @override
  List<NaturalFeature> getAll() =>
      List<NaturalFeature>.unmodifiable(_naturalFeatures);

  @override
  NaturalFeature? getById(int id) {
    for (final naturalFeature in _naturalFeatures) {
      if (naturalFeature.id == id) {
        return naturalFeature;
      }
    }
    return null;
  }

  @override
  int put(NaturalFeature naturalFeature) {
    if (naturalFeature.sourceRecordKey != null &&
        _naturalFeatures.any(
          (existing) =>
              existing.id != naturalFeature.id &&
              existing.sourceRecordKey == naturalFeature.sourceRecordKey,
        )) {
      throw StateError('Duplicate Natural Feature source identity.');
    }
    if (naturalFeature.id == 0) {
      naturalFeature.id = _nextId++;
    } else if (naturalFeature.id >= _nextId) {
      _nextId = naturalFeature.id + 1;
    }
    _naturalFeatures = [
      for (final existing in _naturalFeatures)
        if (existing.id != naturalFeature.id) existing,
      naturalFeature,
    ];
    return naturalFeature.id;
  }

  @override
  bool remove(int id) {
    final initialCount = _naturalFeatures.length;
    _naturalFeatures = _naturalFeatures
        .where((naturalFeature) => naturalFeature.id != id)
        .toList(growable: false);
    return _naturalFeatures.length != initialCount;
  }

  @override
  void reconcileAtomically({
    required List<NaturalFeature> upserts,
    required List<int> deletedIds,
  }) {
    final previousFeatures = List<NaturalFeature>.from(_naturalFeatures);
    final previousNextId = _nextId;
    try {
      for (final id in deletedIds) {
        remove(id);
      }
      for (var index = 0; index < upserts.length; index++) {
        put(upserts[index]);
        if (failureForTest == NaturalFeatureWriteFailure.afterFirstWrite &&
            index == 0) {
          throw StateError(
            'Injected failure after the first Natural Feature write',
          );
        }
      }
    } catch (_) {
      _naturalFeatures = previousFeatures;
      _nextId = previousNextId;
      rethrow;
    }
  }
}

class NaturalFeatureRepository {
  NaturalFeatureRepository(Store store)
    : _storage = ObjectBoxNaturalFeatureStorage(store);

  NaturalFeatureRepository.test(NaturalFeatureStorage storage)
    : _storage = storage;

  final NaturalFeatureStorage _storage;

  List<NaturalFeature> getAllNaturalFeatures() => _storage.getAll();

  NaturalFeature? findById(int id) => _storage.getById(id);

  NaturalFeature? findByOsmIdentity({
    required String osmType,
    required int osmId,
    String ownership = 'OSM',
  }) {
    for (final naturalFeature in _storage.getAll()) {
      if (naturalFeature.sourceOfTruth == ownership &&
          naturalFeature.osmType == osmType &&
          naturalFeature.osmId == osmId) {
        return naturalFeature;
      }
    }
    return null;
  }

  NaturalFeature save(NaturalFeature naturalFeature) {
    final key =
        '${naturalFeature.sourceOfTruth}:${naturalFeature.osmType}:${naturalFeature.osmId}';
    naturalFeature.sourceKey = key;
    naturalFeature.sourceRecordKey = key;
    naturalFeature.id = _storage.put(naturalFeature);
    return naturalFeature;
  }

  bool isEmpty() => _storage.getAll().isEmpty;

  void reconcileAtomically({
    required List<NaturalFeature> upserts,
    required List<int> deletedIds,
  }) {
    _storage.reconcileAtomically(upserts: upserts, deletedIds: deletedIds);
  }

  bool delete(int id) => _storage.remove(id);
}
