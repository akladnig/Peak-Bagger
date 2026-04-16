import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('selected map label renders on one Tasmap layer', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
                selectedMap: map,
                tasmapDisplayMode: TasmapDisplayMode.selectedMap,
              ),
            ),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final layerFinder = find.descendant(
      of: find.byKey(const Key('tasmap-layer')),
      matching: find.byType(PolygonLayer),
    );
    expect(layerFinder, findsOneWidget);
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);

    final layer = tester.widget<PolygonLayer>(layerFinder);
    expect(layer.polygons, hasLength(1));

    final polygon = layer.polygons.single;
    expect(polygon.label, 'Adamsons\nTS07');
    expect(polygon.labelStyle.fontSize, 12);
    expect(polygon.labelStyle.shadows, isNotEmpty);
    expect(polygon.labelPlacementCalculator, isNotNull);
  });

  testWidgets('overlay labels render without selected map layer', (
    tester,
  ) async {
    final maps = [_adamsons(), _wellington()];
    final repository = await TestTasmapRepository.create(maps: maps);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
                tasmapDisplayMode: TasmapDisplayMode.overlay,
              ),
            ),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TasmapOutlineLayer), findsNothing);

    final layerFinder = find.byKey(const Key('tasmap-layer'));
    expect(layerFinder, findsOneWidget);

    final polygonLayer = tester.widget<PolygonLayer>(layerFinder);
    expect(polygonLayer.polygons, hasLength(2));
    expect(
      polygonLayer.polygons.map((p) => p.label),
      contains('Adamsons\nTS07'),
    );
    expect(
      polygonLayer.polygons.map((p) => p.label),
      contains('Wellington\nTQ08'),
    );
  });

  testWidgets('Tasmap labels hide below zoom 10', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 9,
                basemap: Basemap.tracestrack,
                selectedMap: map,
                tasmapDisplayMode: TasmapDisplayMode.selectedMap,
              ),
            ),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final layerFinder = find.descendant(
      of: find.byKey(const Key('tasmap-layer')),
      matching: find.byType(PolygonLayer),
    );
    final layer = tester.widget<PolygonLayer>(layerFinder);

    expect(layer.polygons.single.label, isNull);
  });
}

Tasmap50k _adamsons() {
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

Tasmap50k _wellington() {
  return Tasmap50k(
    series: 'TQ08',
    name: 'Wellington',
    parentSeries: '8312',
    mgrs100kIds: 'EN',
    eastingMin: 0,
    eastingMax: 39999,
    northingMin: 40000,
    northingMax: 69999,
    mgrsMid: 'EN',
    eastingMid: 20000,
    northingMid: 55000,
    p1: 'EN0000069999',
    p2: 'EN3999969999',
    p3: 'EN3999940000',
    p4: 'EN0000040000',
  );
}
