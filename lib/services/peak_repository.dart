import 'dart:async';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/services/peak_list_derived_data.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:peak_bagger/services/peak_source.dart';

import '../core/number_formatters.dart';
import '../objectbox.g.dart';

abstract class PeakStorage {
  int get count;

  Peak? getById(int peakId);

  List<Peak> getAll();

  List<Peak> getByName(String query);

  List<Peak> getSearchPopupPeakNameCandidates(String query);

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
        '${formatCount(skippedMalformedCount)} PeakLists have been skipped as they\'re malformed.',
    };
  }
}

class PeakSaveResult {
  const PeakSaveResult({required this.peak, this.peakListRewriteResult});

  final Peak peak;
  final PeakListRewriteResult? peakListRewriteResult;

  String? get warningMessage => peakListRewriteResult?.warningMessage;
}

class PeakDuplicateResolutionResult {
  const PeakDuplicateResolutionResult._({
    required this.survivingPeak,
    required this.failureMessage,
  });

  const PeakDuplicateResolutionResult.success({required Peak survivingPeak})
    : this._(survivingPeak: survivingPeak, failureMessage: null);

  const PeakDuplicateResolutionResult.failure(String failureMessage)
    : this._(survivingPeak: null, failureMessage: failureMessage);

  final Peak? survivingPeak;
  final String? failureMessage;

  bool get isSuccess => failureMessage == null;
}

class PeakDuplicateResolutionException implements Exception {
  const PeakDuplicateResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class PeakListRewritePort {
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  });

  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  });

  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  });
}

class ObjectBoxPeakListRewritePort implements PeakListRewritePort {
  ObjectBoxPeakListRewritePort(Store store)
    : _peakListBox = store.box<PeakList>(),
      _peakBox = store.box<Peak>(),
      _peaksBaggedBox = store.box<PeaksBagged>(),
      _gpxTrackBox = store.box<GpxTrack>(),
      _routeBox = store.box<Route>();

  final Box<PeakList> _peakListBox;
  final Box<Peak> _peakBox;
  final Box<PeaksBagged> _peaksBaggedBox;
  final Box<GpxTrack> _gpxTrackBox;
  final Box<Route> _routeBox;

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

  @override
  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  }) {
    final refreshedOsmIds = {previousPeak.osmId, updatedPeak.osmId};
    final peaksByOsmId = {
      for (final peak in _peakBox.getAll()) peak.osmId: peak,
    };
    var refreshedCount = 0;

    for (final peakList in _peakListBox.getAll()) {
      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        continue;
      }

      if (!items.any((item) => refreshedOsmIds.contains(item.peakOsmId))) {
        continue;
      }

      final derivedData = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (peakOsmId) => peaksByOsmId[peakOsmId],
      );
      if (derivedData.matches(peakList)) {
        continue;
      }

      _peakListBox.put(derivedData.applyTo(peakList));
      refreshedCount += 1;
    }

    return refreshedCount;
  }

  @override
  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  }) {
    final peaksByOsmId = {
      for (final peak in _peakBox.getAll()) peak.osmId: peak,
    };
    final baggedPlan = _buildPeaksBaggedUpdates(
      _peaksBaggedBox.getAll(),
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final trackUpdates = _buildTrackUpdates(
      tracks: _gpxTrackBox.getAll(),
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final routeUpdates = _buildRouteUpdates(
      routes: _routeBox.getAll(),
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final peakListUpdates = _buildPeakListUpdates(
      peakLists: _peakListBox.getAll(),
      peaksByOsmId: peaksByOsmId,
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );

    if (peakListUpdates.isNotEmpty) {
      _peakListBox.putMany(
        peakListUpdates.map((update) => update.updated).toList(growable: false),
      );
    }
    if (baggedPlan.removeIds.isNotEmpty) {
      _peaksBaggedBox.removeMany(baggedPlan.removeIds);
    }
    if (baggedPlan.updates.isNotEmpty) {
      _peaksBaggedBox.putMany(
        baggedPlan.updates
            .map((update) => update.updated)
            .toList(growable: false),
      );
    }
    if (trackUpdates.isNotEmpty) {
      _gpxTrackBox.putMany(
        trackUpdates.map((update) => update.updated).toList(growable: false),
      );
    }
    if (routeUpdates.isNotEmpty) {
      _routeBox.putMany(
        routeUpdates.map((update) => update.updated).toList(growable: false),
      );
    }

    unawaited(peakStorage.delete(duplicatePeak.id));
  }
}

class InMemoryPeakListRewritePort implements PeakListRewritePort {
  InMemoryPeakListRewritePort({
    required this.peakLists,
    required this.peaksBagged,
    required this.tracks,
    required this.routes,
    required this.peakStorage,
    this.beforeApplyTrackWritesForTest,
  });

  final List<PeakList> peakLists;
  final List<PeaksBagged> peaksBagged;
  final List<GpxTrack> tracks;
  final List<Route> routes;
  final PeakStorage peakStorage;
  final void Function()? beforeApplyTrackWritesForTest;

  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    var rewrittenCount = 0;
    var skippedMalformedCount = 0;

    for (var index = 0; index < peakLists.length; index++) {
      final peakList = peakLists[index];
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
          peakLists[index] = peakList.copyWith(
            peakList: encodePeakListItems(updatedItems),
          );
        }
      } catch (_) {
        skippedMalformedCount += 1;
      }
    }

    for (var index = 0; index < peaksBagged.length; index++) {
      final row = peaksBagged[index];
      if (row.peakId == oldOsmId) {
        peaksBagged[index] = PeaksBagged(
          baggedId: row.baggedId,
          peakId: newOsmId,
          gpxId: row.gpxId,
          date: row.date,
        );
      }
    }

    return PeakListRewriteResult(
      rewrittenCount: rewrittenCount,
      skippedMalformedCount: skippedMalformedCount,
    );
  }

  @override
  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  }) {
    final peaksByOsmId = {
      for (final peak in peakStorage.getAll()) peak.osmId: peak,
    };
    final refreshedOsmIds = {previousPeak.osmId, updatedPeak.osmId};
    var refreshedCount = 0;

    for (var index = 0; index < peakLists.length; index++) {
      final peakList = peakLists[index];
      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        continue;
      }
      if (!items.any((item) => refreshedOsmIds.contains(item.peakOsmId))) {
        continue;
      }

      final derivedData = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (peakOsmId) => peaksByOsmId[peakOsmId],
      );
      peakLists[index] = derivedData.applyTo(peakList);
      refreshedCount += 1;
    }

    return refreshedCount;
  }

  @override
  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  }) {
    final peaksByOsmId = {
      for (final peak in this.peakStorage.getAll()) peak.osmId: peak,
    };
    final baggedPlan = _buildPeaksBaggedUpdates(
      peaksBagged,
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final trackUpdates = _buildTrackUpdates(
      tracks: tracks,
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final routeUpdates = _buildRouteUpdates(
      routes: routes,
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );
    final peakListUpdates = _buildPeakListUpdates(
      peakLists: peakLists,
      peaksByOsmId: peaksByOsmId,
      duplicatePeak: duplicatePeak,
      survivingPeak: survivingPeak,
    );

    final peakListSnapshot = peakLists
        .map(_clonePeakList)
        .toList(growable: false);
    final peaksBaggedSnapshot = peaksBagged
        .map(_clonePeaksBagged)
        .toList(growable: false);
    final trackSnapshot = tracks.map(_cloneTrack).toList(growable: false);
    final routeSnapshot = routes.map(_cloneRoute).toList(growable: false);

    try {
      _applyPeakListUpdates(peakLists, peakListUpdates);
      _applyPeaksBaggedUpdates(
        peaksBagged,
        updates: baggedPlan.updates,
        removeIds: baggedPlan.removeIds,
      );
      beforeApplyTrackWritesForTest?.call();
      _applyTrackUpdates(tracks, trackUpdates);
      _applyRouteUpdates(routes, routeUpdates);
      unawaited(peakStorage.delete(duplicatePeak.id));
    } catch (_) {
      _restorePeakLists(peakLists, peakListSnapshot);
      _restorePeaksBagged(peaksBagged, peaksBaggedSnapshot);
      _restoreTracks(tracks, trackSnapshot);
      _restoreRoutes(routes, routeSnapshot);
      rethrow;
    }
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
  List<Peak> getSearchPopupPeakNameCandidates(String query) {
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
  List<Peak> getSearchPopupPeakNameCandidates(String query) {
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

class PeakRepository implements PeakSource {
  PeakRepository(Store store, {required this._peakListRewritePort})
    : _storage = ObjectBoxPeakStorage(store),
      _store = store;

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

  @override
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

  List<Peak> searchPopupPeakCandidates({
    required String query,
    required MapSearchSort sort,
    String? regionKey,
    required int offset,
    required int limit,
  }) {
    if (query.isEmpty || limit <= 0) {
      return const [];
    }

    final start = offset < 0 ? 0 : offset;
    final candidates = <Peak>[];
    final seenIds = <String>{};

    void addCandidate(Peak peak) {
      if (!_peakMatchesPopupRegion(peak, regionKey: regionKey)) {
        return;
      }
      final resultId = _popupPeakResultId(peak);
      if (!seenIds.add(resultId)) {
        return;
      }
      candidates.add(peak);
    }

    for (final peak in _storage.getSearchPopupPeakNameCandidates(query)) {
      addCandidate(peak);
    }
    if (_queryCouldMatchElevation(query)) {
      for (final peak in _storage.getAll()) {
        final elevation = peak.elevation;
        if (elevation == null || !elevation.toString().contains(query)) {
          continue;
        }
        addCandidate(peak);
      }
    }

    candidates.sort(
      (left, right) => _comparePopupPeakCandidates(left, right, sort),
    );
    if (start >= candidates.length) {
      return const [];
    }
    final end = math.min(start + limit, candidates.length);
    return candidates.sublist(start, end);
  }

  int _comparePopupPeakCandidates(Peak left, Peak right, MapSearchSort sort) {
    final titleComparison = _popupPeakNormalizedTitle(
      left,
    ).compareTo(_popupPeakNormalizedTitle(right));
    if (titleComparison != 0) {
      return sort == MapSearchSort.nameAscending
          ? titleComparison
          : -titleComparison;
    }
    return _popupPeakResultId(left).compareTo(_popupPeakResultId(right));
  }

  String _popupPeakNormalizedTitle(Peak peak) => peak.name.trim().toLowerCase();

  String _popupPeakResultId(Peak peak) => '${peak.osmId}';

  bool _peakMatchesPopupRegion(Peak peak, {required String? regionKey}) {
    if (regionKey == null) {
      return true;
    }
    final resolvedRegionKey =
        regionManifestCatalog.regionKeyForPoint(
          LatLng(peak.latitude, peak.longitude),
        ) ??
        peak.region;
    return peakMatchesSearchRegion(
      storedPeakRegionKey: peak.region,
      resolvedRegionKey: resolvedRegionKey,
      filterRegionKey: regionKey,
    );
  }

  bool _queryCouldMatchElevation(String query) => RegExp(r'\d').hasMatch(query);

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
      if (_shouldRefreshPeakListDerivedData(previous, savedPeak)) {
        _peakListRewritePort.refreshDerivedDataForPeakReferences(
          previousPeak: previous!,
          updatedPeak: savedPeak,
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
      if (_shouldRefreshPeakListDerivedData(previous, savedPeak)) {
        _peakListRewritePort.refreshDerivedDataForPeakReferences(
          previousPeak: previous!,
          updatedPeak: savedPeak,
        );
      }
    });

    return PeakSaveResult(
      peak: savedPeak,
      peakListRewriteResult: rewriteResult,
    );
  }

  Future<PeakDuplicateResolutionResult> resolveDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
  }) async {
    final storedDuplicatePeak = _resolveStoredPeakForDuplicateResolution(
      duplicatePeak,
    );
    if (storedDuplicatePeak == null) {
      return const PeakDuplicateResolutionResult.failure(
        'Peak duplicate resolution failed: the duplicate peak no longer exists.',
      );
    }

    final storedSurvivingPeak = _resolveStoredPeakForDuplicateResolution(
      survivingPeak,
    );
    if (storedSurvivingPeak == null) {
      return const PeakDuplicateResolutionResult.failure(
        'Peak duplicate resolution failed: the Surviving peak no longer exists.',
      );
    }

    if (storedDuplicatePeak.id == storedSurvivingPeak.id) {
      return const PeakDuplicateResolutionResult.failure(
        'Peak duplicate resolution failed: the duplicate peak and Surviving peak must be different records.',
      );
    }

    try {
      final store = _store;
      if (store == null) {
        _peakListRewritePort.resolvePeakDuplicate(
          duplicatePeak: storedDuplicatePeak,
          survivingPeak: storedSurvivingPeak,
          peakStorage: _storage,
        );
      } else {
        store.runInTransaction(TxMode.write, () {
          _peakListRewritePort.resolvePeakDuplicate(
            duplicatePeak: storedDuplicatePeak,
            survivingPeak: storedSurvivingPeak,
            peakStorage: _storage,
          );
        });
      }
    } on PeakDuplicateResolutionException catch (error) {
      return PeakDuplicateResolutionResult.failure(error.message);
    } catch (error) {
      return PeakDuplicateResolutionResult.failure(
        'Peak duplicate resolution failed: $error',
      );
    }

    return PeakDuplicateResolutionResult.success(
      survivingPeak: storedSurvivingPeak,
    );
  }

  Future<void> backfillRegion(String region) async {
    final peaks = _storage.getAll();
    if (peaks.isEmpty || peaks.every((peak) => peak.region == region)) {
      return;
    }

    final updatedPeaks = peaks
        .map((peak) => peak.copyWith(region: region))
        .toList(growable: false);
    await _storage.replaceAll(updatedPeaks);
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

  bool _shouldRefreshPeakListDerivedData(Peak? previous, Peak updatedPeak) {
    if (previous == null) {
      return false;
    }

    return previous.osmId != updatedPeak.osmId ||
        previous.latitude != updatedPeak.latitude ||
        previous.longitude != updatedPeak.longitude ||
        previous.region != updatedPeak.region;
  }

  bool isEmpty() {
    return _storage.isEmpty;
  }

  Peak? _resolveStoredPeakForDuplicateResolution(Peak peak) {
    if (peak.id != 0) {
      return _storage.getById(peak.id);
    }
    if (peak.osmId != 0) {
      return findByOsmId(peak.osmId);
    }
    return null;
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

  @override
  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  }) {
    return 0;
  }

  @override
  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  }) {}
}

typedef _PeakListUpdate = ({PeakList original, PeakList updated});
typedef _PeaksBaggedUpdate = ({PeaksBagged original, PeaksBagged updated});
typedef _TrackUpdate = ({GpxTrack original, GpxTrack updated});
typedef _RouteUpdate = ({Route original, Route updated});

List<_PeakListUpdate> _buildPeakListUpdates({
  required List<PeakList> peakLists,
  required Map<int, Peak> peaksByOsmId,
  required Peak duplicatePeak,
  required Peak survivingPeak,
}) {
  final updates = <_PeakListUpdate>[];

  for (final peakList in peakLists) {
    late final List<PeakListItem> items;
    try {
      items = decodePeakListItems(peakList.peakList);
    } catch (_) {
      throw PeakDuplicateResolutionException(
        'Peak duplicate resolution failed: PeakList "${peakList.name}" is malformed.',
      );
    }

    var changed = false;
    final normalizedItems = <PeakListItem>[];
    final seenPeakOsmIds = <int>{};

    for (final item in items) {
      final mappedPeakOsmId = item.peakOsmId == duplicatePeak.osmId
          ? survivingPeak.osmId
          : item.peakOsmId;
      if (mappedPeakOsmId != item.peakOsmId) {
        changed = true;
      }
      if (!seenPeakOsmIds.add(mappedPeakOsmId)) {
        changed = true;
        continue;
      }

      normalizedItems.add(
        PeakListItem(peakOsmId: mappedPeakOsmId, points: item.points),
      );
    }

    if (!changed) {
      continue;
    }

    final normalizedPeakList = peakList.copyWith(
      peakList: encodePeakListItems(normalizedItems),
    );
    final derivedData = derivePeakListDerivedData(
      peakList: normalizedPeakList,
      items: normalizedItems,
      peakResolver: (peakOsmId) => peaksByOsmId[peakOsmId],
    );
    updates.add((
      original: peakList,
      updated: derivedData.applyTo(normalizedPeakList),
    ));
  }

  return updates;
}

({List<_PeaksBaggedUpdate> updates, List<int> removeIds})
_buildPeaksBaggedUpdates(
  List<PeaksBagged> rows, {
  required Peak duplicatePeak,
  required Peak survivingPeak,
}) {
  final groups = <(int, int), List<PeaksBagged>>{};
  for (final row in rows) {
    final mappedPeakId = row.peakId == duplicatePeak.osmId
        ? survivingPeak.osmId
        : row.peakId;
    groups.putIfAbsent((row.gpxId, mappedPeakId), () => []).add(row);
  }

  final updates = <_PeaksBaggedUpdate>[];
  final removeIds = <int>[];

  for (final entry in groups.values) {
    entry.sort((left, right) => left.baggedId.compareTo(right.baggedId));
    PeaksBagged keeper = entry.first;
    for (final row in entry) {
      if (row.peakId == survivingPeak.osmId) {
        keeper = row;
        break;
      }
    }

    for (final row in entry) {
      if (!identical(row, keeper)) {
        removeIds.add(row.baggedId);
      }
    }

    if (keeper.peakId == duplicatePeak.osmId) {
      updates.add((
        original: keeper,
        updated: PeaksBagged(
          baggedId: keeper.baggedId,
          peakId: survivingPeak.osmId,
          gpxId: keeper.gpxId,
          date: keeper.date,
        ),
      ));
    }
  }

  return (updates: updates, removeIds: removeIds);
}

List<_TrackUpdate> _buildTrackUpdates({
  required List<GpxTrack> tracks,
  required Peak duplicatePeak,
  required Peak survivingPeak,
}) {
  final updates = <_TrackUpdate>[];

  for (final track in tracks) {
    var changed = false;
    final updatedPeaks = <Peak>[];
    final seenPeakIds = <int>{};

    for (final peak in track.peaks) {
      final mappedPeak = peak.id == duplicatePeak.id ? survivingPeak : peak;
      if (mappedPeak.id != peak.id) {
        changed = true;
      }
      if (!seenPeakIds.add(mappedPeak.id)) {
        changed = true;
        continue;
      }
      updatedPeaks.add(mappedPeak);
    }

    if (!changed) {
      continue;
    }

    updates.add((
      original: track,
      updated: _cloneTrack(track, peaks: updatedPeaks),
    ));
  }

  return updates;
}

List<_RouteUpdate> _buildRouteUpdates({
  required List<Route> routes,
  required Peak duplicatePeak,
  required Peak survivingPeak,
}) {
  final updates = <_RouteUpdate>[];

  for (final route in routes) {
    var changed = false;
    final updatedWaypoints = <RouteWaypoint>[];
    final seenWaypoints = <RouteWaypoint>{};

    for (final waypoint in route.routeWaypoints) {
      final mappedWaypoint = waypoint.peakOsmId == duplicatePeak.osmId
          ? RouteWaypoint(
              latitude: waypoint.latitude,
              longitude: waypoint.longitude,
              label: waypoint.label,
              sequence: waypoint.sequence,
              isPeakDerived: waypoint.isPeakDerived,
              peakOsmId: survivingPeak.osmId,
              peakName: waypoint.peakName,
            )
          : waypoint;
      if (mappedWaypoint != waypoint) {
        changed = true;
      }
      if (!seenWaypoints.add(mappedWaypoint)) {
        changed = true;
        continue;
      }
      updatedWaypoints.add(mappedWaypoint);
    }

    if (!changed) {
      continue;
    }

    updates.add((
      original: route,
      updated: _cloneRoute(route, routeWaypoints: updatedWaypoints),
    ));
  }

  return updates;
}

void _applyPeakListUpdates(
  List<PeakList> peakLists,
  List<_PeakListUpdate> updates,
) {
  for (final update in updates) {
    final index = peakLists.indexOf(update.original);
    if (index != -1) {
      peakLists[index] = update.updated;
    }
  }
}

void _applyPeaksBaggedUpdates(
  List<PeaksBagged> peaksBagged, {
  required List<_PeaksBaggedUpdate> updates,
  required List<int> removeIds,
}) {
  final removeIdSet = removeIds.toSet();
  peaksBagged.removeWhere((row) => removeIdSet.contains(row.baggedId));
  for (final update in updates) {
    final index = peaksBagged.indexOf(update.original);
    if (index != -1) {
      peaksBagged[index] = update.updated;
    }
  }
}

void _applyTrackUpdates(List<GpxTrack> tracks, List<_TrackUpdate> updates) {
  for (final update in updates) {
    final index = tracks.indexOf(update.original);
    if (index != -1) {
      tracks[index] = update.updated;
    }
  }
}

void _applyRouteUpdates(List<Route> routes, List<_RouteUpdate> updates) {
  for (final update in updates) {
    final index = routes.indexOf(update.original);
    if (index != -1) {
      routes[index] = update.updated;
    }
  }
}

void _restorePeakLists(List<PeakList> target, List<PeakList> snapshot) {
  target
    ..clear()
    ..addAll(snapshot);
}

void _restorePeaksBagged(List<PeaksBagged> target, List<PeaksBagged> snapshot) {
  target
    ..clear()
    ..addAll(snapshot);
}

void _restoreTracks(List<GpxTrack> target, List<GpxTrack> snapshot) {
  target
    ..clear()
    ..addAll(snapshot);
}

void _restoreRoutes(List<Route> target, List<Route> snapshot) {
  target
    ..clear()
    ..addAll(snapshot);
}

PeakList _clonePeakList(PeakList peakList) {
  return peakList.copyWith();
}

PeaksBagged _clonePeaksBagged(PeaksBagged row) {
  return PeaksBagged(
    baggedId: row.baggedId,
    peakId: row.peakId,
    gpxId: row.gpxId,
    date: row.date,
  );
}

GpxTrack _cloneTrack(GpxTrack track, {List<Peak>? peaks}) {
  final cloned = GpxTrack.fromMap(track.toMap());
  cloned.gpxTrackId = track.gpxTrackId;
  cloned.peaks.addAll(
    peaks ?? track.peaks.map((peak) => peak.copyWith()..id = peak.id),
  );
  return cloned;
}

Route _cloneRoute(Route route, {List<RouteWaypoint>? routeWaypoints}) {
  return Route(
    id: route.id,
    name: route.name,
    desc: route.desc,
    gpxRoute: route.gpxRoute,
    gpxRouteElevations: route.gpxRouteElevations,
    routeWaypoints: routeWaypoints ?? route.routeWaypoints,
    displayRoutePointsByZoom: route.displayRoutePointsByZoom,
    colour: route.colour,
    visible: route.visible,
    distance2d: route.distance2d,
    distance3d: route.distance3d,
    ascent: route.ascent,
    descent: route.descent,
    startElevation: route.startElevation,
    endElevation: route.endElevation,
    lowestElevation: route.lowestElevation,
    highestElevation: route.highestElevation,
    estimatedTime: route.estimatedTime,
    routeTimingSource: route.routeTimingSource,
    routeTimingProfileJson: route.routeTimingProfileJson,
    walkingSpeedKmh: route.walkingSpeedKmh,
    routeTimingSegmentKindsJson: route.routeTimingSegmentKindsJson,
  );
}
