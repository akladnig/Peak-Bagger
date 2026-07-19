import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_csv_export_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  Future<void> scrollSettingsUntilVisible(
    WidgetTester tester,
    Finder target, {
    double dragOffset = -500,
  }) async {
    final settingsScrollable = find.byKey(const Key('settings-scrollable'));
    for (var i = 0; i < 4 && target.evaluate().isEmpty; i++) {
      await tester.drag(settingsScrollable, Offset(0, dragOffset));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('export peak lists shows loading state and success', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final completer = Completer<PeakListCsvExportResult>();
    var exportCalls = 0;
    Future<PeakListCsvExportResult> exportRunner({
      PeakListCsvExportProgressCallback? onProgress,
    }) {
      exportCalls += 1;
      onProgress?.call(
        const PeakListCsvExportProgress(
          completedFileCount: 0,
          totalFileCount: 1234,
          currentFileName: 'abels-peak-list.csv',
          currentFileWrittenRowCount: 0,
          currentFileTotalRowCount: 12,
        ),
      );
      return completer.future;
    }

    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportBackgroundRunnerProvider.overrideWithValue(
            exportRunner,
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await scrollSettingsUntilVisible(
      tester,
      find.byKey(const Key('export-peak-lists-tile')),
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(exportCalls, 1);
    expect(notifier.reloadPeakMarkersCallCount, 0);
    expect(find.text('Export started'), findsOneWidget);
    expect(find.byKey(const Key('peak-list-export-status')), findsNothing);
    expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);
    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();
    expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
    expect(find.text('0 / 1234 files'), findsOneWidget);
    expect(find.text('0 / 12 rows'), findsOneWidget);
    expect(find.text('abels-peak-list.csv'), findsOneWidget);
    await tester.tap(find.byKey(const Key('background-jobs-close')));
    await tester.pump();

    completer.complete(
      const PeakListCsvExportResult(
        outputDirectoryPath: '/Users/adrian/Documents/Bushwalking/Peak_Lists',
        exportedFileCount: 1234,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();
    expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('background-jobs-expand-background-job-1')),
    );
    await tester.pump();
    expect(notifier.reloadPeakMarkersCallCount, 0);
    expect(find.text('Files written: 1,234'), findsOneWidget);
    expect(
      find.text('Destination: /Users/adrian/Documents/Bushwalking/Peak_Lists'),
      findsOneWidget,
    );
  });

  testWidgets('export peak lists shows warning-bearing success summary', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportBackgroundRunnerProvider.overrideWithValue(({
            PeakListCsvExportProgressCallback? onProgress,
          }) async {
            return PeakListCsvExportResult(
              outputDirectoryPath:
                  '/Users/adrian/Documents/Bushwalking/Peak_Lists',
              exportedFileCount: 1234,
              skippedMalformedListCount: 1234,
              warningEntries: List<String>.filled(1234, 'warning'),
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await scrollSettingsUntilVisible(
      tester,
      find.byKey(const Key('export-peak-lists-tile')),
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('background-jobs-expand-background-job-1')),
    );
    await tester.pump();

    expect(find.text('Warnings: 1,234'), findsOneWidget);
    expect(find.text('Skipped lists: 1,234'), findsOneWidget);
  });

  testWidgets('export peak lists shows zero-output success state', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportBackgroundRunnerProvider.overrideWithValue(({
            PeakListCsvExportProgressCallback? onProgress,
          }) async {
            return const PeakListCsvExportResult(
              outputDirectoryPath:
                  '/Users/adrian/Documents/Bushwalking/Peak_Lists',
              exportedFileCount: 0,
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await scrollSettingsUntilVisible(
      tester,
      find.byKey(const Key('export-peak-lists-tile')),
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('background-jobs-expand-background-job-1')),
    );
    await tester.pump();
    expect(find.text('Files written: 0'), findsOneWidget);
    expect(find.text('Skipped lists: 0'), findsOneWidget);
  });

  testWidgets('export peak lists shows failure with path detail', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportBackgroundRunnerProvider.overrideWithValue(({
            PeakListCsvExportProgressCallback? onProgress,
          }) async {
            throw const PeakListCsvExportException(
              'Peak_Lists directory does not exist at /tmp/Peak_Lists. Create the folder and retry.',
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await scrollSettingsUntilVisible(
      tester,
      find.byKey(const Key('export-peak-lists-tile')),
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Export failed:'), findsOneWidget);
    expect(find.textContaining('/tmp/Peak_Lists'), findsOneWidget);
    expect(find.textContaining('Create the folder and retry'), findsOneWidget);
    expect(find.byKey(const Key('peak-list-export-status')), findsNothing);
  });
}
