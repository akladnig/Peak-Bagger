import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('tasmap outline uses csv order and outline styling', (
    tester,
  ) async {
    final selectedMap = _tasmapMap();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FlutterMap(
            mapController: MapController(),
            options: MapOptions(
              initialCenter: const LatLng(-41.5, 146.5),
              initialZoom: 12,
            ),
            children: [
              TasmapOutlineLayer(
                key: const Key('tasmap-outline-layer'),
                points: _expectedPoints(selectedMap),
              ),
            ],
          ),
        ),
      ),
    );

    await tester.pump();

    final layerFinder = find.descendant(
      of: find.byKey(const Key('tasmap-outline-layer')),
      matching: find.byType(PolygonLayer),
    );
    expect(layerFinder, findsOneWidget);

    final layer = tester.widget<PolygonLayer>(layerFinder);
    expect(layer.polygons, hasLength(1));

    final polygon = layer.polygons.single;
    expect(polygon.color, Colors.transparent);
    expect(polygon.borderColor, Colors.blue);
    expect(polygon.points, _expectedPoints(selectedMap));
  });

  testWidgets('tasmap reset reimports from csv', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
                syncEnabled: false,
              ),
            ),
          ),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('reset-map-data-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Map data reset successfully!'), findsWidgets);
  });
}

class TestTasmapNotifier extends TasmapNotifier {
  @override
  TasmapState build() => const TasmapState();

  @override
  Future<TasmapCsvImportResult> resetAndReimport() async {
    state = state.copyWith(mapCount: 75);
    return const TasmapCsvImportResult(
      maps: [],
      importedCount: 75,
      skippedCount: 0,
    );
  }
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

List<LatLng> _expectedPoints(Tasmap50k map) {
  return map.polygonPoints
      .map((point) {
        final coords = mgrs.Mgrs.toPoint('55G$point');
        return LatLng(coords[1], coords[0]);
      })
      .toList(growable: false);
}
