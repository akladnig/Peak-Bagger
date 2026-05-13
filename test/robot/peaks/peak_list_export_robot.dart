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
  final PeakListCsvExportRunner exportRunner;
  final TestTasmapNotifier tasmapNotifier;

  Finder get exportTile => find.byKey(const Key('export-peak-lists-tile'));
  Finder get exportStatus => find.byKey(const Key('peak-list-export-status'));
  Finder get settingsScrollable => find.byKey(const Key('settings-scrollable'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListCsvExportRunnerProvider.overrideWithValue(exportRunner),
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
    await tester.pumpAndSettle();

    for (var i = 0; i < 3 && exportStatus.evaluate().isEmpty; i++) {
      await tester.drag(settingsScrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
  }

  void expectStatusVisible(String expected) {
    final text = tester.widget<Text>(exportStatus);
    expect(text.data, expected);
  }
}
