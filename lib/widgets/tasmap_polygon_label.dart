import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

const double tasmapPolygonLabelDefaultInsetX = 0;
const double tasmapPolygonLabelDefaultInsetY = 50;
const EdgeInsets _tasmapPolygonLabelPadding = EdgeInsets.symmetric(
  horizontal: 6,
  vertical: 4,
);

String? formatTasmapPolygonLabel(Tasmap50k map) {
  final name = map.name.trim();
  final series = map.series.trim();

  if (name.isEmpty && series.isEmpty) {
    return null;
  }

  if (name.isEmpty) {
    return series;
  }

  if (series.isEmpty) {
    return name;
  }

  return '$name\n$series';
}

LatLng? tasmapPolygonLabelAnchor(
  List<LatLng> points, {
  MapCamera? camera,
  double insetX = tasmapPolygonLabelDefaultInsetX,
  double insetY = tasmapPolygonLabelDefaultInsetY,
}) {
  if (points.length < 4) {
    return null;
  }

  final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
  final maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

  if (camera == null) {
    final maxLat = points
        .map((p) => p.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((p) => p.longitude)
        .reduce((a, b) => a < b ? a : b);

    final latInset = ((maxLat - minLat).abs() * 0.08).clamp(0.0001, 0.02);
    final lngInset = ((maxLng - minLng).abs() * 0.08).clamp(0.0001, 0.02);

    return LatLng(minLat + latInset, maxLng - lngInset);
  }

  final corner = LatLng(minLat, maxLng);
  final screenOffset = camera.latLngToScreenOffset(corner);

  return camera.screenOffsetToLatLng(
    Offset(screenOffset.dx + insetX, screenOffset.dy + insetY),
  );
}

Offset? tasmapPolygonLabelScreenOffset(
  List<LatLng> points, {
  required MapCamera camera,
  double insetX = tasmapPolygonLabelDefaultInsetX,
  double insetY = tasmapPolygonLabelDefaultInsetY,
}) {
  if (points.length < 4) {
    return null;
  }

  final minLat = points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
  final maxLng = points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);
  final corner = LatLng(minLat, maxLng);
  final screenOffset = camera.latLngToScreenOffset(corner);

  return Offset(screenOffset.dx - insetX, screenOffset.dy - insetY);
}

Widget tasmapPolygonLabelWidget({
  required String label,
  required Color color,
  required Color backgroundColor,
}) {
  return DecoratedBox(
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Padding(
      padding: _tasmapPolygonLabelPadding,
      child: Text(
        label,
        textAlign: TextAlign.left,
        style: tasmapPolygonLabelStyle(color),
      ),
    ),
  );
}

PolygonLabelPlacementCalculator? tasmapPolygonLabelPlacementCalculator(
  List<LatLng> points,
) {
  return points.length < 4
      ? null
      : const _TasmapPolygonLabelPlacementCalculator();
}

TextStyle tasmapPolygonLabelStyle(Color color) {
  return TextStyle(
    fontSize: 12,
    color: color,
    // shadows: const [
    //   Shadow(color: Colors.black54, blurRadius: 2, offset: Offset(1, 1)),
    //   Shadow(color: Colors.black26, blurRadius: 3, offset: Offset(-1, -1)),
    // ],
  );
}

class _TasmapPolygonLabelPlacementCalculator
    implements PolygonLabelPlacementCalculator {
  const _TasmapPolygonLabelPlacementCalculator();

  @override
  LatLng call(Polygon<Object> polygon) {
    return tasmapPolygonLabelAnchor(polygon.points)!;
  }

  @override
  bool operator ==(Object other) =>
      other is _TasmapPolygonLabelPlacementCalculator;

  @override
  int get hashCode => 0;
}

class TasmapPolygonLabelEntry {
  const TasmapPolygonLabelEntry({
    required this.points,
    required this.label,
    required this.color,
  });

  final List<LatLng> points;
  final String label;
  final Color color;
}

class TasmapPolygonLabelLayer extends StatelessWidget {
  const TasmapPolygonLabelLayer({
    super.key,
    required this.entries,
    this.insetX = tasmapPolygonLabelDefaultInsetX,
    this.insetY = tasmapPolygonLabelDefaultInsetY,
  });

  final List<TasmapPolygonLabelEntry> entries;
  final double insetX;
  final double insetY;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final labels = <Widget>[];

    for (final entry in entries) {
      final entryInsetX = insetX + entry.label.length * 6;
      final offset = tasmapPolygonLabelScreenOffset(
        entry.points,
        camera: camera,
        insetX: entryInsetX,
        insetY: insetY,
      );
      if (offset != null) {
        labels.add(
          Positioned(
            left: offset.dx,
            top: offset.dy,
            child: IgnorePointer(
              child: tasmapPolygonLabelWidget(
                label: entry.label,
                color: entry.color,

                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surface.withValues(alpha: 0.8),
              ),
            ),
          ),
        );
      }
    }

    return MobileLayerTransformer(child: Stack(children: labels));
  }
}
