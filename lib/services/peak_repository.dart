import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';

import '../objectbox.g.dart';

abstract class PeakStorage {
  int get count;

  Peak? getById(int peakId);

  List<Peak> getAll();

  List<Peak> getByName(String query);

  bool get isEmpty;

  Future<void> addMany(List<Peak> peaks);

  Peak put(Peak peak);

  Future<void> delete(int peakId);

  Future<void> replaceAll(
    List<Peak> peaks, {
    void Function()? beforePutManyForTest,
  });

  Future<void> clearAll();
}

class PeakListRewriteResult {
  const PeakListRewriteResult({
    required this.rewrittenCount,
    required this.skippedMalformedCount,
  });

  final int rewrittenCount;
  final int skippedMalformedCount;

  String? get warningMessage {
    return switch (skippedMalformedCount) {
      0 => null,
      1 => '1 PeakList has been skipped as it\'s malformed.',
      _ =>
        '$skippedMalformedCount PeakLists have been skipped as they\'re malformed.',
    };
  }
}

class PeakSaveResult {
  const PeakSaveResult({required this.peak, this.peakListRewriteResult});

  final Peak peak;
  final PeakListRewriteResult? peakListRewriteResult;

  String? get warningMessage => peakListRewriteResult?.warningMessage;
}

abstract class PeakListRewritePort {
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  });
}

class ObjectBoxPeakListRewritePort implements PeakListRewritePort {
  ObjectBoxPeakListRewritePort(Store store)
    : _peakListBox = store.box<PeakList>(),
      _peaksBaggedBox = store.box<PeaksBagged>();

  final Box<PeakList> _peakListBox;
  final Box<PeaksBagged> _peaksBaggedBox;

  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    var rewrittenCount = 0;
    var skippedMalformedCount = 0;

    final peakLists = _peakListBox.getAll().toList(growable: false)
      ..sort((a, b) {
        final nameCompare = a.name.compareTo(b.name);
        return nameCompare != 0
            ? nameCompare
            : a.peakListId.compareTo(b.peakListId);
      });

    for (final peakList in peakLists) {
      try {
        final items = decodePeakListItems(peakList.peakList);
        var changed = false;
        final updatedItems = <PeakListItem>[];
        for (final item in items) {
          if (item.peakOsmId == oldOsmId) {
            updatedItems.add(
              PeakListItem(peakOsmId: newOsmId, points: item.points),
            );
            changed = true;
          } else {
            updatedItems.add(item);
          }
        }

        if (changed) {
          rewrittenCount += 1;
          peakList.peakList = encodePeakListItems(updatedItems);
          _peakListBox.put(peakList);
        }
      } catch (_) {
        skippedMalformedCount += 1;
      }
    }

    final baggedRows = _peaksBaggedBox.getAll().toList(growable: false);
    var baggedChanged = false;
    for (final row in baggedRows) {
      if (row.peakId != oldOsmId) {
        continue;
      }
      row.peakId = newOsmId;
      baggedChanged = true;
    }
    if (baggedChanged) {
      _peaksBaggedBox.putMany(
        baggedRows
            .where((row) => row.peakId == newOsmId)
            .toList(growable: false),
      );
    }

    return PeakListRewriteResult(
      rewrittenCount: rewrittenCount,
      skippedMalformedCount: skippedMalformedCount,
    );
  }
}

class ObjectBoxPeakStorage implements PeakStorage {
  ObjectBoxPeakStorage(this._store) : _peakBox = _store.box<Peak>();

  final Store _store;
  final Box<Peak> _peakBox;

  @override
  int get count => _peakBox.count();

  @override
  Peak? getById(int peakId) => _peakBox.get(peakId);

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
  Peak put(Peak peak) {
    final id = _peakBox.put(peak);
    peak.id = id;
    return peak;
  }

  @override
  Future<void> delete(int peakId) async {
    _peakBox.remove(peakId);
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
  Peak? getById(int peakId) {
    for (final peak in _peaks) {
      if (peak.id == peakId) {
        return peak;
      }
    }

    return null;
  }

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
  Peak put(Peak peak) {
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
  Future<void> delete(int peakId) async {
    _peaks = _peaks.where((peak) => peak.id != peakId).toList(growable: false);
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
  PeakRepository(
    Store store, {
    required PeakListRewritePort peakListRewritePort,
  }) : _storage = ObjectBoxPeakStorage(store),
       _store = store,
       _peakListRewritePort = peakListRewritePort;

  PeakRepository.test(
    PeakStorage storage, {
    PeakListRewritePort? peakListRewritePort,
  }) : _storage = storage,
       _store = null,
       _peakListRewritePort = peakListRewritePort ?? _NoopPeakListRewritePort();

  final PeakStorage _storage;
  final Store? _store;
  final PeakListRewritePort _peakListRewritePort;

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

  Peak? findById(int peakId) {
    return _storage.getById(peakId);
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
    return (await saveDetailed(peak)).peak;
  }

  Future<PeakSaveResult> saveDetailed(Peak peak) async {
    final previous = peak.id != 0
        ? _storage.getById(peak.id)
        : findByOsmId(peak.osmId);
    Peak savedPeak = peak;
    PeakListRewriteResult? rewriteResult;
    final store = _store;

    if (store == null) {
      savedPeak = _storage.put(peak);
      if (previous != null && previous.osmId != savedPeak.osmId) {
        rewriteResult = _peakListRewritePort.rewriteOsmIdReferences(
          oldOsmId: previous.osmId,
          newOsmId: savedPeak.osmId,
        );
      }
      return PeakSaveResult(
        peak: savedPeak,
        peakListRewriteResult: rewriteResult,
      );
    }

    store.runInTransaction(TxMode.write, () {
      savedPeak = _storage.put(peak);
      if (previous != null && previous.osmId != savedPeak.osmId) {
        rewriteResult = _peakListRewritePort.rewriteOsmIdReferences(
          oldOsmId: previous.osmId,
          newOsmId: savedPeak.osmId,
        );
      }
    });

    return PeakSaveResult(
      peak: savedPeak,
      peakListRewriteResult: rewriteResult,
    );
  }

  Future<void> delete(int peakId) async {
    await _storage.delete(peakId);
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

    final existingPeaksByOsmId = <int, Peak>{
      for (final peak in existingPeaks) peak.osmId: peak,
    };

    final replacementPeaks = peaks
        .map((peak) {
          final existingPeak = existingPeaksByOsmId[peak.osmId];
          if (existingPeak == null) {
            return peak;
          }

          return peak.copyWith(
            altName: existingPeak.altName,
            verified: existingPeak.verified,
          )..id = existingPeak.id;
        })
        .toList(growable: false);

    await _storage.replaceAll(
      replacementPeaks,
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

class _NoopPeakListRewritePort implements PeakListRewritePort {
  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    return const PeakListRewriteResult(
      rewrittenCount: 0,
      skippedMalformedCount: 0,
    );
  }
}
