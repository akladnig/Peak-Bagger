import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/services/route_admin_editor.dart';
import 'package:peak_bagger/services/route_timing_service.dart';

void main() {
  test('validateAndBuild preserves route geometry while updating metadata', () {
    final source = Route(
      id: 7,
      name: 'Original Route',
      desc: 'Original description',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
      gpxRouteElevations: const [123, 456],
      routeWaypoints: const [
        RouteWaypoint(
          latitude: -41.6,
          longitude: 146.6,
          label: 'Waypoint 1',
          sequence: 1,
          isPeakDerived: false,
        ),
      ],
      displayRoutePointsByZoom: '{"10":[[[ -41.5,146.5 ],[ -41.6,146.6 ]]]}',
      colour: 1,
      distance2d: 10,
      distance3d: 11,
      ascent: 12,
      descent: 13,
      startElevation: 14,
      endElevation: 15,
      lowestElevation: 16,
      highestElevation: 17,
      walkingSpeedKmh: 4.4,
    );

    final result = RouteAdminEditor.validateAndBuild(
      source: source,
      form: const RouteAdminFormState(
        name: 'Updated Route',
        desc: 'Updated description',
        visible: false,
        colour: '0x00000002',
        distance2d: '20.5',
        distance3d: '21.5',
        ascent: '22',
        descent: '23',
        startElevation: '24',
        endElevation: '25',
        lowestElevation: '26',
        highestElevation: '27',
      ),
    );

    expect(result.isValid, isTrue);
    expect(result.route, isNotNull);
    expect(result.route!.id, 7);
    expect(result.route!.name, 'Updated Route');
    expect(result.route!.desc, 'Updated description');
    expect(result.route!.visible, isFalse);
    expect(result.route!.colour, 2);
    expect(result.route!.distance2d, 20.5);
    expect(result.route!.distance3d, 21.5);
    expect(result.route!.ascent, 22);
    expect(result.route!.descent, 23);
    expect(result.route!.startElevation, 24);
    expect(result.route!.endElevation, 25);
    expect(result.route!.lowestElevation, 26);
    expect(result.route!.highestElevation, 27);
    expect(result.route!.gpxRoute, source.gpxRoute);
    expect(result.route!.gpxRouteElevations, source.gpxRouteElevations);
    expect(result.route!.routeWaypoints, source.routeWaypoints);
    expect(
      result.route!.displayRoutePointsByZoom,
      source.displayRoutePointsByZoom,
    );
    final expectedProfile = buildNaismithProfile(
      points: source.gpxRoute,
      elevations: source.gpxRouteElevations,
    );
    expect(
      result.route!.routeTimingProfileJson,
      encodeRouteTimingProfile(expectedProfile),
    );
    expect(
      result.route!.estimatedTime,
      profileDurationSeconds(expectedProfile) * 1000,
    );
    expect(result.route!.routeTimingSource, RouteTimingSources.naismith);
    expect(result.route!.walkingSpeedKmh, 4.4);
    expect(
      result.route!.routeTimingSegmentKindsJson,
      '["${RouteTimingSegmentKinds.manualEstimated}"]',
    );
    expect(RouteAdminEditor.normalize(source).colour, '0x00000001');
  });
}
