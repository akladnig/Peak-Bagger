import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';

void main() {
  group('resolvePeakInfoPopupPlacement', () {
    test('places popup to the right of the marker by default', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(100, 100),
        viewportSize: const Size(500, 300),
        popupSize: UiConstants.peakInfoPopupSize,
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(126, 30));
    });

    test('flips left when right placement would overflow', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(460, 100),
        viewportSize: const Size(500, 300),
        popupSize: UiConstants.peakInfoPopupSize,
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(114, 30));
    });

    test('clamps vertically within margin', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(100, 20),
        viewportSize: const Size(500, 300),
        popupSize: UiConstants.peakInfoPopupSize,
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(126, 8));
    });

    test('clamps vertically near the bottom edge', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(100, 280),
        viewportSize: const Size(500, 300),
        popupSize: UiConstants.peakInfoPopupSize,
      );

      expect(placement.isAnchorable, isTrue);
      expect(placement.topLeft, const Offset(126, 152));
    });

    test('reports unanchorable when anchor is outside viewport', () {
      final placement = resolvePeakInfoPopupPlacement(
        anchorScreenOffset: const Offset(-1, 100),
        viewportSize: const Size(500, 300),
        popupSize: UiConstants.peakInfoPopupSize,
      );

      expect(placement.isAnchorable, isFalse);
    });
  });
}
