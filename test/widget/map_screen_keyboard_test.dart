import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';

void main() {
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

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mapProvider.overrideWith(() => TestMapNotifier(state))],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
