import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/router.dart';

class BackgroundJobsRobot {
  BackgroundJobsRobot(this.tester);

  final WidgetTester tester;

  Finder get navDashboard => find.byKey(const Key('nav-dashboard'));
  Finder get navMap => find.byKey(const Key('nav-map'));
  Finder get navSettings => find.byKey(const Key('nav-settings'));
  Finder get importTracksFab => find.byKey(const Key('import-tracks-fab'));
  Finder get exportPeakDataTile =>
      find.byKey(const Key('export-peak-data-tile'));
  Finder get backgroundJobsEntry =>
      find.byKey(const Key('background-jobs-entry'));
  Finder get backgroundJobsPanel =>
      find.byKey(const Key('background-jobs-panel'));
  Finder get backgroundJobsClearFinished =>
      find.byKey(const Key('background-jobs-clear-finished'));
  Finder get snackbarOpenJobs =>
      find.byKey(const Key('background-jobs-snackbar-open-jobs'));
  Finder get appBarTitle => find.byKey(const Key('app-bar-title'));
  Finder get importDialog => find.byKey(const Key('gpx-import-dialog'));
  Finder get selectFilesButton =>
      find.byKey(const Key('gpx-import-select-files'));
  Finder get importButton => find.byKey(const Key('gpx-import-button'));
  Finder get importSelectedRow => find.byKey(const Key('gpx-import-row-0'));

  Finder backgroundJobRow(int index) =>
      find.byKey(Key('background-jobs-row-background-job-$index'));
  Finder backgroundJobStatus(int index) =>
      find.byKey(Key('background-jobs-status-background-job-$index'));
  Finder backgroundJobProgress(int index) =>
      find.byKey(Key('background-jobs-progress-background-job-$index'));
  Finder backgroundJobDismiss(int index) =>
      find.byKey(Key('background-jobs-dismiss-background-job-$index'));
  Finder backgroundJobExpand(int index) =>
      find.byKey(Key('background-jobs-expand-background-job-$index'));

  Future<void> openDashboard() async {
    router.go('/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openSettings() async {
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openJobsFromSnackbar() async {
    await tester.tap(snackbarOpenJobs, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openJobsPanel() async {
    await tester.tap(backgroundJobsEntry, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> expandJob(int index) async {
    await tester.tap(backgroundJobExpand(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> dismissJob(int index) async {
    await tester.tap(backgroundJobDismiss(index), warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> clearFinishedJobs() async {
    await tester.tap(backgroundJobsClearFinished, warnIfMissed: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> startImport() async {
    await tester.ensureVisible(importTracksFab);
    await tester.pumpAndSettle();
    tester.widget<FloatingActionButton>(importTracksFab).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    tester.widget<FilledButton>(selectFilesButton).onPressed!.call();
    await tester.pump();
    for (var i = 0; i < 20 && importSelectedRow.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    for (var i = 0; i < 20; i++) {
      final button = tester.widget<FilledButton>(importButton);
      if (button.onPressed != null) {
        break;
      }
      await tester.pump(const Duration(milliseconds: 50));
    }
    tester.widget<FilledButton>(importButton).onPressed!.call();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> startPeakDataExport() async {
    await tester.scrollUntilVisible(
      exportPeakDataTile,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(exportPeakDataTile);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectTitle(String text) {
    expect(
      find.descendant(of: appBarTitle, matching: find.text(text)),
      findsOneWidget,
    );
  }

  void expectJobStatus(int index, String text) {
    expect(backgroundJobStatus(index), findsOneWidget);
    expect(
      find.descendant(
        of: backgroundJobStatus(index),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }

  void expectJobProgressText(int index, String text) {
    expect(backgroundJobProgress(index), findsOneWidget);
    expect(tester.widget<Text>(backgroundJobProgress(index)).data, text);
  }
}
