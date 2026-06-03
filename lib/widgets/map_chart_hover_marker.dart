import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme.dart';

MarkerLayer buildChartHoverMarkerLayer(LatLng point) {
  return MarkerLayer(
    key: const Key('map-chart-hover-marker-layer'),
    markers: [
      Marker(
        point: point,
        width: MapChartHoverDotTheme.size,
        height: MapChartHoverDotTheme.size,
        child: const _MapChartHoverMarker(),
      ),
    ],
  );
}

class _MapChartHoverMarker extends StatelessWidget {
  const _MapChartHoverMarker();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('map-chart-hover-marker'),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MapChartHoverDotTheme.color,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 1,
        ),
      ),
    );
  }
}
