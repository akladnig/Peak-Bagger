import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_derived_data_persistence.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('removes only the selected peak correlation and refreshes map state', () async {
    final selectedTrack = _track(id: 1, peakOsmIds: [10, 20]);
    final otherTrack = _track(id: 2, peakOsmIds: [10]);
    final tracks = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([selectedTrack, otherTrack]),
    );
    final bagged = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 4, gpxId: 1, peakId: 10),
        PeaksBagged(baggedId: 5, gpxId: 1, peakId: 20),
        PeaksBagged(baggedId: 9, gpxId: 2, peakId: 10),
      ]),
    );
    final container = await _container(tracks: tracks, bagged: bagged);
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = _state([selectedTrack, otherTrack]);

    await notifier.removePeakCorrelation(trackId: 1, peakOsmId: 10);

    expect(tracks.findById(1)!.peaks.map((peak) => peak.osmId), [20]);
    expect(tracks.findById(2)!.peaks.map((peak) => peak.osmId), [10]);
    expect(
      bagged.getAll().map((row) => (row.baggedId, row.gpxId, row.peakId)),
      [(5, 1, 20), (9, 2, 10)],
    );
    expect(container.read(mapProvider).tracks[0].peaks.map((peak) => peak.osmId), [20]);
    expect(container.read(mapProvider).selectedTrackId, 1);
    expect(notifier.correlatedPeakIds, {10, 20});
    expect(container.read(peaksBaggedRevisionProvider), 1);
  });

  test('treats an already-absent persisted pair as a successful refresh', () async {
    final persistedTrack = _track(id: 1, peakOsmIds: [20]);
    final tracks = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([persistedTrack]),
    );
    final bagged = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 5, gpxId: 1, peakId: 20),
      ]),
    );
    final container = await _container(tracks: tracks, bagged: bagged);
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = _state([_track(id: 1, peakOsmIds: [10, 20])]);

    await notifier.removePeakCorrelation(trackId: 1, peakOsmId: 10);

    expect(tracks.findById(1)!.peaks.map((peak) => peak.osmId), [20]);
    expect(
      bagged.getAll().map((row) => (row.baggedId, row.gpxId, row.peakId)),
      [(5, 1, 20)],
    );
    expect(container.read(mapProvider).tracks.single.peaks.map((peak) => peak.osmId), [20]);
    expect(container.read(mapProvider).selectedTrackId, 1);
    expect(container.read(peaksBaggedRevisionProvider), 1);
  });

  for (final failure in TrackDerivedDataPersistenceFailure.values) {
    test('retains the exact persisted data when $failure fails', () async {
      final selectedTrack = _track(id: 1, peakOsmIds: [10, 20]);
      final otherTrack = _track(id: 2, peakOsmIds: [10]);
      final tracks = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([selectedTrack, otherTrack]),
      );
      final bagged = PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(baggedId: 4, gpxId: 1, peakId: 10),
          PeaksBagged(baggedId: 5, gpxId: 1, peakId: 20),
          PeaksBagged(baggedId: 9, gpxId: 2, peakId: 10),
        ]),
      );
      final container = await _container(
        tracks: tracks,
        bagged: bagged,
        failureForTest: failure,
      );
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      notifier.state = _state([selectedTrack, otherTrack]);
      final priorTracks = _trackSnapshots(tracks.getAllTracks());
      final priorRows = _rowSnapshots(bagged.getAll());

      await expectLater(
        notifier.removePeakCorrelation(trackId: 1, peakOsmId: 10),
        throwsStateError,
      );

      expect(_trackSnapshots(tracks.getAllTracks()), priorTracks);
      expect(_rowSnapshots(bagged.getAll()), priorRows);
      expect(_trackSnapshots(container.read(mapProvider).tracks), priorTracks);
      expect(container.read(mapProvider).selectedTrackId, 1);
      expect(container.read(peaksBaggedRevisionProvider), 0);
    });
  }

  test('remains absent after repository reload and derived-history sync', () async {
    final trackStorage = InMemoryGpxTrackStorage([
      _track(id: 1, peakOsmIds: [10, 20]),
      _track(id: 2, peakOsmIds: [10]),
    ]);
    final baggedStorage = InMemoryPeaksBaggedStorage([
      PeaksBagged(baggedId: 4, gpxId: 1, peakId: 10),
      PeaksBagged(baggedId: 5, gpxId: 1, peakId: 20),
      PeaksBagged(baggedId: 9, gpxId: 2, peakId: 10),
    ]);
    final tracks = GpxTrackRepository.test(trackStorage);
    final bagged = PeaksBaggedRepository.test(baggedStorage);
    final container = await _container(tracks: tracks, bagged: bagged);
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = _state(tracks.getAllTracks());

    await notifier.removePeakCorrelation(trackId: 1, peakOsmId: 10);

    final reloadedTracks = GpxTrackRepository.test(trackStorage);
    final reloadedBagged = PeaksBaggedRepository.test(baggedStorage);
    await reloadedBagged.syncFromTracks(reloadedTracks.getAllTracks());
    final reloadedContainer = await _container(
      tracks: reloadedTracks,
      bagged: reloadedBagged,
    );
    addTearDown(reloadedContainer.dispose);
    final reloadedNotifier = reloadedContainer.read(mapProvider.notifier);
    reloadedNotifier.state = _state(reloadedTracks.getAllTracks());

    expect(reloadedTracks.findById(1)!.peaks.map((peak) => peak.osmId), [20]);
    expect(reloadedTracks.findById(2)!.peaks.map((peak) => peak.osmId), [10]);
    expect(
      reloadedBagged.getAll().map((row) => (row.gpxId, row.peakId)),
      [(1, 20), (2, 10)],
    );
    expect(reloadedNotifier.correlatedPeakIds, {10, 20});
  });

  test('explicit selected-track recalculation can restore an eligible pair', () async {
    SharedPreferences.setMockInitialValues({
      peakCorrelationDistanceKey: 100,
      peakCorrelationElevationKey: 20,
    });
    final peak = Peak(
      osmId: 99,
      name: 'Eligible peak',
      latitude: -42,
      longitude: 146,
      elevation: 100,
    );
    final selectedTrack = GpxTrack(
        gpxTrackId: 1,
        contentHash: 'track-1',
        trackName: 'Track 1',
        gpxFile: _eligibleCorrelationGpx,
        peakCorrelationProcessed: true,
      )
      ..peaks.add(peak);
    final tracks = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([selectedTrack]),
    );
    final bagged = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 4, gpxId: 1, peakId: 99),
      ]),
    );
    final container = await _container(
      tracks: tracks,
      bagged: bagged,
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
    );
    addTearDown(container.dispose);
    final notifier = container.read(mapProvider.notifier);
    notifier.state = _state([selectedTrack]);

    await notifier.removePeakCorrelation(trackId: 1, peakOsmId: 99);
    final result = await notifier.recalculateSelectedTrackStatistics(1);

    expect(result, isNotNull);
    expect(tracks.findById(1)!.peaks.map((peak) => peak.osmId), [99]);
    expect(bagged.getAll().map((row) => (row.gpxId, row.peakId)), [(1, 99)]);
  });
}

Future<ProviderContainer> _container({
  required GpxTrackRepository tracks,
  required PeaksBaggedRepository bagged,
  TrackDerivedDataPersistenceFailure? failureForTest,
  PeakRepository? peakRepository,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  return ProviderContainer(
    overrides: [
      mapProvider.overrideWith(
        () => MapNotifier(
          peakRepository:
              peakRepository ?? PeakRepository.test(InMemoryPeakStorage()),
          overpassService: OverpassService(),
          tasmapRepository: tasmapRepository,
          gpxTrackRepository: tracks,
          routeRepository: RouteRepository.test(InMemoryRouteStorage()),
          peaksBaggedRepository: bagged,
          trackDerivedDataPersistence: RepositoryTrackDerivedDataPersistence(
            tracks: tracks,
            peaksBagged: bagged,
            failureForTest: failureForTest,
          ),
          migrationMarkerStore: const MigrationMarkerStore(),
          loadPositionOnBuild: false,
          loadPeaksOnBuild: false,
          loadTracksOnBuild: false,
        ),
      ),
    ],
  );
}

MapState _state(List<GpxTrack> tracks) {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    showTracks: true,
    tracks: tracks,
    selectedTrackId: 1,
  );
}

GpxTrack _track({required int id, required List<int> peakOsmIds}) {
  return GpxTrack(
      gpxTrackId: id,
      contentHash: 'track-$id',
      trackName: 'Track $id',
      peakCorrelationProcessed: true,
    )
    ..peaks.addAll([
      for (final osmId in peakOsmIds)
        Peak(
          id: osmId + 1000,
          osmId: osmId,
          name: 'Peak $osmId',
          latitude: -42,
          longitude: 146,
        ),
    ]);
}

List<String> _trackSnapshots(Iterable<GpxTrack> tracks) {
  return [
    for (final track in tracks)
      '${track.gpxTrackId}:${track.peaks.map((peak) => peak.osmId).join(',')}',
  ];
}

List<(int, int, int)> _rowSnapshots(Iterable<PeaksBagged> rows) {
  return [
    for (final row in rows) (row.baggedId, row.gpxId, row.peakId),
  ];
}

const _eligibleCorrelationGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk><trkseg>
    <trkpt lat="-42.0" lon="146.0"><ele>100</ele><time>2024-01-15T08:00:00Z</time></trkpt>
    <trkpt lat="-42.0" lon="146.001"><ele>100</ele><time>2024-01-15T08:01:00Z</time></trkpt>
  </trkseg></trk>
</gpx>
''';
