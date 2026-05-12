import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  group('selected track contract', () {
    test('invalid selectTrack is no-op and valid visible id sticks', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [_track(1), _track(2)],
        selectedTrackId: 1,
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => _InitialStateMapNotifier(initialState)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mapProvider.notifier);

      notifier.selectTrack(999);
      expect(container.read(mapProvider).selectedTrackId, 1);

      notifier.selectTrack(2);
      expect(container.read(mapProvider).selectedTrackId, 2);
    });

    test('reconcileSelectedTrackState clears stale selected id', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [_track(1)],
        selectedTrackId: 999,
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => _InitialStateMapNotifier(initialState)),
        ],
      );
      addTearDown(container.dispose);

      container.read(mapProvider.notifier).reconcileSelectedTrackState();

      expect(container.read(mapProvider).selectedTrackId, isNull);
    });

    test('showTrack repository miss clears selection and does not bump focus', () async {
      final repository = await TestTasmapRepository.create();
      final gpxRepository = GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1)]),
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => MapNotifier(
              peakRepository: PeakRepository.test(InMemoryPeakStorage()),
              overpassService: OverpassService(),
              tasmapRepository: repository,
              gpxTrackRepository: gpxRepository,
              peaksBaggedRepository: PeaksBaggedRepository.test(
                InMemoryPeaksBaggedStorage(),
              ),
              migrationMarkerStore: const MigrationMarkerStore(),
              loadPositionOnBuild: false,
              loadPeaksOnBuild: false,
              loadTracksOnBuild: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mapProvider.notifier);

      notifier.showTrack(1);
      expect(container.read(mapProvider).selectedTrackId, 1);
      expect(container.read(mapProvider).selectedTrackFocusSerial, 1);

      notifier.showTrack(999);

      final state = container.read(mapProvider);
      expect(state.selectedTrackId, isNull);
      expect(state.selectedTrackFocusSerial, 1);
    });
  });
}

GpxTrack _track(int id) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
  );
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}
