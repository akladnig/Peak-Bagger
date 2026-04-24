import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class GeoAreas {
  GeoAreas._();

  static final tasmaniaBounds = LatLngBounds(
    const LatLng(-43.643, 143.833),
    const LatLng(-39.579, 148.482),
  );
}
