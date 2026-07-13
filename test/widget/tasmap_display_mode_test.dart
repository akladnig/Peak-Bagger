import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/widgets/left_tooltip_fab.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets(
    'grid cycles visibility states without forcing selected map visible',
    (tester) async {
      final selectedMap = _tasmapMap();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 12,
                  basemap: Basemap.tracestrack,
                  selectedMap: selectedMap,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: Stack(children: [MapActionRail()])),
          ),
        ),
      );

      await tester.pump();

      final gridFab = find.byKey(const Key('grid-map-fab'));
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapActionRail)),
      );
      expect(
        container.read(mapProvider).gridVisibility,
        MapGridVisibility.hidden,
      );
      expect(_tooltipMessageFor(gridFab, tester), 'Show Map Grid');

      await tester.ensureVisible(gridFab);
      await tester.pumpAndSettle();
      await tester.tap(gridFab);
      await tester.pump();
      expect(
        container.read(mapProvider).gridVisibility,
        MapGridVisibility.mapGridOnly,
      );
      expect(
        container.read(mapProvider).tasmapDisplayMode,
        TasmapDisplayMode.selectedMap,
      );
      expect(_tooltipMessageFor(gridFab, tester), 'Show Map and MGRS Grid');

      await tester.ensureVisible(gridFab);
      await tester.pumpAndSettle();
      await tester.tap(gridFab);
      await tester.pump();
      expect(
        container.read(mapProvider).gridVisibility,
        MapGridVisibility.mapGridAndDistanceGrid,
      );
      expect(_tooltipMessageFor(gridFab, tester), 'Hide Grids');

      await tester.ensureVisible(gridFab);
      await tester.pumpAndSettle();
      await tester.tap(gridFab);
      await tester.pump();
      expect(
        container.read(mapProvider).gridVisibility,
        MapGridVisibility.hidden,
      );
      expect(
        container.read(mapProvider).tasmapDisplayMode,
        TasmapDisplayMode.none,
      );
      expect(_tooltipMessageFor(gridFab, tester), 'Show Map Grid');
    },
  );

  testWidgets('grid uses mgrs-only copy in non sheet-backed viewports', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(46.05, 14.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Stack(children: [MapActionRail()])),
        ),
      ),
    );

    await tester.pump();

    final gridFab = find.byKey(const Key('grid-map-fab'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapActionRail)),
    );
    expect(_tooltipMessageFor(gridFab, tester), 'Show MGRS Grid');

    await tester.ensureVisible(gridFab);
    await tester.pumpAndSettle();
    await tester.tap(gridFab);
    await tester.pump();

    expect(
      container.read(mapProvider).gridVisibility,
      MapGridVisibility.mapGridOnly,
    );
    expect(
      container.read(mapProvider).tasmapDisplayMode,
      TasmapDisplayMode.none,
    );
    expect(_tooltipMessageFor(gridFab, tester), 'Hide MGRS Grid');

    await tester.ensureVisible(gridFab);
    await tester.pumpAndSettle();
    await tester.tap(gridFab);
    await tester.pump();

    expect(
      container.read(mapProvider).gridVisibility,
      MapGridVisibility.hidden,
    );
    expect(_tooltipMessageFor(gridFab, tester), 'Show MGRS Grid');
  });
}

String _tooltipMessageFor(Finder fab, WidgetTester tester) {
  return tester
      .widget<LeftTooltipFab>(
        find.ancestor(of: fab, matching: find.byType(LeftTooltipFab)),
      )
      .message;
}

Tasmap50k _tasmapMap() {
  return Tasmap50k(
    series: 'TS07',
    name: 'Adamsons',
    parentSeries: '8211',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}
