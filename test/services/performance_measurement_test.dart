import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/performance_measurement.dart';

void main() {
  test('kernel process birth replaces the conservative dispatch anchor', () {
    final records = <Map<String, Object?>>[];
    final measurement = PerformanceMeasurement(sink: records.add);
    measurement.correlateNativeClock(
      dartBeforeUs: 100,
      dartAfterUs: 120,
      nativeNowUs: 1010,
      launchBeforeExecUs: 500,
      processLaunchUs: 550,
      processLaunchUncertaintyUs: 2,
    );
    measurement.event('frame', {'dart_monotonic_us': 200});
    expect(records.single['process_launch_monotonic_us'], 550);
    expect(records.single['launch_to_endpoint_upper_bound_us'], 562);
    expect(records.single['dispatch_to_endpoint_upper_bound_us'], 610);
  });
  test('native clock correlation reports a bounded launch interval', () {
    final records = <Map<String, Object?>>[];
    final measurement = PerformanceMeasurement(sink: records.add);
    measurement.correlateNativeClock(
      dartBeforeUs: 100,
      dartAfterUs: 120,
      nativeNowUs: 1010,
      launchBeforeExecUs: 500,
    );
    measurement.event('frame', {'dart_monotonic_us': 200});
    expect(records.single['native_monotonic_us'], 1100);
    expect(records.single['clock_uncertainty_us'], 10);
    expect(records.single['launch_to_endpoint_upper_bound_us'], 610);
  });
}
