import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets(
    'map route shows selected transient and pinned app-bar items',
    (tester) async {
      await _pumpApp(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          visibleBounds: _tasmaniaBounds,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {1},
          previousSpecificPeakListIds: {1},
          pinnedPeakListIdsByRegion: {
            'tasmania': {2},
          },
        ),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Zulu', peakList: '[]')..peakListId = 2,
            PeakList(name: 'Alpha', peakList: '[]')..peakListId = 1,
          ]),
        ),
      );
      router.go('/map');
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('peak-list-selection-summary')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-list-app-bar-item-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-list-app-bar-item-2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('peak-list-app-bar-item-3')),
        findsNothing,
      );
    },
  );

  testWidgets('all peaks and none show exactly one special chip on map route', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: _tasmaniaBounds,
        peakListSelectionMode: PeakListSelectionMode.allPeaks,
      ),
    );
    router.go('/map');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-list-selection-chip-all-peaks')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('peak-list-selection-chip-none')),
      findsNothing,
    );

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    container
        .read(mapProvider.notifier)
        .selectPeakList(PeakListSelectionMode.none);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-list-selection-chip-all-peaks')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('peak-list-selection-chip-none')),
      findsOneWidget,
    );
  });

  testWidgets('summary remains visible on constrained desktop widths', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          visibleBounds: _tasmaniaBounds,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {1, 2},
        ),
      peakListRepository: PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Alpha Long List Name', peakList: '[]')
            ..peakListId = 1,
          PeakList(name: 'Zulu Long List Name', peakList: '[]')..peakListId = 2,
        ]),
      ),
    );

      router.go('/map');
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-list-selection-summary')), findsOneWidget);
  });

  testWidgets(
    'summary stays to the right of centered search without clipping',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpApp(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          visibleBounds: _tasmaniaBounds,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {1, 2, 3},
        ),
        peakListRepository: PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(name: 'Abels', peakList: '[]')..peakListId = 1,
            PeakList(name: 'HWC Peak Baggers', peakList: '[]')..peakListId = 2,
            PeakList(name: 'Poimena Reserve West Ridge', peakList: '[]')
              ..peakListId = 3,
          ]),
        ),
      );
      router.go('/map');
      await tester.pumpAndSettle();

      final appBarRect = tester.getRect(
        find.byKey(const Key('shared-app-bar')),
      );
      final searchRect = tester.getRect(
        find.byKey(const Key('app-bar-search-trigger')),
      );
      final summaryRect = tester.getRect(
        find.byKey(const Key('peak-list-selection-summary')),
      );
      final rightChipRect = tester.getRect(
        find.byKey(const Key('peak-list-app-bar-item-3')),
      );

      expect(searchRect.center.dx, closeTo(appBarRect.center.dx, 1.0));
      expect(summaryRect.left, greaterThan(searchRect.right));
      expect(rightChipRect.right, lessThanOrEqualTo(appBarRect.right));
    },
  );

  testWidgets('non-map routes omit peak list summary container', (tester) async {
    await _pumpApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: _tasmaniaBounds,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {1},
      ),
      peakListRepository: PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(name: 'Alpha', peakList: '[]')..peakListId = 1,
        ]),
      ),
    );

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-selection-summary')), findsNothing);

    router.go('/map');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-selection-summary')), findsOneWidget);
  });
}

final _tasmaniaBounds = LatLngBounds(
  const LatLng(-43.5, 145.5),
  const LatLng(-40.5, 148.5),
);

Future<void> _pumpApp(
  WidgetTester tester,
  MapState state, {
  PeakListRepository? peakListRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ??
              PeakListRepository.test(InMemoryPeakListStorage()),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}
