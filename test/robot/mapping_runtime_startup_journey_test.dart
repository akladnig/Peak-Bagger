import 'package:flutter_test/flutter_test.dart';

import '../harness/mapping_runtime_startup_harness.dart';
import 'mapping_store_failure_robot.dart';

void main() {
  testWidgets(
    'unavailable startup retries a synchronized generation and opens the normal ready surface',
    (tester) async {
      final harness = MappingRuntimeStartupHarness();
      addTearDown(harness.dispose);
      final robot = MappingStoreFailureRobot(tester);
      await robot.pumpStartup(harness.shell);
      robot.expectReplicaStartupUnavailable('/local/replica');
      harness.synchronizationReady();
      await robot.retryStartup();
      robot.expectStartupChecking();
      harness.finishReadiness();
      await tester.pumpAndSettle();
      robot.expectReadySurface();
      expect(harness.initializeCalls, 1);
      expect(harness.catalogRoots, [
        '/local/replica/generations/complete/payload',
      ]);
    },
  );
}
