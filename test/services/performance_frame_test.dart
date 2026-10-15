import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/performance_frame.dart';

FrameTiming _frame(int number, int start, int finish) => FrameTiming(
  vsyncStart: start - 10,
  buildStart: start,
  buildFinish: finish,
  rasterStart: finish + 1,
  rasterFinish: finish + 10,
  rasterFinishWallTime: finish + 1000,
  frameNumber: number,
);

void main() {
  test(
    'correlates post-frame after build finish across delayed timing batches',
    () {
      final correlation = PerformanceFrameCorrelation(callbackUs: 150);
      final old = _frame(1, 50, 60);
      final qualifying = _frame(2, 100, 140);
      final next = _frame(3, 160, 170);
      expect(correlation.observe([old]), isNull);
      expect(correlation.observe([qualifying]), isNull);
      expect(correlation.observe([next])?.frameNumber, 2);
    },
  );
}
