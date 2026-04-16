import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_tasmap_repository.dart';
import 'tasmap_robot.dart';

void main() {
  testWidgets('reset map data then select a Tasmap from goto', (tester) async {
    SharedPreferences.setMockInitialValues({});

    final repository = await TestTasmapRepository.create();
    final robot = TasmapRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        syncEnabled: false,
      ),
      repository,
    );
    addTearDown(robot.dispose);

    await robot.pumpApp();
    robot.expectMapReady();

    await robot.openSettings();
    await robot.resetTasmapData();
    robot.expectResetStatusVisible();

    await robot.returnToMap();
    await robot.openSettings();
    expect(find.text('Map data reset successfully!'), findsNothing);

    await robot.returnToMap();
    robot.expectMapReady();

    await robot.openGotoInput();
    await robot.enterGotoQuery('Adamsons');
    await robot.selectGotoSuggestion('Adamsons');
    robot.expectSelectedMapOutlineVisible();
  });
}
