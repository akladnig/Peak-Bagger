import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

import '../harness/natural_feature_mapping_harness.dart';
import 'mapping_store_failure_robot.dart';

void main() {
  for (final populated in [false, true]) {
    testWidgets(
      'Natural Features ${populated ? 'refresh' : 'bootstrap'} dismisses and retries its original source',
      (tester) async {
        final harness = NaturalFeatureMappingHarness(populated: populated);
        addTearDown(harness.dispose);
        final robot = MappingStoreFailureRobot(tester);
        await robot.pumpSurface(harness.container, harness.surface);
        final key = populated
            ? const MappingStoreOperationKey.naturalFeaturesRefresh()
            : const MappingStoreOperationKey.naturalFeaturesBootstrap();
        harness.pending = Completer<void>();
        final operation = harness.start(key);
        await tester.pump();
        if (!populated) robot.expectUnavailable('natural-features');
        harness.pending!.complete();
        await operation;
        await tester.pump();
        robot.expectFailure('Features/features.json');
        await robot.dismiss();
        robot.expectUnavailable('natural-features');
        harness.repaired = true;
        await robot.retryFeature('natural-features');
        robot.expectAvailable('natural-features');
        expect(harness.reads, 2);
        expect(harness.repository.getAllNaturalFeatures(), hasLength(1));
        expect(harness.operations.failureFor(key), isNull);
      },
    );
  }
}
