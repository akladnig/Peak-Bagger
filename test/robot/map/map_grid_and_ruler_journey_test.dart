import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import '../../harness/test_tasmap_repository.dart';
import 'map_grid_robot.dart';

void main() {
  testWidgets('grid journey cycles tooltips and shows ruler/readout state', (
    tester,
  ) async {
    final map = mapGridRobotMap();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final robot = MapGridRobot(tester, mapGridRobotState(map), repository);

    await robot.pumpMap();

    expect(robot.zoomReadout, findsOneWidget);
    expect(robot.tooltipMessage(), 'Show Map Grid');
    expect(robot.mapNotifier.state.gridVisibility, MapGridVisibility.hidden);

    await robot.tapGridFab();
    expect(robot.tooltipMessage(), 'Show Map and MGRS Grid');
    expect(
      robot.mapNotifier.state.gridVisibility,
      MapGridVisibility.mapGridOnly,
    );
    expect(robot.zoomReadout, findsOneWidget);

    await robot.tapGridFab();
    expect(robot.tooltipMessage(), 'Hide Grids');
    expect(
      robot.mapNotifier.state.gridVisibility,
      MapGridVisibility.mapGridAndDistanceGrid,
    );
    expect(robot.zoomReadout, findsOneWidget);

    await robot.tapGridFab();
    expect(robot.tooltipMessage(), 'Show Map Grid');
    expect(robot.mapNotifier.state.gridVisibility, MapGridVisibility.hidden);
    expect(robot.zoomReadout, findsOneWidget);
  });

  testWidgets('grid journey uses mgrs-only cycle outside sheet-backed regions', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create(maps: []);
    final robot = MapGridRobot(tester, nonSheetMapGridRobotState(), repository);

    await robot.pumpMap();

    expect(robot.tooltipMessage(), 'Show MGRS Grid');
    expect(robot.mapNotifier.state.gridVisibility, MapGridVisibility.hidden);

    await robot.tapGridFab();
    expect(robot.tooltipMessage(), 'Hide MGRS Grid');
    expect(robot.mapNotifier.state.gridVisibility, MapGridVisibility.mapGridOnly);

    await robot.tapGridFab();
    expect(robot.tooltipMessage(), 'Show MGRS Grid');
    expect(robot.mapNotifier.state.gridVisibility, MapGridVisibility.hidden);
  });
}
