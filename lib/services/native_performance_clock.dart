import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';

import 'performance_measurement.dart';

const _clockChannel = MethodChannel('peak_bagger/performance');

void _enableEngineTimings(List<FrameTiming> timings) {}

Future<void> initializeNativePerformanceClock() async {
  if (!performanceMeasurement.enabled || !Platform.isMacOS) return;
  var lastHeartbeatUs = developer.Timeline.now;
  // Process-lifetime measurement probe; a delayed timer is a UI-isolate gap,
  // not proof that a macOS spinning cursor was displayed.
  Timer.periodic(const Duration(milliseconds: 50), (_) {
    final now = developer.Timeline.now;
    final gap = now - lastHeartbeatUs;
    lastHeartbeatUs = now;
    if (gap > 100000) {
      performanceMeasurement.event('event-loop.gap', {'gap_us': gap});
    }
  });
  // Enable engine timing collection before qualifying frames are rasterized.
  // Per-screen one-shot callbacks added after framework paint can then consume
  // the queued timing batch. This registration lives for the app process.
  SchedulerBinding.instance.addTimingsCallback(_enableEngineTimings);
  try {
    final before = developer.Timeline.now;
    final clock = await _clockChannel.invokeMapMethod<String, Object?>('clock');
    final after = developer.Timeline.now;
    if (clock == null) return;
    performanceMeasurement.correlateNativeClock(
      dartBeforeUs: before,
      dartAfterUs: after,
      nativeNowUs: clock['native_now_us'] as int,
      launchBeforeExecUs: clock['launch_before_exec_us'] as int?,
      processLaunchUs: clock['process_launch_us'] as int?,
      processLaunchUncertaintyUs:
          clock['process_launch_clock_uncertainty_us'] as int? ?? 0,
    );
    performanceMeasurement.context.addAll({
      'run_id': clock['run_id'],
      'condition': clock['condition'],
      'repetition': clock['repetition'],
      'launch_method': clock['launch_method'],
      'native_entry_us': clock['native_entry_us'],
      'launch_before_exec_us': clock['launch_before_exec_us'],
      'process_launch_clock_method': clock['process_launch_clock_method'],
    });
    performanceMeasurement.event('clock.correlation', {
      'dart_before_us': before,
      'dart_after_us': after,
      'native_now_us': clock['native_now_us'],
      'method': 'mach_absolute_time / bracketed method-channel midpoint',
    });
  } catch (error) {
    performanceMeasurement.event('clock.unavailable', {'error': '$error'});
  }
}
