import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

import '../core/constants.dart';

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

  List<List<LatLng>> getSegmentsForZoom(int zoom) {
    final caches = decodeDisplayRoutePointsByZoom(displayRoutePointsByZoom);
    if (caches.isEmpty) {
      return gpxRoute.isEmpty ? const [] : [List<LatLng>.unmodifiable(gpxRoute)];
    }

    final clampedZoom = zoom.clamp(MapConstants.trackMinZoom, MapConstants.trackMaxZoom);
    final segments = caches[clampedZoom];
    if (segments == null || segments.isEmpty) {
      return gpxRoute.isEmpty ? const [] : [List<LatLng>.unmodifiable(gpxRoute)];
    }
    return segments;
  }

  static Map<int, List<List<LatLng>>> decodeDisplayRoutePointsByZoom(
    String jsonString,
  ) {
    if (jsonString.isEmpty || jsonString == '{}') {
      return const {};
    }

    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final caches = <int, List<List<LatLng>>>{};
    for (final entry in decoded.entries) {
      final zoom = int.tryParse(entry.key);
      if (zoom == null || entry.value is! List) {
        continue;
      }
      caches[zoom] = _decodeSegments(json.encode(entry.value));
    }
    return caches;
  }

  static List<List<LatLng>> _decodeSegments(String jsonString) {
    if (jsonString.isEmpty || jsonString == '[]') {
      return const [];
    }

    final dynamic decoded = json.decode(jsonString);
    if (decoded is! List) {
      return const [];
    }

    final segments = <List<LatLng>>[];
    for (final segment in decoded) {
      if (segment is! List) continue;
      final latLngs = <LatLng>[];
      for (final point in segment) {
        if (point is! List || point.length != 2) continue;
        final lat = (point[0] as num?)?.toDouble();
        final lng = (point[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          latLngs.add(LatLng(lat, lng));
        }
      }
      if (latLngs.isNotEmpty) {
        segments.add(latLngs);
      }
    }

    return segments;
  }
}
