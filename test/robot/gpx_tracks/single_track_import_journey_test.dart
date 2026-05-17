import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_map_notifier.dart';

void main() {
  testWidgets('selected imported track state zooms the map', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'hash-1',
      trackName: 'Correlated Track',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-43.2, 147.0), const LatLng(-43.1, 147.2)],
      ]),
    );
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [track],
        selectedTrackId: 1,
        selectedTrackFocusSerial: 1,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
        ],
        child: const App(),
      ),
    );
    addTearDown(() async {
      try {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        router.go('/');
        await tester.pump();
      } catch (_) {}
    });
    await tester.pump();

    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    expect(notifier.state.selectedTrackId, 1);
    expect(notifier.state.selectedTrackFocusSerial, 1);
    expect(notifier.state.zoom, lessThan(15));
    expect(notifier.state.center.latitude, closeTo(-43.15, 0.02));
    expect(notifier.state.center.longitude, closeTo(147.1, 0.02));
    expect(find.byKey(const Key('track-info-panel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('track-info-panel')),
        matching: find.text('Correlated Track'),
      ),
      findsOneWidget,
    );
  });
}
