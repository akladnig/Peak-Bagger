import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'peak_refresh_robot.dart';

void main() {
  testWidgets('refresh peak data flow returns success and warning', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final robot = PeakRefreshRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
        refreshHandler: () async => const PeakRefreshResult(
          importedCount: 3,
          skippedCount: 1,
          warning: '1 peaks skipped',
        ),
      ),
    );

    await robot.pumpApp();
    await robot.openRefreshDialog();
    robot.expectConfirmDialogVisible();

    await robot.confirmRefresh();
    expect(robot.notifier.refreshCallCount, 1);
    robot.expectResultVisible('3', warning: '1 peaks skipped');
  });

  testWidgets('refresh peak data flow shows failure dialog', (tester) async {
    final repository = await TestTasmapRepository.create();
    final robot = PeakRefreshRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
        refreshHandler: () async {
          throw StateError('boom');
        },
      ),
    );

    await robot.pumpApp();
    await robot.openRefreshDialog();
    robot.expectConfirmDialogVisible();

    await robot.confirmRefresh();
    expect(robot.notifier.refreshCallCount, 1);
    robot.expectFailureVisible('boom');
  });
}
