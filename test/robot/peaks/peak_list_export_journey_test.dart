import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'peak_list_export_robot.dart';

void main() {
  testWidgets(
    'export peak lists journey keeps progress across shell navigation',
    (tester) async {
      final repository = await TestTasmapRepository.create();
      final completer = Completer<PeakListCsvExportResult>();
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
        ({PeakListCsvExportProgressCallback? onProgress}) {
          onProgress?.call(
            const PeakListCsvExportProgress(
              completedFileCount: 0,
              totalFileCount: 2,
              currentFileName: 'alpha-list-peak-list.csv',
              currentFileWrittenRowCount: 1,
              currentFileTotalRowCount: 3,
            ),
          );
          return completer.future;
        },
      );

      await robot.pumpApp();
      await robot.runExport();
      expect(robot.snackbarOpenJobs, findsOneWidget);

      await robot.openDashboard();
      expect(find.byKey(const Key('app-bar-title')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('app-bar-title')),
          matching: find.text('Dashboard'),
        ),
        findsOneWidget,
      );

      await robot.openBackgroundJobsFromSnackbar();
      expect(robot.backgroundJobsPanel, findsOneWidget);
      robot.expectBackgroundJobStatus(1, 'Running');
      robot.expectBackgroundJobProgressText(1, '0 / 2 files');

      completer.complete(
        const PeakListCsvExportResult(
          outputDirectoryPath: '/Users/adrian/Documents/Bushwalking/Peak_Lists',
          exportedFileCount: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      robot.expectBackgroundJobStatus(1, 'Completed');
      await robot.expandBackgroundJob(1);
      expect(find.text('Files written: 2'), findsOneWidget);
      expect(
        find.text(
          'Destination: /Users/adrian/Documents/Bushwalking/Peak_Lists',
        ),
        findsOneWidget,
      );
      await robot.clearFinishedBackgroundJobs();
      expect(robot.backgroundJobsEntry, findsNothing);
    },
  );

  testWidgets(
    'export peak lists warning path keeps completed warning details',
    (tester) async {
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
        ({PeakListCsvExportProgressCallback? onProgress}) async {
          return PeakListCsvExportResult(
            outputDirectoryPath:
                '/Users/adrian/Documents/Bushwalking/Peak_Lists',
            exportedFileCount: 1234,
            skippedZeroResolvedRowListCount: 1234,
            warningEntries: List<String>.filled(1234, 'warning'),
          );
        },
      );

      await robot.pumpApp();
      await robot.runExport();
      await robot.openBackgroundJobsPanel();
      robot.expectBackgroundJobStatus(1, 'Completed');
      await robot.expandBackgroundJob(1);
      expect(find.text('Skipped lists: 1,234'), findsOneWidget);
      expect(find.text('Warnings: 1,234'), findsOneWidget);
      await robot.dismissBackgroundJob(1);
      expect(robot.backgroundJobsEntry, findsNothing);
    },
  );
}
