import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/route_marker_display.dart';

export '../models/route_marker_display.dart' show RouteMarkerKind;

class RouteMarker extends StatelessWidget {
  const RouteMarker({
    super.key,
    required this.kind,
    required this.color,
    this.number,
    this.size = RouteUI.markerSize,
    this.strokeWidth = RouteUI.strokeWidth,
  });

  final RouteMarkerKind kind;
  final Color color;
  final int? number;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final markerSize = math.max(size, RouteUI.markerMinSize);
    final borderWidth = math.max(strokeWidth, 0.0);

    return SizedBox.square(
      dimension: markerSize,
      child: switch (kind) {
        RouteMarkerKind.circle => Container(
            key: const Key('route-marker-circle'),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: borderWidth),
            ),
          ),
        RouteMarkerKind.target => Stack(
            alignment: Alignment.center,
            children: [
              Container(
                key: const Key('route-marker-target-ring'),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: borderWidth),
                ),
              ),
              Container(
                key: const Key('route-marker-target-dot'),
                width: markerSize * 0.36,
                height: markerSize * 0.36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        RouteMarkerKind.numbered => Container(
            key: const Key('route-marker-numbered-fill'),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: _darkenedStroke(color),
                width: borderWidth,
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_clampNumber(number)}',
                  key: const Key('route-marker-numbered-label'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: RouteUI.markerFontSize,
                    fontWeight: FontWeight.w400,
                    height: 1.0,
                  ),
                ),
              ),
            ),
          ),
      },
    );
  }

  static int _clampNumber(int? value) {
    if (value == null) {
      return 1;
    }
    if (value < 1) {
      return 1;
    }
    if (value > 99) {
      return 99;
    }
    return value;
  }

  static Color _darkenedStroke(Color color) {
    return Color.lerp(color, Colors.black, RouteUI.strokeDarkenAlpha)!;
  }
}
