import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';

void main() {
  test('buildTrailPolylines uses a stable layer key', () {
    final layer = buildTrailPolylines([
      Polyline(points: const []),
    ]);

    expect(layer.key, const ValueKey('trail-polyline-layer'));
    expect(layer.polylines, hasLength(1));
  });
}
