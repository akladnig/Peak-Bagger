import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_tasmap_repository.dart';
import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import 'tasmap_robot.dart';

void main() {
  testWidgets('reset map data then select a Tasmap from goto', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final repository = await TestTasmapRepository.create();
    final robot = TasmapRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        syncEnabled: false,
      ),
      repository,
    );
    addTearDown(robot.dispose);

    await robot.pumpApp();
    robot.expectMapReady();

    await robot.openSettings();
    await robot.resetTasmapData();
    robot.expectResetStatusVisible();

    await robot.returnToMap();
    await robot.openSettings();
    expect(find.text('Map data reset successfully!'), findsNothing);

    await robot.returnToMap();
    robot.expectMapReady();

    await robot.openGotoInput();
    await robot.enterGotoQuery('Adamsons');
    await robot.selectGotoSuggestion('Adamsons');
    robot.expectSelectedMapOutlineVisible();
  });

  testWidgets('reset map data refreshes map screen tasmap reads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final repository = await TestTasmapRepository.create();
    final initialState = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      tasmapDisplayMode: TasmapDisplayMode.overlay,
      syncEnabled: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    final initialCalls = repository.getAllMapsCallCount;

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('reset-map-data-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.getAllMapsCallCount, greaterThan(initialCalls));
  });
}
