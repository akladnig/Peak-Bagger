import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  test('normalises persisted track names after committing the batch', () async {
    final repository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(
          gpxTrackId: 1,
          contentHash: 'one',
          trackName: 'Mount Anne 15-01-2024',
          gpxFile: '<gpx />',
        ),
        GpxTrack(
          gpxTrackId: 2,
          contentHash: 'two',
          trackName: 'Frenchmans Cap',
          gpxFile: '<gpx />',
        ),
      ]),
    );
    final notifier = TestMapNotifier(
      _state(repository.getAllTracks()),
      gpxTrackRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    container.read(mapProvider);
    final pending = container.read(mapProvider.notifier).normaliseTrackNames();

    expect(container.read(mapProvider).isLoadingTracks, isTrue);
    expect(
      await container.read(mapProvider.notifier).normaliseTrackNames(),
      isNull,
    );

    final result = await pending;

    expect(result?.updatedCount, 1);
    expect(result?.unchangedCount, 1);
    expect(container.read(mapProvider).isLoadingTracks, isFalse);
    expect(container.read(mapProvider).tracks.map((track) => track.trackName), [
      'Mount Anne',
      'Frenchmans Cap',
    ]);
  });

  test('reports a failed batch without changing stored track names', () async {
    final repository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage.withFailureForTest(
        tracks: [
          GpxTrack(
            gpxTrackId: 1,
            contentHash: 'one',
            trackName: 'Mount Anne 15-01-2024',
            gpxFile: '<gpx />',
          ),
        ],
        failureForTest: TrackNameNormalisationFailure.afterFirstWrite,
      ),
    );
    final notifier = TestMapNotifier(
      _state(repository.getAllTracks()),
      gpxTrackRepository: repository,
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    container.read(mapProvider);
    final result = await container
        .read(mapProvider.notifier)
        .normaliseTrackNames();

    expect(result, isNull);
    expect(container.read(mapProvider).isLoadingTracks, isFalse);
    expect(
      container.read(mapProvider).trackImportError,
      'Failed to normalise track names: Bad state: Injected failure after the first Track-name write',
    );
    expect(repository.getAllTracks().single.trackName, 'Mount Anne 15-01-2024');
  });
}

MapState _state(List<GpxTrack> tracks) {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 10,
    basemap: Basemap.tracestrack,
    tracks: tracks,
  );
}
