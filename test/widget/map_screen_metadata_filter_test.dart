import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_details_metadata_filter_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets(
    'map omits metadata filters while search remains available and markers stay unfiltered',
    (tester) async {
      final notifier = TestMapNotifier(_baseState());
      await _pumpApp(tester, notifier);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shared-app-bar'))),
      );

      expect(find.byKey(const Key('app-bar-map-filter-trigger')), findsNothing);
      expect(find.byKey(const Key('app-bar-map-filter-divider')), findsNothing);
      expect(find.byKey(const Key('map-metadata-filter-popup')), findsNothing);
      expect(
        find.byKey(const Key('map-metadata-filter-backdrop')),
        findsNothing,
      );
      expect(
        container
            .read(filteredPeaksProvider)
            .map((peak) => peak.osmId)
            .toList(),
        [100, 200],
      );

      container
          .read(peakListDetailsMetadataFilterProvider.notifier)
          .setRatingFilter(PeakRatingFilterOption.atLeast4_5);
      await tester.pump();

      expect(
        container
            .read(filteredPeaksProvider)
            .map((peak) => peak.osmId)
            .toList(),
        [100, 200],
      );

      await tester.tap(find.byKey(const Key('app-bar-search-trigger')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('map-search-popup')), findsOneWidget);
    },
  );
}

Future<void> _pumpApp(WidgetTester tester, TestMapNotifier notifier) async {
  final tasmapRepository = await TestTasmapRepository.create();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
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

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    peaks: [
      Peak(
        osmId: 100,
        name: 'Tas Easy',
        latitude: -42.0,
        longitude: 146.0,
        rating: 4.2,
        difficulty: 'Easy',
        durationMinutes: 240,
        region: 'tasmania',
      ),
      Peak(
        osmId: 200,
        name: 'FVG T',
        latitude: 46.2,
        longitude: 13.2,
        rating: 4.8,
        difficulty: 'T',
        durationMinutes: 180,
        region: 'fvg',
      ),
    ],
  );
}
