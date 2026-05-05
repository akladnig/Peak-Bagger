import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'peak_list_export_robot.dart';

void main() {
  testWidgets('export peak lists happy path shows final success summary', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final robot = PeakListExportRobot(
      tester,
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      () async => const PeakListCsvExportResult(
        outputDirectoryPath: '/Users/adrian/Documents/Bushwalking/Peak_Lists',
        exportedFileCount: 2,
      ),
    );

    await robot.pumpApp();
    await robot.runExport();

    robot.expectStatusVisible('Exported 2 peak lists. Skipped 0 lists.');
  });

  testWidgets('export peak lists warning path shows final warning summary', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final robot = PeakListExportRobot(
      tester,
      repository,
      TestPeakNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      ),
      () async => const PeakListCsvExportResult(
        outputDirectoryPath: '/Users/adrian/Documents/Bushwalking/Peak_Lists',
        exportedFileCount: 1,
        skippedZeroResolvedRowListCount: 1,
        warningEntries: ['warning 1', 'warning 2'],
      ),
    );

    await robot.pumpApp();
    await robot.runExport();

    robot.expectStatusVisible(
      'Exported 1 peak list. Skipped 1 list. 2 warnings. Older files may remain for skipped lists.',
    );
  });
}
