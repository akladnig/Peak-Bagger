import 'package:flutter/material.dart';

const dashboardSecondarySeriesColor = Color(0xFF2E7D32);

Color lighterSeriesColor(Color color, [double delta = 0.15]) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withLightness((hsl.lightness + delta).clamp(0.0, 1.0).toDouble())
      .toColor();
}
