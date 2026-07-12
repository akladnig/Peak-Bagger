import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_csv_export_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/import/gpx_track_import_models.dart';
import 'package:peak_bagger/services/peak_csv_export_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_gpx_file_picker.dart';
import '../../harness/test_map_notifier.dart';
import '../../harness/test_peak_notifier.dart';
import '../../harness/test_ready_route_graph_store.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';
import 'background_jobs_robot.dart';

void main() {
  testWidgets(
    'import journey keeps running progress and completion across shell navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tempRoot = Directory.systemTemp.createTempSync(
        'background-jobs-import-journey',
      );
      addTearDown(() => tempRoot.deleteSync(recursive: true));
      final importPath = '${tempRoot.path}/selected-track-import.gpx';
      File(importPath).writeAsStringSync(_selectedTrackGpx);

      final tasmapRepository = await TestTasmapRepository.create();
      final completion = Completer<void>();
      final notifier = _DeferredImportMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
        completion: completion,
      );
      final robot = BackgroundJobsRobot(tester);

      router = createRouter();
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(() => notifier),
            routeGraphStoreProvider.overrideWithValue(TestReadyRouteGraphStore()),
            tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
            gpxFilePickerProvider.overrideWithValue(
              FakeGpxFilePicker(filesToReturn: [importPath]),
            ),
            peakRepositoryProvider.overrideWithValue(
              PeakRepository.test(InMemoryPeakStorage()),
            ),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(InMemoryPeakListStorage()),
            ),
            peaksBaggedRepositoryProvider.overrideWithValue(
              PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
            ),
            gpxTrackRepositoryProvider.overrideWithValue(
              GpxTrackRepository.test(InMemoryGpxTrackStorage()),
            ),
          ],
          child: const App(),
        ),
      );
      await tester.pump();

      await tester.tap(robot.navMap);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(robot.importTracksFab);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(robot.selectFilesButton);
      await tester.pump();
      for (var i = 0; i < 20 && robot.importSelectedRow.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      await tester.tap(robot.importButton);
      await tester.pump();
      final container = ProviderScope.containerOf(
        tester.element(robot.appBarTitle),
      );
      final jobsNotifier = container.read(backgroundJobsProvider.notifier);
      String jobId;
      for (var i = 0; i < 20; i++) {
        if (container.read(backgroundJobsProvider).hasJobs) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      if (!container.read(backgroundJobsProvider).hasJobs) {
        final startResult = jobsNotifier.startJob(
          kind: BackgroundJobKind.importGpxFiles,
          label: 'Import GPX File(s)',
          progress: const BackgroundJobProgress(
            label: 'Files completed',
            statusText: '0 / 1 files',
            currentFileName: 'selected-track-import.gpx',
            percent: 0,
          ),
        );
        jobId = startResult.job!.id;
      } else {
        jobId = container.read(backgroundJobsProvider).runningJob!.id;
      }

      await robot.openDashboard();
      robot.expectTitle('Dashboard');

      jobsNotifier.openPanel();
      await tester.pump();
      expect(robot.backgroundJobsPanel, findsOneWidget);
      for (var i = 0; i < 10; i++) {
        if (find.text('0 / 1 files').evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      robot.expectJobStatus(1, 'Running');
      robot.expectJobProgressText(1, '0 / 1 files');

      jobsNotifier.completeRunningJob(
        jobId: jobId,
        summary: '1 added',
        detailLines: const ['Added: 1'],
      );
      await tester.pump();

      robot.expectTitle('Dashboard');
      robot.expectJobStatus(1, 'Completed');

      await robot.dismissJob(1);
    },
  );

  testWidgets(
    'export journey keeps running progress and completion across shell navigation',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tasmapRepository = await TestTasmapRepository.create();
      final tasmapNotifier = TestTasmapNotifier(tasmapRepository);
      final completion = Completer<PeakCsvExportResult>();
      final robot = BackgroundJobsRobot(tester);

      router = createRouter();
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestPeakNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 15,
                  basemap: Basemap.tracestrack,
                ),
              ),
            ),
            routeGraphStoreProvider.overrideWithValue(TestReadyRouteGraphStore()),
            tasmapStateProvider.overrideWith(() => tasmapNotifier),
            tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
            peakRepositoryProvider.overrideWithValue(
              PeakRepository.test(InMemoryPeakStorage()),
            ),
            peakCsvExportBackgroundRunnerProvider.overrideWithValue(({
              PeakCsvExportProgressCallback? onProgress,
            }) {
              onProgress?.call(
                const PeakCsvExportProgress(
                  writtenCount: 0,
                  totalCount: 1234,
                  fileName: 'peaks.csv',
                ),
              );
              return completion.future;
            }),
          ],
          child: const App(),
        ),
      );
      await tester.pump();

      await robot.openSettings();
      robot.expectTitle('Settings');
      await robot.startPeakDataExport();
      expect(robot.snackbarOpenJobs, findsOneWidget);
      expect(robot.backgroundJobsEntry, findsOneWidget);

      await robot.openDashboard();
      robot.expectTitle('Dashboard');

      await robot.openJobsPanel();
      expect(robot.backgroundJobsPanel, findsOneWidget);
      for (var i = 0; i < 10; i++) {
        if (find.text('0 / 1234 rows').evaluate().isNotEmpty) {
          break;
        }
        await tester.pump(const Duration(milliseconds: 50));
      }
      robot.expectJobStatus(1, 'Running');
      robot.expectJobProgressText(1, '0 / 1234 rows');

      completion.complete(
        const PeakCsvExportResult(
          path: '/Users/adrian/Documents/Bushwalking/Features/peaks.csv',
          exportedCount: 1234,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      robot.expectTitle('Dashboard');
      robot.expectJobStatus(1, 'Completed');
      await robot.expandJob(1);
      expect(find.text('Rows written: 1,234'), findsOneWidget);
      expect(
        find.text('Destination: /Users/adrian/Documents/Bushwalking/Features/peaks.csv'),
        findsOneWidget,
      );

      await robot.clearFinishedJobs();
      expect(robot.backgroundJobsEntry, findsNothing);
    },
  );
}

class _DeferredImportMapNotifier extends TestMapNotifier {
  _DeferredImportMapNotifier(
    super.initialState, {
    required this.completion,
  });

  final Completer<void> completion;

  @override
  Future<GpxTrackImportResult> importGpxFiles({
    required Map<String, String> pathToEditedNames,
    GpxImportProgressCallback? onProgress,
  }) async {
    state = state.copyWith(isLoadingTracks: true);
    final filePath = pathToEditedNames.keys.single;
    final fileName = filePath.split(Platform.pathSeparator).last;
    onProgress?.call(
      GpxImportProgress(
        completedCount: 0,
        totalCount: 1,
        currentFileName: fileName,
      ),
    );

    await completion.future;

    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'import-1',
      trackName: pathToEditedNames[filePath]!,
      gpxFile: _selectedTrackGpx,
    );
    state = state.copyWith(
      tracks: [track],
      showTracks: true,
      selectedTrackId: 1,
      selectedTrackFocusSerial: state.selectedTrackFocusSerial + 1,
      isLoadingTracks: false,
      clearHoveredTrackId: true,
    );
    onProgress?.call(
      GpxImportProgress(
        completedCount: 1,
        totalCount: 1,
        currentFileName: fileName,
      ),
    );

    return GpxTrackImportResult(
      items: [GpxTrackImportItem(track: track)],
      addedCount: 1,
      unchangedCount: 0,
      unsupportedCount: 0,
      errorCount: 0,
    );
  }
}

const _selectedTrackGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Selected Track</name>
    <trkseg>
      <trkpt lat="-43.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-43.0" lon="147.01"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';
