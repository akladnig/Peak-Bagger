import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

import '../core/constants.dart';
import 'route_waypoint.dart';

@Entity()
class Route {
  @Id()
  int id;

  String name;

  String desc;

  @Transient()
  List<LatLng> gpxRoute;

  @Transient()
  List<int?> gpxRouteElevations;

  @Transient()
  List<RouteWaypoint> routeWaypoints;

  String displayRoutePointsByZoom;
  int colour;
  bool visible;
  double distance2d;
  double distance3d;
  double ascent;
  double descent;
  double startElevation;
  double endElevation;
  double lowestElevation;
  double highestElevation;
  int? estimatedTime;
  String? routeTimingProfileJson;

  @Transient()
  Map<int, List<List<LatLng>>>? _decodedDisplayRoutePointsByZoomCache;

  @Transient()
  String? _decodedDisplayRoutePointsByZoomSource;

  Route({
    this.id = 0,
    this.name = '',
    this.desc = '',
    List<LatLng>? gpxRoute,
    List<int?>? gpxRouteElevations,
    List<RouteWaypoint>? routeWaypoints,
    this.displayRoutePointsByZoom = '{}',
    this.colour = 0,
    this.visible = true,
    this.distance2d = 0,
    this.distance3d = 0,
    this.ascent = 0,
    this.descent = 0,
    this.startElevation = 0,
    this.endElevation = 0,
    this.lowestElevation = 0,
    this.highestElevation = 0,
    this.estimatedTime,
    this.routeTimingProfileJson,
  }) : gpxRoute = List<LatLng>.from(gpxRoute ?? const []),
       gpxRouteElevations = _normalizeElevations(
         pointCount: (gpxRoute ?? const <LatLng>[]).length,
         elevations: gpxRouteElevations,
       ),
       routeWaypoints = List<RouteWaypoint>.from(routeWaypoints ?? const []);

  String get gpxRouteJson => jsonEncode(
    List<List<num>>.generate(gpxRoute.length, (index) {
      final point = gpxRoute[index];
      final elevation = index < gpxRouteElevations.length
          ? gpxRouteElevations[index]
          : null;
      return elevation == null
          ? [point.latitude, point.longitude]
          : [point.latitude, point.longitude, elevation];
    }, growable: false),
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
    final elevations = <int?>[];
    for (final entry in decoded) {
      if (entry is! List || (entry.length != 2 && entry.length != 3)) {
        continue;
      }

      final lat = entry[0];
      final lng = entry[1];
      if (lat is! num || lng is! num) {
        continue;
      }

      points.add(LatLng(lat.toDouble(), lng.toDouble()));
      final rawElevation = entry.length == 3 ? entry[2] : null;
      elevations.add(rawElevation is num ? rawElevation.round() : null);
    }

    gpxRoute = points;
    gpxRouteElevations = _normalizeElevations(
      pointCount: points.length,
      elevations: elevations,
    );
  }

  String get routeWaypointsJson => jsonEncode(
    routeWaypoints.map((waypoint) => waypoint.toJson()).toList(growable: false),
  );

  set routeWaypointsJson(String value) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(value);
    } catch (_) {
      routeWaypoints = [];
      return;
    }

    if (decoded is! List) {
      routeWaypoints = [];
      return;
    }

    final waypoints = <RouteWaypoint>[];
    for (final entry in decoded) {
      final waypoint = RouteWaypoint.fromJson(entry);
      if (waypoint != null) {
        waypoints.add(waypoint);
      }
    }

    routeWaypoints = waypoints;
  }

  static List<int?> _normalizeElevations({
    required int pointCount,
    List<int?>? elevations,
  }) {
    if (pointCount == 0) {
      return const [];
    }
    if (elevations == null || elevations.isEmpty) {
      return List<int?>.filled(pointCount, null, growable: false);
    }

    return List<int?>.generate(
      pointCount,
      (index) => index < elevations.length ? elevations[index] : null,
      growable: false,
    );
  }

  List<List<LatLng>> getSegmentsForZoom(int zoom) {
    final caches = _displayRoutePointsCache();
    if (caches.isEmpty) {
      return gpxRoute.isEmpty
          ? const []
          : [List<LatLng>.unmodifiable(gpxRoute)];
    }

    final clampedZoom = zoom.clamp(
      MapConstants.trackMinZoom,
      MapConstants.trackMaxZoom,
    );
    final segments = caches[clampedZoom];
    if (segments == null || segments.isEmpty) {
      return gpxRoute.isEmpty
          ? const []
          : [List<LatLng>.unmodifiable(gpxRoute)];
    }
    return segments;
  }

  Map<int, List<List<LatLng>>> _displayRoutePointsCache() {
    if (_decodedDisplayRoutePointsByZoomSource == displayRoutePointsByZoom &&
        _decodedDisplayRoutePointsByZoomCache != null) {
      return _decodedDisplayRoutePointsByZoomCache!;
    }

    final caches = decodeDisplayRoutePointsByZoom(displayRoutePointsByZoom);
    _decodedDisplayRoutePointsByZoomSource = displayRoutePointsByZoom;
    _decodedDisplayRoutePointsByZoomCache = caches;
    return caches;
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
