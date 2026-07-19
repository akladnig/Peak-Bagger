import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('map route shows selected transient and pinned app-bar items', (
    tester,
  ) async {
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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Zulu')..peakListId = 2,
        PeakList(name: 'Alpha')..peakListId = 1,
      ]),
    );
    router.go('/map');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-list-selection-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-app-bar-item-2')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-app-bar-item-3')), findsNothing);
  });

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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha Long List Name')..peakListId = 1,
        PeakList(name: 'Zulu Long List Name')..peakListId = 2,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-list-selection-summary')),
      findsOneWidget,
    );
  });

  testWidgets(
    'summary stays to the right of left-side search and filter controls without clipping',
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
        peakListRepository: _peakListRepositoryWithItems([
          PeakList(name: 'Abels')..peakListId = 1,
          PeakList(name: 'HWC Peak Baggers')..peakListId = 2,
          PeakList(name: 'Poimena Reserve West Ridge')..peakListId = 3,
        ]),
      );
      router.go('/map');
      await tester.pumpAndSettle();

      final appBarRect = tester.getRect(
        find.byKey(const Key('shared-app-bar')),
      );
      final searchRect = tester.getRect(
        find.byKey(const Key('app-bar-search-trigger')),
      );
      final filterRect = tester.getRect(
        find.byKey(const Key('app-bar-map-filter-trigger')),
      );
      final summaryRect = tester.getRect(
        find.byKey(const Key('peak-list-selection-summary')),
      );
      final rightChipRect = tester.getRect(
        find.byKey(const Key('peak-list-app-bar-item-3')),
      );

      expect(searchRect.center.dx, lessThan(appBarRect.center.dx));
      expect(filterRect.left, greaterThan(searchRect.right));
      expect(summaryRect.left, greaterThan(filterRect.right));
      expect(rightChipRect.right, lessThanOrEqualTo(appBarRect.right));
    },
  );

  testWidgets('non-map routes omit peak list summary container', (
    tester,
  ) async {
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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha')..peakListId = 1,
      ]),
    );

    router.go('/settings');
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-selection-summary')), findsNothing);

    router.go('/map');
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-list-selection-summary')),
      findsOneWidget,
    );
  });

  testWidgets('zero-region map views hide the peak list row', (tester) async {
    await _pumpApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: LatLngBounds(
          const LatLng(-10.0, 10.0),
          const LatLng(-5.0, 15.0),
        ),
        peakListSelectionMode: PeakListSelectionMode.allPeaks,
      ),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    container
        .read(mapProvider.notifier)
        .updateVisibleBounds(
          LatLngBounds(const LatLng(-10.0, 10.0), const LatLng(-5.0, 15.0)),
        );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-selection-summary')), findsNothing);
  });

  testWidgets('map views keep applicable visible lists in the summary', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: LatLngBounds(
          const LatLng(-89.0, -179.0),
          const LatLng(89.0, 179.0),
        ),
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {1, 2},
        previousSpecificPeakListIds: {1, 2},
      ),
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
        PeakList(name: 'Bravo', region: 'new-south-wales')..peakListId = 2,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    expect(container.read(mapProvider).selectedPeakListIds, contains(1));

    expect(
      find.byKey(const Key('peak-list-selection-summary')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsOneWidget);
  });

  testWidgets('map route restores exact visible-region-set app-bar selection', (
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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
        PeakList(name: 'Bravo', region: 'new-south-wales')..peakListId = 2,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-item-Alpha')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).selectedPeakListIds, {1});

    container
        .read(mapProvider.notifier)
        .updateVisibleBounds(
          LatLngBounds(const LatLng(-34.5, 147.0), const LatLng(-33.0, 150.5)),
        );
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(
      find.byKey(const Key('peak-list-selection-chip-all-peaks')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-item-Bravo')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).selectedPeakListIds, {2});

    container.read(mapProvider.notifier).updateVisibleBounds(_tasmaniaBounds);
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListIds, {1});
    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsOneWidget);
    expect(find.byKey(const Key('peak-list-app-bar-item-2')), findsNothing);

    container
        .read(mapProvider.notifier)
        .updateVisibleBounds(
          LatLngBounds(const LatLng(-34.5, 147.0), const LatLng(-33.0, 150.5)),
        );
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListIds, {2});
    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsNothing);
    expect(find.byKey(const Key('peak-list-app-bar-item-2')), findsOneWidget);
  });

  testWidgets('unpinned app-bar deselect removes the visible list item', (
    tester,
  ) async {
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
      ),
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-selection-chip-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsNothing);
  });

  testWidgets('pinned app-bar deselect keeps the visible list item', (
    tester,
  ) async {
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
          'tasmania': {1},
        },
      ),
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('peak-list-selection-chip-1')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-app-bar-item-1')), findsOneWidget);
  });

  testWidgets('drawer pin tap pins only and main tap toggles selection', (
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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-pin-1')));
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.allPeaks,
    );
    expect(container.read(mapProvider).selectedPeakListIds, isEmpty);
    expect(container.read(mapProvider).pinnedPeakListIdsByRegion, {
      'tasmania': {1},
    });
    expect(find.byKey(const Key('peak-list-unpin-icon-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-pin-1')));
    await tester.pumpAndSettle();

    expect(container.read(mapProvider).pinnedPeakListIdsByRegion, isEmpty);
    expect(find.byKey(const Key('peak-list-pin-icon-1')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-item-Alpha')));
    await tester.pumpAndSettle();

    expect(
      container.read(mapProvider).peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(container.read(mapProvider).selectedPeakListIds, {1});
  });

  testWidgets(
    'drawer selection updates immediately and stale deferred refreshes are superseded',
    (tester) async {
      final scheduler = _ControlledPeakListSelectionRefreshScheduler();
      await _pumpApp(
        tester,
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          visibleBounds: _tasmaniaBounds,
          peakListSelectionMode: PeakListSelectionMode.allPeaks,
        ),
        peakListRepository: _peakListRepositoryWithItems([
          PeakList(name: 'Alpha', region: 'tasmania')..peakListId = 1,
        ]),
        refreshScheduler: scheduler.call,
      );

      router.go('/map');
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shared-app-bar'))),
      );

      await tester.tap(find.byKey(const Key('show-peaks-fab')));
      await tester.pumpAndSettle();
      await scheduler.runAllPending();
      await tester.pump();

      await tester.tap(find.byKey(const Key('peak-list-item-Alpha')));
      await tester.pump();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(container.read(mapProvider).selectedPeakListIds, {1});
      expect(
        find.byKey(const Key('peak-list-selection-chip-all-peaks')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('peak-list-selection-chip-1')), findsNothing);
      expect(scheduler.pendingCount, 1);

      await tester.tap(find.byKey(const Key('peak-list-item-All Peaks')));
      await tester.pump();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );
      expect(container.read(mapProvider).selectedPeakListIds, isEmpty);
      expect(scheduler.pendingCount, 2);

      await scheduler.runPendingAt(1);
      await tester.pump();

      expect(
        find.byKey(const Key('peak-list-selection-chip-all-peaks')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('peak-list-selection-chip-1')), findsNothing);

      await scheduler.runPendingAt(0);
      await tester.pump();

      expect(
        container.read(mapProvider).peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );
      expect(
        find.byKey(const Key('peak-list-selection-chip-all-peaks')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('peak-list-selection-chip-1')), findsNothing);
    },
  );

  testWidgets('app bar chips use selected fill and unselected accent colours', (
    tester,
  ) async {
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
      peakListRepository: _peakListRepositoryWithItems([
        PeakList(name: 'Alpha', region: 'tasmania', colour: 0xFF4C8BF5)
          ..peakListId = 1,
        PeakList(name: 'Bravo', region: 'tasmania', colour: 0xFFE67E22)
          ..peakListId = 2,
      ]),
    );

    router.go('/map');
    await tester.pumpAndSettle();

    final selectedChip = tester.widget<OutlinedButton>(
      find.byKey(const Key('peak-list-selection-chip-1')),
    );
    final unselectedChip = tester.widget<OutlinedButton>(
      find.byKey(const Key('peak-list-selection-chip-2')),
    );

    expect(
      _resolvedBackgroundColor(selectedChip.style),
      const Color(0xFF4C8BF5),
    );
    expect(_resolvedSideColor(unselectedChip.style), const Color(0xFFE67E22));

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pumpAndSettle();

    final selectedDrawerRow = tester.widget<OutlinedButton>(
      find.byKey(const Key('peak-list-item-Alpha')),
    );
    final unselectedDrawerRow = tester.widget<OutlinedButton>(
      find.byKey(const Key('peak-list-item-Bravo')),
    );

    expect(
      _resolvedBackgroundColor(selectedDrawerRow.style),
      const Color(0xFF4C8BF5),
    );
    expect(
      _resolvedSideColor(unselectedDrawerRow.style),
      const Color(0xFFE67E22),
    );
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
  PeakListSelectionRefreshScheduler? refreshScheduler,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => TestMapNotifier(state)),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ??
              PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        if (refreshScheduler != null)
          peakListSelectionRefreshSchedulerProvider.overrideWithValue(
            refreshScheduler,
          ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Color? _resolvedBackgroundColor(ButtonStyle? style) {
  return style?.backgroundColor?.resolve(const <WidgetState>{});
}

Color? _resolvedSideColor(ButtonStyle? style) {
  return style?.side?.resolve(const <WidgetState>{})?.color;
}

class _ControlledPeakListSelectionRefreshScheduler {
  final _pendingTasks = <FutureOr<void> Function()>[];

  int get pendingCount => _pendingTasks.length;

  Future<void> call(FutureOr<void> Function() task) async {
    _pendingTasks.add(task);
  }

  Future<void> runPendingAt(int index) async {
    final task = _pendingTasks.removeAt(index);
    await task();
  }

  Future<void> runAllPending() async {
    while (_pendingTasks.isNotEmpty) {
      await runPendingAt(0);
    }
  }
}

PeakListRepository _peakListRepositoryWithItems(List<PeakList> peakLists) {
  final peaks = [
    for (final peakList in peakLists) _membershipPeakForList(peakList),
  ];
  final peaksById = {for (final peak in peaks) peak.osmId: peak};
  final items = <PeakListItemEntity>[];
  var itemId = 1;
  for (final peakList in peakLists) {
    items.add(
      PeakListItemEntity(id: itemId++, points: 0)
        ..peakList.target = peakList
        ..peak.target = peaksById[_membershipPeakId(peakList.peakListId)]!,
    );
  }

  return PeakListRepository.test(
    InMemoryPeakListStorage(peakLists),
    peakRepository: PeakRepository.test(InMemoryPeakStorage(peaks)),
    itemStorage: InMemoryPeakListItemEntityStorage(items),
  );
}

int _membershipPeakId(int peakListId) => peakListId * 1000;

Peak _membershipPeakForList(PeakList peakList) {
  final region = peakList.region.trim().isEmpty ? 'tasmania' : peakList.region;
  return switch (region) {
    'new-south-wales' => Peak(
      osmId: _membershipPeakId(peakList.peakListId),
      name: '${peakList.name} Peak',
      latitude: -33.8,
      longitude: 149.2,
      region: region,
    ),
    _ => Peak(
      osmId: _membershipPeakId(peakList.peakListId),
      name: '${peakList.name} Peak',
      latitude: -42.0,
      longitude: 146.0,
      region: region == PeakList.mixedRegion ? 'tasmania' : region,
    ),
  };
}
