import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_csv_export_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class PeakListExportRobot {
  PeakListExportRobot(
    this.tester,
    this.repository,
    this.notifier,
    this.exportRunner,
  ) : tasmapNotifier = TestTasmapNotifier(repository);

  final WidgetTester tester;
  final TestTasmapRepository repository;
  final TestPeakNotifier notifier;
  final PeakListCsvExportBackgroundRunner exportRunner;
  final TestTasmapNotifier tasmapNotifier;

  Finder get exportTile => find.byKey(const Key('export-peak-lists-tile'));
  Finder get settingsScrollable => find.byKey(const Key('settings-scrollable'));
  Finder get backgroundJobsEntry =>
      find.byKey(const Key('background-jobs-entry'));
  Finder get backgroundJobsPanel =>
      find.byKey(const Key('background-jobs-panel'));
  Finder get backgroundJobsClearFinished =>
      find.byKey(const Key('background-jobs-clear-finished'));
  Finder get snackbarOpenJobs =>
      find.byKey(const Key('background-jobs-snackbar-open-jobs'));
  Finder backgroundJobRow(int index) =>
      find.byKey(Key('background-jobs-row-background-job-$index'));
  Finder backgroundJobStatus(int index) =>
      find.byKey(Key('background-jobs-status-background-job-$index'));
  Finder backgroundJobProgress(int index) =>
      find.byKey(Key('background-jobs-progress-background-job-$index'));
  Finder backgroundJobExpand(int index) =>
      find.byKey(Key('background-jobs-expand-background-job-$index'));
  Finder backgroundJobDismiss(int index) =>
      find.byKey(Key('background-jobs-dismiss-background-job-$index'));
  Finder get navDashboard => find.byKey(const Key('nav-dashboard'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportBackgroundRunnerProvider.overrideWithValue(
            exportRunner,
          ),
          tasmapStateProvider.overrideWith(() => tasmapNotifier),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> runExport() async {
    for (var i = 0; i < 3 && exportTile.evaluate().isEmpty; i++) {
      await tester.drag(settingsScrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.tap(exportTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openDashboard() async {
    await tester.tap(navDashboard, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openBackgroundJobsFromSnackbar() async {
    await tester.tap(snackbarOpenJobs, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openBackgroundJobsPanel() async {
    await tester.tap(backgroundJobsEntry, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> expandBackgroundJob(int index) async {
    await tester.tap(backgroundJobExpand(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> dismissBackgroundJob(int index) async {
    await tester.tap(backgroundJobDismiss(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> clearFinishedBackgroundJobs() async {
    await tester.tap(backgroundJobsClearFinished, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectBackgroundJobStatus(int index, String text) {
    expect(backgroundJobStatus(index), findsOneWidget);
    expect(
      find.descendant(
        of: backgroundJobStatus(index),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }

  void expectBackgroundJobProgressText(int index, String text) {
    expect(backgroundJobProgress(index), findsOneWidget);
    expect(tester.widget<Text>(backgroundJobProgress(index)).data, text);
  }
}
