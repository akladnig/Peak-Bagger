import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class PeakRefreshRobot {
  PeakRefreshRobot(
    this.tester,
    this.initialState,
    this.repository,
    this.notifier,
  ) : tasmapNotifier = TestTasmapNotifier(repository);

  final WidgetTester tester;
  final MapState initialState;
  final TestTasmapRepository repository;
  final TestPeakNotifier notifier;
  final TestTasmapNotifier tasmapNotifier;

  Finder get refreshPeakDataTile =>
      find.byKey(const Key('refresh-peak-data-tile'));
  Finder get peakRefreshConfirm =>
      find.byKey(const Key('peak-refresh-confirm'));
  Finder get peakRefreshCancel => find.byKey(const Key('peak-refresh-cancel'));
  Finder get peakRefreshStatus => find.byKey(const Key('peak-refresh-status'));
  Finder get peakRefreshResultClose =>
      find.byKey(const Key('peak-refresh-result-close'));
  Finder get peakRefreshErrorClose =>
      find.byKey(const Key('peak-refresh-error-close'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
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

  Future<void> openRefreshDialog() async {
    await tester.tap(refreshPeakDataTile);
    await tester.pump();
  }

  Future<void> confirmRefresh() async {
    await tester.tap(peakRefreshConfirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> cancelRefresh() async {
    await tester.tap(peakRefreshCancel);
    await tester.pump();
  }

  void expectConfirmDialogVisible() {
    expect(find.text('Refresh Peak Data?'), findsOneWidget);
  }

  void expectStatusVisible(String expected) {
    final text = tester.widget<Text>(peakRefreshStatus);
    expect(text.data, expected);
  }

  void expectResultVisible(String importedCount, {String? warning}) {
    expect(find.text('Peak Data Refreshed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('$importedCount Peaks imported'),
      ),
      findsOneWidget,
    );
    if (warning != null) {
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(warning),
        ),
        findsOneWidget,
      );
    }
    expect(peakRefreshResultClose, findsOneWidget);
  }

  void expectFailureVisible(String contains) {
    expect(find.text('Peak Data Refresh Failed'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining(contains),
      ),
      findsOneWidget,
    );
    expect(peakRefreshErrorClose, findsOneWidget);
  }
}
