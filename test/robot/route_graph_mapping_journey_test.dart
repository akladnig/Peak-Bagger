import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/widgets/map_route_bottom_sheet.dart';

import '../harness/route_graph_mapping_harness.dart';
import 'mapping_store_failure_robot.dart';

void main() {
  testWidgets(
    'route planning preserves its segment after dismissal and retries its coverage',
    (tester) async {
      final harness = await RouteGraphMappingHarness.create();
      addTearDown(harness.dispose);
      harness.access.sources['Highways/tasmania.json'] = '{}';
      final robot = MappingStoreFailureRobot(tester);
      await robot.pumpSurface(
        harness.container,
        const RouteDraftGraphOverlay(),
      );
      harness.plan();
      await tester.pump();
      await tester.pump();
      robot.expectFailure('Highways/tasmania.json');
      // Starting an already-active draft is a no-op and must retain its retry.
      harness.notifier.beginRouteDraft();
      await robot.dismiss();
      robot.expectUnavailable('route-planning');
      expect(harness.planner.coverages, isEmpty);
      harness.access.sources.clear();
      await robot.retryFeature('route-planning');
      await tester.pump();
      await tester.pump();
      robot.expectAvailable('route-planning');
      expect(harness.planner.coverages, ['tasmania']);
      expect(harness.access.reads, [
        'Highways/tasmania.json',
        'Highways/tasmania.json',
      ]);
      await tester.pumpAndSettle();
    },
  );
}
