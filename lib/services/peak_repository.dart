import 'package:peak_bagger/models/peak.dart';

import '../objectbox.g.dart';

abstract class PeakStorage {
  int get count;

  List<Peak> getAll();

  List<Peak> getByName(String query);

  bool get isEmpty;

  Future<void> addMany(List<Peak> peaks);

  Future<Peak> put(Peak peak);

  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  });

  Future<void> clearAll();
}

class ObjectBoxPeakStorage implements PeakStorage {
  ObjectBoxPeakStorage(this._store) : _peakBox = _store.box<Peak>();

  final Store _store;
  final Box<Peak> _peakBox;

  @override
  int get count => _peakBox.count();

  @override
  List<Peak> getAll() => _peakBox.getAll();

  @override
  List<Peak> getByName(String query) {
    final queryBuilder = _peakBox
        .query(Peak_.name.contains(query, caseSensitive: false))
        .build();
    final results = queryBuilder.find();
    queryBuilder.close();
    return results;
  }

  @override
  bool get isEmpty => _peakBox.isEmpty();

  @override
  Future<void> addMany(List<Peak> peaks) async {
    _peakBox.putMany(peaks);
  }

  @override
  Future<Peak> put(Peak peak) async {
    final id = _peakBox.put(peak);
    peak.id = id;
    return peak;
  }

  @override
  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  }) async {
    _store.runInTransaction(TxMode.write, () {
      _peakBox.removeAll();
      beforePutManyForTest?.call();
      if (peaks.isNotEmpty) {
        _peakBox.putMany(peaks);
      }
    });
  }

  @override
  Future<void> clearAll() async {
    _peakBox.removeAll();
  }
}

class InMemoryPeakStorage implements PeakStorage {
  InMemoryPeakStorage([List<Peak> peaks = const []])
    : _peaks = List<Peak>.from(peaks),
      _nextId = peaks.fold<int>(1, (maxId, peak) {
        final candidate = peak.id + 1;
        return candidate > maxId ? candidate : maxId;
      });

  List<Peak> _peaks;
  int _nextId;

  @override
  int get count => _peaks.length;

  @override
  List<Peak> getAll() => List<Peak>.unmodifiable(_peaks);

  @override
  List<Peak> getByName(String query) {
    final lowered = query.toLowerCase();
    return _peaks
        .where((peak) => peak.name.toLowerCase().contains(lowered))
        .toList(growable: false);
  }

  @override
  bool get isEmpty => _peaks.isEmpty;

  @override
  Future<void> addMany(List<Peak> peaks) async {
    _peaks = [..._peaks, ...peaks];
  }

  @override
  Future<Peak> put(Peak peak) async {
    final index = _peaks.indexWhere(
      (existing) =>
          (peak.id != 0 && existing.id == peak.id) ||
          existing.osmId == peak.osmId,
    );
    if (index == -1) {
      final stored = peak.copyWith();
      stored.id = peak.id == 0 ? _nextId++ : peak.id;
      _peaks = [..._peaks, stored];
      return stored;
    }

    final nextPeaks = List<Peak>.from(_peaks);
    nextPeaks[index] = peak;
    _peaks = nextPeaks;
    return peak;
  }

  @override
  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  }) async {
    final snapshot = List<Peak>.from(_peaks);
    try {
      _peaks = [];
      beforePutManyForTest?.call();
      _peaks = List<Peak>.from(peaks);
    } catch (_) {
      _peaks = snapshot;
      rethrow;
    }
  }

  @override
  Future<void> clearAll() async {
    _peaks = [];
  }
}

class PeakRepository {
  PeakRepository(Store store) : _storage = ObjectBoxPeakStorage(store);

  PeakRepository.test(PeakStorage storage) : _storage = storage;

  final PeakStorage _storage;

  int get peakCount => _storage.count;

  List<Peak> getAllPeaks() {
    return _storage.getAll();
  }

  List<Peak> getPeaksByName(String query) {
    return _storage.getByName(query);
  }

  List<Peak> searchPeaks(String query) {
    if (query.isEmpty) return getAllPeaks();

    final queryLower = query.toLowerCase();
    final allPeaks = getAllPeaks();

    return allPeaks.where((peak) {
      final nameMatch = peak.name.toLowerCase().contains(queryLower);
      final elevMatch =
          peak.elevation != null && peak.elevation!.toString().contains(query);
      return nameMatch || elevMatch;
    }).toList();
  }

  Peak? findByOsmId(int osmId) {
    for (final peak in _storage.getAll()) {
      if (peak.osmId == osmId) {
        return peak;
      }
    }

    return null;
  }

  int nextSyntheticOsmId([Iterable<Peak>? peaks]) {
    final source = peaks ?? _storage.getAll();
    var nextSyntheticOsmId = -1;
    for (final peak in source) {
      if (peak.osmId <= nextSyntheticOsmId) {
        nextSyntheticOsmId = peak.osmId - 1;
      }
    }
    return nextSyntheticOsmId;
  }

  Future<void> addPeaks(List<Peak> peaks) async {
    await _storage.addMany(peaks);
  }

  Future<Peak> save(Peak peak) async {
    return _storage.put(peak);
  }

  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
    bool preserveExistingIds = true,
  }) async {
    if (!preserveExistingIds) {
      await _storage.replaceAll(
        peaks,
        beforePutManyForTest: beforePutManyForTest,
      );
      return;
    }

    final existingPeaks = _storage.getAll();
    if (existingPeaks.any((peak) => peak.osmId == 0)) {
      await _storage.replaceAll(
        peaks,
        beforePutManyForTest: beforePutManyForTest,
      );
      return;
    }

    final existingIdsByOsmId = <int, int>{
      for (final peak in existingPeaks) peak.osmId: peak.id,
    };

    for (final peak in peaks) {
      final existingId = existingIdsByOsmId[peak.osmId];
      if (existingId != null) {
        peak.id = existingId;
      }
    }

    await _storage.replaceAll(
      peaks,
      beforePutManyForTest: beforePutManyForTest,
    );
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
  }

  bool isEmpty() {
    return _storage.isEmpty;
  }
}
