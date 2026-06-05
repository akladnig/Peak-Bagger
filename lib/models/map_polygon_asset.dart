import 'package:latlong2/latlong.dart';

class MapPolygonAsset {
  const MapPolygonAsset({
    required this.assetPath,
    required this.name,
    required this.points,
  });

  final String assetPath;
  final String name;
  final List<LatLng> points;
}
