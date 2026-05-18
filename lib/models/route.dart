import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Route {
  @Id()
  int id;

  String name;

  @Transient()
  List<LatLng> gpxRoute;

  String displayRoutePointsByZoom;
  int colour;
  double distance2d;
  double distance3d;
  double ascent;
  double descent;
  double startElevation;
  double endElevation;
  double lowestElevation;
  double highestElevation;

  Route({
    this.id = 0,
    this.name = '',
    List<LatLng>? gpxRoute,
    this.displayRoutePointsByZoom = '{}',
    this.colour = 0,
    this.distance2d = 0,
    this.distance3d = 0,
    this.ascent = 0,
    this.descent = 0,
    this.startElevation = 0,
    this.endElevation = 0,
    this.lowestElevation = 0,
    this.highestElevation = 0,
  }) : gpxRoute = List<LatLng>.from(gpxRoute ?? const []);

  String get gpxRouteJson => jsonEncode(
    gpxRoute
        .map((point) => [point.latitude, point.longitude])
        .toList(growable: false),
  );

  set gpxRouteJson(String value) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      gpxRoute = [];
      return;
    }

    if (decoded is! List) {
      gpxRoute = [];
      return;
    }

    final points = <LatLng>[];
    for (final entry in decoded) {
      if (entry is! List || entry.length != 2) {
        continue;
      }

      final lat = entry[0];
      final lng = entry[1];
      if (lat is! num || lng is! num) {
        continue;
      }

      points.add(LatLng(lat.toDouble(), lng.toDouble()));
    }

    gpxRoute = points;
  }
}
