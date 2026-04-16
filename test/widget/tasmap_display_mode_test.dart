import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/widgets/map_action_rail.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('Grid cycles Tasmap display modes', (tester) async {
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
                tasmapDisplayMode: TasmapDisplayMode.overlay,
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

    await tester.tap(find.byKey(const Key('grid-map-fab')));
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MapActionRail)),
    );
    expect(
      container.read(mapProvider).tasmapDisplayMode,
      TasmapDisplayMode.none,
    );

    await tester.tap(find.byKey(const Key('grid-map-fab')));
    await tester.pump();
    expect(
      container.read(mapProvider).tasmapDisplayMode,
      TasmapDisplayMode.selectedMap,
    );

    await tester.tap(find.byKey(const Key('grid-map-fab')));
    await tester.pump();
    expect(
      container.read(mapProvider).tasmapDisplayMode,
      TasmapDisplayMode.overlay,
    );
  });
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
