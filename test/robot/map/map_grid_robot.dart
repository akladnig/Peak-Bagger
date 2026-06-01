import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/widgets/left_tooltip_fab.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class MapGridRobot {
  MapGridRobot(this.tester, this.initialState, this.repository)
    : mapNotifier = TestMapNotifier(initialState);

  final WidgetTester tester;
  final MapState initialState;
  final TestTasmapRepository repository;
  final TestMapNotifier mapNotifier;

  Finder get gridMapFab => find.byKey(const Key('grid-map-fab'));
  Finder get zoomReadout => find.byKey(const Key('map-zoom-readout'));
  Finder get mgrsGridLabelLayer => find.byKey(const Key('mgrs-grid-label-layer'));

  Future<void> pumpMap() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => mapNotifier),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> tapGridFab() async {
    await tester.ensureVisible(gridMapFab);
    await tester.pumpAndSettle();
    await tester.tap(gridMapFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  String tooltipMessage() {
    return tester
        .widget<LeftTooltipFab>(
          find.ancestor(of: gridMapFab, matching: find.byType(LeftTooltipFab)),
        )
        .message;
  }
}

Tasmap50k mapGridRobotMap() {
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

MapState mapGridRobotState(Tasmap50k map) {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 15,
    basemap: Basemap.tracestrack,
    selectedMap: map,
  );
}
