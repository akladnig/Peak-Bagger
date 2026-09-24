import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/natural_feature.dart';

import '../objectbox.g.dart';

abstract class NaturalFeatureStorage {
  List<NaturalFeature> getAll();

  NaturalFeature? getById(int id);

  int put(NaturalFeature naturalFeature);

  bool remove(int id);

  void putAllAtomically(List<NaturalFeature> naturalFeatures);
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
  void putAllAtomically(List<NaturalFeature> naturalFeatures) {
    _store.runInTransaction(TxMode.write, () {
      for (var index = 0; index < naturalFeatures.length; index++) {
        _box.put(naturalFeatures[index]);
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
  void putAllAtomically(List<NaturalFeature> naturalFeatures) {
    final previousFeatures = List<NaturalFeature>.from(_naturalFeatures);
    final previousNextId = _nextId;
    try {
      for (var index = 0; index < naturalFeatures.length; index++) {
        put(naturalFeatures[index]);
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
  }) {
    for (final naturalFeature in _storage.getAll()) {
      if (naturalFeature.osmType == osmType && naturalFeature.osmId == osmId) {
        return naturalFeature;
      }
    }
    return null;
  }

  NaturalFeature save(NaturalFeature naturalFeature) {
    naturalFeature.id = _storage.put(naturalFeature);
    return naturalFeature;
  }

  void upsertAllAtomically(List<NaturalFeature> naturalFeatures) {
    _storage.putAllAtomically(naturalFeatures);
  }

  bool delete(int id) => _storage.remove(id);
}
