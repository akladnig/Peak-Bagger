import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/services/map_chart_hover_resolver.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  test('interpolates route hover by distance', () {
    final resolver = MapChartHoverResolver();
    final route = app_route.Route(
      id: 1,
      name: 'Ridge Walk',
      gpxRoute: const [
        LatLng(-41.5, 146.49),
        LatLng(-41.5, 146.51),
      ],
    );
    final totalDistance = const Distance().as(
      LengthUnit.Meter,
      route.gpxRoute.first,
      route.gpxRoute.last,
    );
    final hoverSample = ElevationProfileChartHoverSample(
      sampleIndex: 1,
      sample: const ElevationProfileSample(
        distanceMeters: 100,
        elevationMeters: 250,
      ),
      xValue: totalDistance / 2,
      axisMode: ElevationProfileAxisMode.distance,
    );

    expect(
      resolver.resolveRouteHover(route: route, hoverSample: hoverSample),
      const LatLng(-41.5, 146.5),
    );
  });

  test('interpolates track hover from repaired geometry first', () {
    final resolver = MapChartHoverResolver();
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx><trk><trkseg><trkpt lat="-41.1" lon="146.1" /></trkseg></trk></gpx>',
      gpxFileRepaired:
          '<gpx><trk><trkseg><trkpt lat="-41.5" lon="146.5" /><trkpt lat="-41.5" lon="146.7" /></trkseg></trk></gpx>',
    );
    final totalDistance = const Distance().as(
      LengthUnit.Meter,
      const LatLng(-41.5, 146.5),
      const LatLng(-41.5, 146.7),
    );
    final hoverSample = ElevationProfileChartHoverSample(
      sampleIndex: 0,
      sample: const ElevationProfileSample(
        distanceMeters: 0,
        elevationMeters: 250,
        segmentIndex: 0,
        pointIndex: 0,
      ),
      xValue: totalDistance / 2,
      axisMode: ElevationProfileAxisMode.distance,
    );

    expect(
      resolver.resolveTrackHover(track: track, hoverSample: hoverSample),
      const LatLng(-41.5, 146.6),
    );
  });

  test('returns null when track geometry is unavailable', () {
    final resolver = MapChartHoverResolver();
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Ridge Walk',
      gpxFile: '',
    );
    final hoverSample = ElevationProfileChartHoverSample(
      sampleIndex: 0,
      sample: const ElevationProfileSample(
        distanceMeters: 0,
        elevationMeters: 250,
      ),
      xValue: 0,
      axisMode: ElevationProfileAxisMode.distance,
    );

    expect(
      resolver.resolveTrackHover(track: track, hoverSample: hoverSample),
      isNull,
    );
  });
}
