import 'package:latlong2/latlong.dart';

class RouteElevationSummary {
  const RouteElevationSummary({
    required this.requestId,
    required this.geometryVersion,
    this.distance3d = 0,
    this.ascent = 0,
    this.descent = 0,
    this.startElevation = 0,
    this.endElevation = 0,
    this.lowestElevation = 0,
    this.highestElevation = 0,
  });

  const RouteElevationSummary.zero({
    required this.requestId,
    required this.geometryVersion,
  }) : distance3d = 0,
       ascent = 0,
       descent = 0,
       startElevation = 0,
       endElevation = 0,
       lowestElevation = 0,
       highestElevation = 0;

  final int requestId;
  final int geometryVersion;
  final double distance3d;
  final double ascent;
  final double descent;
  final double startElevation;
  final double endElevation;
  final double lowestElevation;
  final double highestElevation;
}

abstract interface class RouteElevationSampler {
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  });
}

class NoopRouteElevationSampler implements RouteElevationSampler {
  const NoopRouteElevationSampler();

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async {
    return RouteElevationSummary.zero(
      requestId: requestId,
      geometryVersion: geometryVersion,
    );
  }
}
