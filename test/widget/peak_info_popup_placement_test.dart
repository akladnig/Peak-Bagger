import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';

void main() {
  group('resolvePeakInfoPopupPlacement', () {
    test('places popup to the right of the marker by default', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(100, 100),
        viewportSize: const Size(400, 300),
        popupSize: const Size(120, 80),
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(126, 60));
    });

    test('flips left when right placement would overflow', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(360, 100),
        viewportSize: const Size(400, 300),
        popupSize: const Size(120, 80),
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(214, 60));
    });

    test('clamps vertically within margin', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(100, 20),
        viewportSize: const Size(400, 300),
        popupSize: const Size(120, 80),
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(126, 8));
    });

    test('reports unanchorable when anchor is outside viewport', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(-1, 100),
        viewportSize: const Size(400, 300),
        popupSize: const Size(120, 80),
      );

      expect(placement.isAnchorable, isFalse);
    });
  });
}
