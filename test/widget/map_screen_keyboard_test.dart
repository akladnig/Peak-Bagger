import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('keyboard zoom shortcut commits once immediately', (tester) async {
    final notifier = _CountingKeyboardMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
      ),
    );
    await _pumpMapAppWithNotifier(tester, notifier);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
    await tester.pump();

    expect(notifier.acceptCameraIntentCallCount, 1);
    expect(notifier.persistCameraPositionCallCount, 1);
    expect(notifier.state.zoom, 11);
    expect(notifier.state.cameraRequestCenter, isNull);
  });

  testWidgets('keyboard zoom shortcut updates map zoom', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
    await tester.pump();

    expect(container.read(mapProvider).zoom, 11);
  });

  testWidgets('keyboard movement shortcut pans the map', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    final initialCenter = container.read(mapProvider).center;

    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump(const Duration(milliseconds: 64));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(
      container.read(mapProvider).center.longitude,
      greaterThan(initialCenter.longitude),
    );
  });

  testWidgets('keyboard g opens goto input', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.pump();

    expect(find.byKey(const Key('goto-map-input')), findsOneWidget);
  });

  testWidgets('keyboard g closes peak popup before opening goto input', (
    tester,
  ) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container
        .read(mapProvider.notifier)
        .openPeakInfoPopup(
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -41.5,
            longitude: 146.5,
          ),
        );
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
    expect(find.byKey(const Key('goto-map-input')), findsOneWidget);
  });

  testWidgets('shell navigation closes peak popup', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).openPeakInfoPopup(
      Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -41.5,
        longitude: 146.5,
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump();

    expect(container.read(mapProvider).peakInfoPeak, isNull);
  });

  testWidgets('closing peak search returns focus to map shortcuts', (
    tester,
  ) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('peak-search-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.pump();

    expect(find.byKey(const Key('goto-map-input')), findsOneWidget);
  });

  testWidgets('keyboard i opens info popup', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-41.5, 146.5),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(container.read(mapProvider).showInfoPopup, isTrue);
    expect(find.text('Unknown'), findsOneWidget);
  });

  testWidgets('keyboard g closes map info and does not open goto input', (
    tester,
  ) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-41.5, 146.5),
      ),
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.pump();
    expect(container.read(mapProvider).showInfoPopup, isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.pump();

    expect(container.read(mapProvider).showInfoPopup, isFalse);
    expect(find.byKey(const Key('goto-map-input')), findsNothing);
  });

  testWidgets('keyboard i recenters through accepted camera apply only', (
    tester,
  ) async {
    const target = LatLng(-41.6, 146.6);
    final notifier = _CountingKeyboardMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: target,
      ),
    );
    await _pumpMapAppWithNotifier(tester, notifier);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyI);
    await tester.pump();

    expect(notifier.acceptCameraIntentCallCount, 1);
    expect(notifier.persistCameraPositionCallCount, 1);
    expect(notifier.state.center, target);
    expect(notifier.state.cameraRequestCenter, isNull);
    expect(notifier.state.showInfoPopup, isTrue);
  });

  testWidgets('keyboard b reopens basemaps drawer after peak lists drawer', (
    tester,
  ) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('peak-lists-drawer')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-item-All Peaks')));
    await tester.pumpAndSettle();

    final region = find.byKey(const Key('map-interaction-region'));
    await tester.tapAt(tester.getCenter(region));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();

    expect(find.text('Basemaps'), findsOneWidget);
  });

  testWidgets('escape closes drawer before affecting selected track', (
    tester,
  ) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [_track(10)],
      selectedTrackId: 10,
    );
    await _pumpRawMapScreen(tester, state);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    tester.widget<Focus>(find.byType(Focus).first).focusNode?.requestFocus();
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyB);
    await tester.pumpAndSettle();
    expect(find.text('Basemaps'), findsOneWidget);

    Actions.invoke(
      tester.element(find.byType(Scaffold).first),
      const DismissSurfaceIntent(),
    );
    await tester.pumpAndSettle();

    expect(find.text('Basemaps'), findsNothing);
    expect(container.read(mapProvider).selectedTrackId, 10);
  });

  testWidgets('escape clears selected track when no higher priority surface is open', (
    tester,
  ) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [_track(10)],
      selectedTrackId: 10,
    );
    await _pumpRawMapScreen(tester, state);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    tester.widget<Focus>(find.byType(Focus).first).focusNode?.requestFocus();
    await tester.pump();

    Actions.invoke(
      tester.element(find.byType(Scaffold).first),
      const DismissSurfaceIntent(),
    );
    await tester.pump();

    expect(container.read(mapProvider).selectedTrackId, isNull);
  });

  testWidgets('tapping the map sets the selected marker', (tester) async {
    await _pumpMapApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final region = find.byKey(const Key('map-interaction-region'));
    final container = ProviderScope.containerOf(tester.element(region));

    await tester.tapAt(tester.getCenter(region));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final selectedLocation = container.read(mapProvider).selectedLocation;
    expect(selectedLocation, isNotNull);
    expect(selectedLocation!.latitude, closeTo(-41.5, 0.001));
    expect(selectedLocation.longitude, closeTo(146.5, 0.001));
  });
}

Future<void> _pumpMapApp(
  WidgetTester tester,
  MapState state, {
  Size size = const Size(1600, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpMapAppWithNotifier(
  WidgetTester tester,
  MapNotifier notifier,
  {
  Size size = const Size(1600, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
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
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpRawMapScreen(
  WidgetTester tester,
  MapState state, {
  Size size = const Size(1600, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final gpxTrackRepository = GpxTrackRepository.test(
    InMemoryGpxTrackStorage(state.tracks),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _CountingKeyboardMapNotifier extends TestMapNotifier {
  _CountingKeyboardMapNotifier(super.initialState);

  int acceptCameraIntentCallCount = 0;
  int persistCameraPositionCallCount = 0;

  @override
  void acceptCameraIntent(PendingCameraRequest request) {
    acceptCameraIntentCallCount += 1;
    super.acceptCameraIntent(request);
  }

  @override
  Future<void> persistCameraPosition() async {
    persistCameraPositionCallCount += 1;
  }
}

GpxTrack _track(int id) {
  return GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    gpxFile: '<gpx></gpx>',
  );
}
