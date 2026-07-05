import 'package:flutter/material.dart';

import '../core/number_formatters.dart';
import '../models/peak.dart';
import '../theme.dart';

class PeakMarkerGlyph extends StatelessWidget {
  const PeakMarkerGlyph({
    required this.ticked,
    this.untickedColourValue,
    this.size = 20,
    super.key,
  });

  final bool ticked;
  final int? untickedColourValue;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PeakMarkerGlyphPainter(
        ticked: ticked,
        untickedColourValue: untickedColourValue,
      ),
    );
  }
}

class PeakMarkerHelper extends StatelessWidget {
  const PeakMarkerHelper({
    required this.peak,
    required this.ticked,
    required this.showPeakInfo,
    this.untickedColourValue,
    this.hovered = false,
    super.key,
  });

  final Peak peak;
  final bool ticked;
  final bool showPeakInfo;
  final int? untickedColourValue;
  final bool hovered;

  @override
  Widget build(BuildContext context) {
    final markerSize = hovered ? 32.0 : 20.0;
    final labelTop = markerSize;
    final labelWidth = peakMarkerLabelMaxWidth(context);

    return SizedBox(
      width: markerSize,
      height: markerSize,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (hovered)
            Stack(
              key: Key('peak-marker-hover-${peak.osmId}'),
              alignment: Alignment.center,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.amber, width: 3),
                  ),
                ),
                PeakMarkerGlyph(
                  ticked: ticked,
                  untickedColourValue: untickedColourValue,
                ),
              ],
            )
          else
            PeakMarkerGlyph(
              ticked: ticked,
              untickedColourValue: untickedColourValue,
            ),
          if (showPeakInfo)
            Positioned(
              top: labelTop,
              left: (markerSize - labelWidth) / 2,
              width: labelWidth,
              child: _PeakMarkerLabels(peak: peak),
            ),
        ],
      ),
    );
  }
}

class _PeakMarkerLabels extends StatelessWidget {
  const _PeakMarkerLabels({required this.peak});

  final Peak peak;

  @override
  Widget build(BuildContext context) {
    final maxWidth = peakMarkerLabelMaxWidth(context);
    final name = peak.name.trim().isEmpty ? '—' : peak.name.trim();
    final height = peak.elevation == null
        ? '—'
        : formatElevation(peak.elevation!.round(), showUnits: false);
    final labelStyle = peakMarkerLabelTextStyle(context);

    return ConstrainedBox(
      key: Key('peak-marker-labels-${peak.osmId}'),
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          OutlinedText(
            key: Key('peak-marker-name-${peak.osmId}'),
            text: name,
            style: labelStyle,
            maxLines: 2,
          ),
          OutlinedText(
            key: Key('peak-marker-height-${peak.osmId}'),
            text: height,
            style: labelStyle,
          ),
        ],
      ),
    );
  }
}

class _PeakMarkerGlyphPainter extends CustomPainter {
  const _PeakMarkerGlyphPainter({
    required this.ticked,
    this.untickedColourValue,
  });

  final bool ticked;
  final int? untickedColourValue;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20;
    final center = Offset(size.width / 2, size.height / 2);
    final path = Path()
      ..moveTo(center.dx, center.dy - 9 * scale)
      ..lineTo(center.dx - 7 * scale, center.dy + 7 * scale)
      ..lineTo(center.dx + 7 * scale, center.dy + 7 * scale)
      ..close();
    final fill = Paint()
      ..color = ticked
          ? tickedColour
          : (untickedColourValue == null
                ? untickedColour
                : Color(untickedColourValue!));
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _PeakMarkerGlyphPainter oldDelegate) {
    return oldDelegate.ticked != ticked ||
        oldDelegate.untickedColourValue != untickedColourValue;
  }
}
