import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class TassyFullRefreshRobot {
  TassyFullRefreshRobot(
    this.tester,
    this.initialState,
    this.repository,
    this.notifier,
  );

  final WidgetTester tester;
  final MapState initialState;
  final PeakListRepository repository;
  final TestPeakNotifier notifier;

  Finder get updateTassyFullPeakListTile =>
      find.byKey(const Key('update-tassy-full-peak-list-tile'));
  Finder get updateTassyFullConfirm =>
      find.byKey(const Key('update-tassy-full-confirm'));
  Finder get updateTassyFullCancel =>
      find.byKey(const Key('update-tassy-full-cancel'));
  Finder get updateTassyFullResultClose =>
      find.byKey(const Key('update-tassy-full-result-close'));
  Finder get updateTassyFullErrorClose =>
      find.byKey(const Key('update-tassy-full-error-close'));
  Finder get settingsScrollable => find.byType(Scrollable).last;

  Future<void> pumpApp() async {
    tester.view.physicalSize = const Size(1024, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final tasmapRepository = await TestTasmapRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          peakListRepositoryProvider.overrideWithValue(repository),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(tasmapRepository)),
          tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openUpdateTassyFullDialog() async {
    await tester.scrollUntilVisible(
      updateTassyFullPeakListTile,
      200,
      scrollable: settingsScrollable,
    );
    await tester.tap(updateTassyFullPeakListTile);
    await tester.pump();
  }

  Future<void> confirmUpdateTassyFull() async {
    await tester.tap(updateTassyFullConfirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  void expectUpdateTassyFullConfirmVisible() {
    expect(find.text('Update Tassy Full Peak List?'), findsOneWidget);
  }

  void expectUpdateTassyFullResultVisible({
    required int added,
    required int updated,
  }) {
    expect(find.text('Tassy Full Peak List Updated'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Added $added ${added == 1 ? 'peak' : 'peaks'}'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching:
            find.text('Updated $updated ${updated == 1 ? 'peak' : 'peaks'}'),
      ),
      findsOneWidget,
    );
    expect(updateTassyFullResultClose, findsOneWidget);
  }
}
