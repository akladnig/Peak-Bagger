import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/widgets/tasmap_polygon_label.dart';

class TasmapOutlineLayer extends StatelessWidget {
  const TasmapOutlineLayer({
    super.key,
    required this.points,
    this.label,
    this.labelStyle,
    this.labelPlacementCalculator,
  });

  final List<LatLng> points;
  final String? label;
  final TextStyle? labelStyle;
  final PolygonLabelPlacementCalculator? labelPlacementCalculator;

  @override
  Widget build(BuildContext context) {
    final polygonLabelStyle =
        labelStyle ?? tasmapPolygonLabelStyle(Colors.blue);
    return KeyedSubtree(
      key: key,
      child: PolygonLayer(
        polygons: [
          Polygon(
            points: points,
            color: Colors.transparent,
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
            label: label,
            labelStyle: polygonLabelStyle,
            labelPlacementCalculator: label == null
                ? null
                : labelPlacementCalculator,
          ),
        ],
      ),
    );
  }
}
