import 'dart:ui';
import 'dart:developer' as developer;

import 'package:flutter/scheduler.dart';

import 'performance_measurement.dart';

class PerformanceFrameCorrelation {
  PerformanceFrameCorrelation({required this.callbackUs});
  final int callbackUs;
  FrameTiming? _candidate;
  int? nextBuildStartUs;

  FrameTiming? observe(List<FrameTiming> timings) {
    for (final frame in timings) {
      final start = frame.timestampInMicroseconds(FramePhase.buildStart);
      if (start <= callbackUs) {
        _candidate = frame;
      } else if (_candidate != null) {
        nextBuildStartUs = start;
        return _candidate;
      }
    }
    return null;
  }
}

/// Attach raster-thread evidence to a qualifying framework frame. Delivery of
/// FrameTiming is batched; use the raster timestamp, never callback arrival time.
/// Raster finish is not a WindowServer/display presentation timestamp.
VoidCallback recordRasterizedPerformanceFrame(
  PerformanceMeasurement measurement,
  String event,
  Map<String, Object?> fields,
) {
  if (!measurement.enabled) return () {};
  final binding = SchedulerBinding.instance;
  final vsyncUs = binding.currentSystemFrameTimeStamp.inMicroseconds;
  final frameworkCallbackUs = developer.Timeline.now;
  var registered = true;
  final correlation = PerformanceFrameCorrelation(
    callbackUs: frameworkCallbackUs,
  );
  late TimingsCallback callback;
  callback = (timings) {
    // postFrame runs after scene submission; buildFinish may precede it.
    final matched = correlation.observe(timings);
    if (matched == null) return;
    binding.removeTimingsCallback(callback);
    registered = false;
    measurement.event('$event.rasterized', {
      ...fields,
      'endpoint': 'raster-finish',
      'frame_number': matched.frameNumber,
      'framework_vsync_us': vsyncUs,
      'vsync_start_us': matched.timestampInMicroseconds(FramePhase.vsyncStart),
      'framework_callback_us': frameworkCallbackUs,
      'build_start_us': matched.timestampInMicroseconds(FramePhase.buildStart),
      'build_finish_us': matched.timestampInMicroseconds(
        FramePhase.buildFinish,
      ),
      'next_build_start_us': correlation.nextBuildStartUs,
      'dart_monotonic_us': matched.timestampInMicroseconds(
        FramePhase.rasterFinish,
      ),
      'build_us': matched.buildDuration.inMicroseconds,
      'raster_us': matched.rasterDuration.inMicroseconds,
      if (fields['accepted_dart_us'] case final int acceptedUs)
        'elapsed_us':
            matched.timestampInMicroseconds(FramePhase.rasterFinish) -
            acceptedUs,
    });
  };
  binding.addTimingsCallback(callback);
  binding.scheduleFrame();
  return () {
    if (registered) {
      binding.removeTimingsCallback(callback);
      registered = false;
    }
  };
}
