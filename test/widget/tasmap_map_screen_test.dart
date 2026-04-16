import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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
    final center = repository.getMapCenter(map)!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
                zoom: 10,
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

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);

    final textFinder = find.descendant(
      of: labelLayerFinder,
      matching: find.text('Adamsons\nTS07'),
    );
    expect(textFinder, findsOneWidget);

    final text = tester.widget<Text>(textFinder);
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets('overlay labels render without selected map layer', (
    tester,
  ) async {
    final maps = [_adamsons(), _wellingtonTwin()];
    final repository = await TestTasmapRepository.create(maps: maps);
    final center = repository.getMapCenter(maps[0])!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
                zoom: 10,
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

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);

    expect(
      find.descendant(
        of: labelLayerFinder,
        matching: find.text('Adamsons\nTS07'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: labelLayerFinder,
        matching: find.text('Wellington\nTQ08'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Tasmap labels hide below zoom 10', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final center = repository.getMapCenter(map)!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
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

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);

    expect(
      find.descendant(of: labelLayerFinder, matching: find.byType(Text)),
      findsNothing,
    );
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

Tasmap50k _wellingtonTwin() {
  return Tasmap50k(
    series: 'TQ08',
    name: 'Wellington',
    parentSeries: '8312',
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
