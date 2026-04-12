import 'package:flutter_test/flutter_test.dart';

import 'gpx_tracks_harness.dart';
import 'gpx_tracks_robot.dart';

void main() {
  testWidgets('import happy path then toggle hides and shows tracks', (
    tester,
  ) async {
    final harness = await GpxTracksHarness.create();
    addTearDown(harness.dispose);

    final robot = GpxTracksRobot(tester, harness);
    await robot.pumpApp();

    robot.expectTracksImportedAndVisible();

    await robot.toggleTracks();
    robot.expectTracksHidden();

    await robot.toggleTracks();
    robot.expectTracksShown();
  }, skip: true);
}
