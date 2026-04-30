import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/peak_hover_detector.dart';

void main() {
  group('PeakHoverDetector', () {
    test('returns no match outside threshold', () {
      final result = PeakHoverDetector.findHoveredPeak(
        pointerPosition: const Offset(50, 50),
        candidates: const [
          PeakHoverCandidate(peakId: 1, screenPosition: Offset(0, 0)),
        ],
      );

      expect(result.hoveredPeakId, isNull);
      expect(result.distance, isNull);
    });

    test('chooses nearest peak and keeps first match on ties', () {
      final nearest = PeakHoverDetector.findHoveredPeak(
        pointerPosition: const Offset(0, 0),
        candidates: const [
          PeakHoverCandidate(peakId: 1, screenPosition: Offset(8, 0)),
          PeakHoverCandidate(peakId: 2, screenPosition: Offset(4, 0)),
        ],
      );
      final tie = PeakHoverDetector.findHoveredPeak(
        pointerPosition: const Offset(0, 0),
        candidates: const [
          PeakHoverCandidate(peakId: 3, screenPosition: Offset(5, 0)),
          PeakHoverCandidate(peakId: 4, screenPosition: Offset(-5, 0)),
        ],
      );

      expect(nearest.hoveredPeakId, 2);
      expect(nearest.distance, 4);
      expect(tie.hoveredPeakId, 3);
      expect(tie.distance, 5);
    });
  });
}
