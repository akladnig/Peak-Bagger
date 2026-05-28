import 'package:latlong2/latlong.dart';

enum GpxPointSourceKind { track, route }

class GpxPointSample {
  const GpxPointSample({
    required this.lat,
    required this.lon,
    required this.sourceKind,
    this.ele,
    this.time,
  });

  final double lat;
  final double lon;
  final double? ele;
  final DateTime? time;
  final GpxPointSourceKind sourceKind;

  LatLng get location => LatLng(lat, lon);

  GpxPointSample copyWith({
    double? lat,
    double? lon,
    double? ele,
    DateTime? time,
    GpxPointSourceKind? sourceKind,
  }) {
    return GpxPointSample(
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      ele: ele ?? this.ele,
      time: time ?? this.time,
      sourceKind: sourceKind ?? this.sourceKind,
    );
  }
}
