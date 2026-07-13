import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import 'peak_list_pins_robot.dart';

void main() {
  testWidgets(
    'journey: select pin deselect switch regions hide restore and unpin',
    (tester) async {
      final robot = PeakListPinsRobot(tester);
      await robot.pumpApp();

      await robot.selectDrawerList('Alpha');
      expect(robot.appBarItem(1), findsOneWidget);

      await robot.pinDrawerList(1);
      expect(robot.notifier.state.pinnedPeakListIdsByRegion, {
        'tasmania': {1},
      });
      expect(robot.notifier.state.selectedPeakListIds, {1});

      await robot.tapAppBarToggle(1);
      expect(
        robot.notifier.state.peakListSelectionMode,
        PeakListSelectionMode.none,
      );
      expect(robot.appBarItem(1), findsOneWidget);

      await robot.setVisibleBounds(nswBounds);
      expect(robot.appBarItem(1), findsNothing);

      await robot.setVisibleBounds(multiRegionBounds);
      await robot.selectDrawerList('Bravo');
      expect(robot.appBarItem(1), findsOneWidget);
      expect(robot.appBarItem(2), findsOneWidget);

      await robot.setVisibleBounds(zeroRegionBounds);
      expect(robot.summaryRoot, findsNothing);

      await robot.setVisibleBounds(multiRegionBounds);
      expect(robot.appBarItem(1), findsOneWidget);
      expect(robot.appBarItem(2), findsOneWidget);

      await robot.tapAppBarUnpin(1);
      expect(robot.appBarItem(1), findsNothing);
      expect(robot.appBarItem(2), findsOneWidget);
    },
  );

  testWidgets(
    'journey: exact visible-region-set selection restores when returning',
    (tester) async {
      final robot = PeakListPinsRobot(tester);
      await robot.pumpApp();

      await robot.selectDrawerList('Alpha');
      expect(robot.notifier.state.selectedPeakListIds, {1});

      await robot.setVisibleBounds(nswBounds);
      expect(
        robot.notifier.state.peakListSelectionMode,
        PeakListSelectionMode.allPeaks,
      );

      await robot.selectDrawerList('Bravo');
      expect(robot.notifier.state.selectedPeakListIds, {2});

      await robot.setVisibleBounds(tasmaniaBounds);
      expect(
        robot.notifier.state.peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(robot.notifier.state.selectedPeakListIds, {1});
      expect(robot.appBarItem(1), findsOneWidget);
      expect(robot.appBarItem(2), findsNothing);

      await robot.setVisibleBounds(nswBounds);
      expect(
        robot.notifier.state.peakListSelectionMode,
        PeakListSelectionMode.specificList,
      );
      expect(robot.notifier.state.selectedPeakListIds, {2});
      expect(robot.appBarItem(1), findsNothing);
      expect(robot.appBarItem(2), findsOneWidget);
    },
  );
}
