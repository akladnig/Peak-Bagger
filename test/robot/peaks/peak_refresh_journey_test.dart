import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'peak_refresh_robot.dart';
import 'tassy_full_refresh_robot.dart';

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

  testWidgets('update tassy full journey rebuilds and reconciles selection', (
    tester,
  ) async {
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 5),
            const PeakListItem(peakOsmId: 22, points: 4),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'South West',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 2),
          ]),
        )..peakListId = 2,
        PeakList(
          name: 'Tassy Full',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 11, points: 1),
            const PeakListItem(peakOsmId: 33, points: 1),
          ]),
        )..peakListId = 3,
      ]),
    );
    final robot = TassyFullRefreshRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListId: 999,
      ),
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListId: 999,
        ),
      ),
    );

    await robot.pumpApp();
    await robot.openUpdateTassyFullDialog();
    robot.expectUpdateTassyFullConfirmVisible();

    await robot.confirmUpdateTassyFull();
    robot.expectUpdateTassyFullResultVisible(added: 1, updated: 1);
    expect(robot.notifier.state.peakListSelectionMode, PeakListSelectionMode.allPeaks);
    expect(robot.notifier.state.selectedPeakListId, isNull);
    expect(
      decodePeakListItems(repository.findByName('Tassy Full')!.peakList)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 5), (22, 4), (33, 1)],
    );
  });
}
