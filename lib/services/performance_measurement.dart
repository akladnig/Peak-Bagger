import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

/// Opt-in, structured monotonic observations. Never substitutes for success.
class PerformanceMeasurement {
  PerformanceMeasurement({
    void Function(Map<String, Object?>)? sink,
    this.enabled = true,
  }) : _sink = sink ?? _write;

  final bool enabled;
  final void Function(Map<String, Object?>) _sink;
  final Map<String, Object?> context = {};
  int? _nativeOffsetUs;
  int _clockUncertaintyUs = 0;
  int? _launchBeforeExecUs;
  int? _processLaunchUs;
  int _processLaunchUncertaintyUs = 0;

  void correlateNativeClock({
    required int dartBeforeUs,
    required int dartAfterUs,
    required int nativeNowUs,
    int? launchBeforeExecUs,
    int? processLaunchUs,
    int processLaunchUncertaintyUs = 0,
  }) {
    _nativeOffsetUs = nativeNowUs - ((dartBeforeUs + dartAfterUs) ~/ 2);
    _clockUncertaintyUs = (dartAfterUs - dartBeforeUs + 1) ~/ 2;
    _launchBeforeExecUs = launchBeforeExecUs;
    _processLaunchUs = processLaunchUs;
    _processLaunchUncertaintyUs = processLaunchUncertaintyUs;
  }

  static void _write(Map<String, Object?> record) =>
      stdout.writeln('[measurement] ${jsonEncode(record)}');

  void event(String name, [Map<String, Object?> fields = const {}]) {
    if (!enabled) return;
    final dartNow =
        fields['dart_monotonic_us'] as int? ?? developer.Timeline.now;
    final nativeNow = _nativeOffsetUs == null
        ? null
        : dartNow + _nativeOffsetUs!;
    _sink({
      ...context,
      'event': name,
      'dart_monotonic_us': dartNow,
      'native_monotonic_us': ?nativeNow,
      if (nativeNow != null) 'clock_uncertainty_us': _clockUncertaintyUs,
      if (nativeNow != null &&
          (_processLaunchUs ?? _launchBeforeExecUs) != null)
        'launch_to_endpoint_upper_bound_us':
            nativeNow +
            _clockUncertaintyUs +
            _processLaunchUncertaintyUs -
            (_processLaunchUs ?? _launchBeforeExecUs)!,
      if (nativeNow != null && _launchBeforeExecUs != null)
        'dispatch_to_endpoint_upper_bound_us':
            nativeNow + _clockUncertaintyUs - _launchBeforeExecUs!,
      'process_launch_monotonic_us': ?_processLaunchUs,
      if (_processLaunchUs != null)
        'process_launch_clock_uncertainty_us': _processLaunchUncertaintyUs,
      'build_mode': const bool.fromEnvironment('dart.vm.product')
          ? 'release'
          : const bool.fromEnvironment('dart.vm.profile')
          ? 'profile'
          : 'debug',
      ...fields,
    });
  }

  Future<T> phase<T>(
    String name,
    Future<T> Function() action, [
    Map<String, Object?> fields = const {},
  ]) async {
    if (!enabled) return action();
    final clock = Stopwatch()..start();
    event('$name.begin', fields);
    try {
      final result = await action();
      event('$name.end', {
        ...fields,
        'elapsed_us': clock.elapsedMicroseconds,
        'outcome': 'success',
      });
      return result;
    } catch (error) {
      event('$name.end', {
        ...fields,
        'elapsed_us': clock.elapsedMicroseconds,
        'outcome': 'failed',
        'error': '$error',
      });
      rethrow;
    }
  }

  T phaseSync<T>(String name, T Function() action) {
    if (!enabled) return action();
    final clock = Stopwatch()..start();
    event('$name.begin');
    try {
      final result = action();
      event('$name.end', {
        'elapsed_us': clock.elapsedMicroseconds,
        'outcome': 'success',
      });
      return result;
    } catch (error) {
      event('$name.end', {
        'elapsed_us': clock.elapsedMicroseconds,
        'outcome': 'failed',
        'error': '$error',
      });
      rethrow;
    }
  }
}

final performanceMeasurement = PerformanceMeasurement(
  enabled: const bool.fromEnvironment('MEASURE_PERFORMANCE'),
);
