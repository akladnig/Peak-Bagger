import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../../harness/test_map_notifier.dart';

class GpxTracksRobot {
  GpxTracksRobot(this.tester, this.initialState);

  final WidgetTester tester;
  final MapState initialState;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get infoFab => find.byKey(const Key('map-info-fab'));

  Future<void> pumpApp() async {
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
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectTracksImportedAndVisible() {
    expect(initialState.tracks, isNotEmpty);
    expect(initialState.showTracks, isTrue);
    expect(showTracksFab, findsOneWidget);
    expect(importFab, findsOneWidget);
    expect(infoFab, findsOneWidget);
  }

  Future<void> toggleTracks() async {
    await tester.tap(showTracksFab);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  void expectTracksHidden() {
    expect(
      ProviderScope.containerOf(
        tester.element(showTracksFab),
      ).read(mapProvider).showTracks,
      isFalse,
    );
  }

  void expectTracksShown() {
    expect(
      ProviderScope.containerOf(
        tester.element(showTracksFab),
      ).read(mapProvider).showTracks,
      isTrue,
    );
  }
}
