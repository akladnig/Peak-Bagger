import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import 'gpx_tracks_harness.dart';

class GpxTracksRobot {
  GpxTracksRobot(this.tester, this.harness);

  final WidgetTester tester;
  final GpxTracksHarness harness;

  Finder get showTracksFab => find.byKey(const Key('show-tracks-fab'));
  Finder get importFab => find.byKey(const Key('import-tracks-fab'));
  Finder get infoFab => find.byKey(const Key('map-info-fab'));

  Future<void> pumpApp() async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: harness.container,
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
    final mapState = harness.container.read(mapProvider);
    expect(mapState.tracks, isNotEmpty);
    expect(mapState.showTracks, isTrue);
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
    expect(harness.container.read(mapProvider).showTracks, isFalse);
  }

  void expectTracksShown() {
    expect(harness.container.read(mapProvider).showTracks, isTrue);
  }
}
