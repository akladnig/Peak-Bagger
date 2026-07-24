import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_map_notifier.dart';

class RecoveryRobot {
  RecoveryRobot(this.tester, this.initialState);

  final WidgetTester tester;
  final MapState initialState;

  Finder get banner => find.text('Some tracks need to be rebuilt.');
  Finder get bannerAction =>
      find.byKey(const Key('open-track-recovery-settings'));
  Finder get resetTrackTile => find.byKey(const Key('reset-track-data-tile'));
  Finder get resetButton => find.byKey(const Key('reset-track-data-confirm'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get settingsScrollable => find.byKey(const Key('settings-scrollable'));

  Future<void> pumpApp() async {
    tester.view.physicalSize = const Size(1024, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
        child: const App(),
      ),
    );
    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> openSettingsFromBanner() async {
    await tester.ensureVisible(bannerAction);
    await tester.pumpAndSettle();
    await tester.tap(bannerAction);
    await tester.pumpAndSettle();
  }

  Future<void> resetTrackData() async {
    for (var i = 0; i < 6 && resetTrackTile.evaluate().isEmpty; i++) {
      await tester.drag(settingsScrollable, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(resetTrackTile);
    await tester.pumpAndSettle();
    await tester.tap(resetButton);
    await tester.pumpAndSettle();
  }
}
