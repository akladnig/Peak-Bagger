import 'dart:math' as math;
import 'dart:ui' show Offset;

enum MapTrackpadGestureType { none, pinchZoom, verticalZoom }

class MapTrackpadGestureIntent {
  const MapTrackpadGestureIntent._(this.type, this.zoomDelta);

  const MapTrackpadGestureIntent.none()
    : this._(MapTrackpadGestureType.none, 0);

  const MapTrackpadGestureIntent.pinchZoom(double zoomDelta)
    : this._(MapTrackpadGestureType.pinchZoom, zoomDelta);

  const MapTrackpadGestureIntent.verticalZoom(double zoomDelta)
    : this._(MapTrackpadGestureType.verticalZoom, zoomDelta);

  final MapTrackpadGestureType type;
  final double zoomDelta;
}

MapTrackpadGestureIntent classifyMapTrackpadGesture({
  required Offset pan,
  required double scale,
}) {
  const scaleEpsilon = 0.25;
  const verticalPanDeadZone = 2.0;
  const pixelsPerZoomLevel = 200.0;

  if ((scale - 1).abs() > scaleEpsilon) {
    return MapTrackpadGestureIntent.pinchZoom(math.log(scale) / math.ln2);
  }

  if (pan.dy.abs() <= verticalPanDeadZone || pan.dy.abs() < pan.dx.abs()) {
    return const MapTrackpadGestureIntent.none();
  }

  return MapTrackpadGestureIntent.verticalZoom(pan.dy / pixelsPerZoomLevel);
}
