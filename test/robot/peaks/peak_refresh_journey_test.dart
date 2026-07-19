import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

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
          importedCount: 1234,
          skippedCount: 1234,
          warning: '1,234 peaks skipped',
        ),
      ),
    );

    await robot.pumpApp();
    await robot.openRefreshDialog();
    robot.expectConfirmDialogVisible();

    await robot.confirmRefresh();
    expect(robot.notifier.refreshCallCount, 1);
    robot.expectResultVisible('1,234', warning: '1,234 peaks skipped');
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
    final repository = await _peakListRepository(
      peaks: [
        _peak(11),
        _peak(22),
        _peak(33),
        _peak(44, region: 'new-south-wales'),
      ],
      definitions: [
        (
          peakList: PeakList(peakListId: 1, name: 'Abels'),
          items: const [
            PeakListItem(peakOsmId: 11, points: 5),
            PeakListItem(peakOsmId: 22, points: 4),
            PeakListItem(peakOsmId: 44, points: 7),
          ],
        ),
        (
          peakList: PeakList(peakListId: 2, name: 'South West'),
          items: const [PeakListItem(peakOsmId: 11, points: 2)],
        ),
        (
          peakList: PeakList(peakListId: 3, name: 'Tassy Full'),
          items: const [
            PeakListItem(peakOsmId: 11, points: 1),
            PeakListItem(peakOsmId: 33, points: 1),
            PeakListItem(peakOsmId: 44, points: 1),
          ],
        ),
      ],
    );
    final robot = TassyFullRefreshRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {999},
      ),
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListIds: {999},
        ),
      ),
    );

    await robot.pumpApp();
    robot.expectUpdateTassyFullSubtitleVisible();
    await robot.openUpdateTassyFullDialog();
    robot.expectUpdateTassyFullConfirmVisible();

    await robot.confirmUpdateTassyFull();
    robot.expectUpdateTassyFullResultVisible(added: 1, updated: 2, removed: 0);
    expect(
      robot.notifier.state.peakListSelectionMode,
      PeakListSelectionMode.specificList,
    );
    expect(robot.notifier.state.selectedPeakListIds, {999});
    expect(
      repository
          .getPeakListItemsForList(repository.findByName('Tassy Full')!.peakListId)
          .map((item) => (item.peakOsmId, item.points))
          .toList(),
      [(11, 5), (22, 4), (33, 1), (44, 7)],
    );
  });
}

Future<PeakListRepository> _peakListRepository({
  required List<Peak> peaks,
  required List<({PeakList peakList, List<PeakListItem> items})> definitions,
}) async {
  final peakRepository = PeakRepository.test(InMemoryPeakStorage(peaks));
  final repository = PeakListRepository.test(
    InMemoryPeakListStorage(),
    peakRepository: peakRepository,
  );
  for (final definition in definitions) {
    await repository.save(definition.peakList, items: definition.items);
  }
  return repository;
}

Peak _peak(int osmId, {String region = Peak.defaultRegion}) {
  return Peak(
    osmId: osmId,
    name: 'Peak $osmId',
    latitude: -41.5,
    longitude: 146.5,
    region: region,
  );
}
