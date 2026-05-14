import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'dashboard_robot.dart';

void main() {
  testWidgets('dashboard journey reorders cards and restores layout', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final robot = DashboardRobot(tester);

    final firstContainer = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 12,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        tasmapRepositoryProvider.overrideWithValue(
          await TestTasmapRepository.create(),
        ),
      ],
    );
    addTearDown(firstContainer.dispose);
    await robot.pumpApp(container: firstContainer);
    await robot.openDashboard();

    expect(robot.board, findsOneWidget);
    expect(robot.card('distance'), findsOneWidget);
    expect(robot.dragHandle('distance'), findsOneWidget);

    await robot.container
        .read(dashboardLayoutProvider.notifier)
        .moveCard('distance', 'peaks-bagged');
    final savedOrder = [
      'elevation',
      'latest-walk',
      'distance',
      'peaks-bagged',
      'top-5-highest',
      'top-5-walks',
    ];
    robot.expectOrder(savedOrder);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(dashboardCardOrderStorageKey), savedOrder);

    SharedPreferences.setMockInitialValues({
      dashboardCardOrderStorageKey: savedOrder,
    });

    final secondContainer = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 12,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        tasmapRepositoryProvider.overrideWithValue(
          await TestTasmapRepository.create(),
        ),
      ],
    );
    addTearDown(secondContainer.dispose);
    await robot.pumpApp(container: secondContainer);
    await robot.openDashboard();

    expect(robot.board, findsOneWidget);
    expect(robot.card('distance'), findsOneWidget);
    expect(robot.dragHandle('distance'), findsOneWidget);
  });
}
