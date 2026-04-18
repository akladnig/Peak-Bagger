import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('peak search opens and closes', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-search-input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-search-close')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-search-input')), findsNothing);
    expect(container.read(mapProvider).showPeakSearch, isFalse);
  });

  testWidgets('peak search shows empty state for no matches', (tester) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(find.byKey(const Key('peak-search-input')), 'zzz');
    await tester.pump();

    expect(find.text('No peaks found'), findsOneWidget);
  });

  testWidgets('selecting a peak search result centers on the peak', (
    tester,
  ) async {
    await _pumpMapApp(tester, _mapStateWithPeaks());

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('map-interaction-region'))),
    );
    container.read(mapProvider.notifier).togglePeakSearch();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.enterText(
      find.byKey(const Key('peak-search-input')),
      'Bonnet',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ListTile, 'Bonnet Hill'));
    await tester.pump();

    final state = container.read(mapProvider);
    expect(find.byKey(const Key('peak-search-input')), findsNothing);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
    expect(state.center, const LatLng(-43.0, 147.0));
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

MapState _mapStateWithPeaks() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 6406,
        name: 'Bonnet Hill',
        latitude: -43.0,
        longitude: 147.0,
        elevation: 410,
      ),
      Peak(
        osmId: 7000,
        name: 'Other Peak',
        latitude: -42.9,
        longitude: 147.1,
        elevation: 380,
      ),
    ],
  );
}
