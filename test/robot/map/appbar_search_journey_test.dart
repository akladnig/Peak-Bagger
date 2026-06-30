import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'appbar_search_robot.dart';

void main() {
  testWidgets('journey: open from app bar and select peak', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.enterQuery('Bonnet');
    await robot.tapPeakResult();

    final state = robot.container().read(mapProvider);
    expect(state.selectedPeaks.map((peak) => peak.osmId), contains(6406));
  });

  testWidgets('journey: open from cmd+f and select track', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromKeyboard();
    await robot.enterQuery('Bonnet');
    await robot.tapTrackResult();

    final state = robot.container().read(mapProvider);
    expect(state.selectedTrackId, 1);
    expect(state.selectedLocation, isNotNull);
  });

  testWidgets('journey: select route and map results', (tester) async {
    final robot = AppBarSearchRobot(tester);
    await robot.pumpApp();

    await robot.openFromAppBar();
    await robot.enterQuery('Bonnet');
    await robot.tapRouteResult();

    var state = robot.container().read(mapProvider);
    expect(state.selectedRouteId, 1);

    await robot.openFromAppBar();
    await robot.enterQuery('Alpha');
    await robot.tapMapResult();

    state = robot.container().read(mapProvider);
    expect(state.selectedMap?.name, 'Alpha Map');
    expect(state.selectedMapFocusSerial, greaterThan(0));
  });
}
