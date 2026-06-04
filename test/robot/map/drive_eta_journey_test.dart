import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

import 'drive_eta_robot.dart';

void main() {
  testWidgets('drive ETA journey shows loading then success', (tester) async {
    final robot = DriveEtaRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await robot.pumpApp();
    await robot.openMap();
    await robot.clickEtaTarget();

    robot.expectLoadingVisible();

    robot.completeRoute(distanceMeters: 12000, durationSeconds: 3900);
    await robot.pumpAfterAsync();

    robot.expectSuccessVisible();
  });

  testWidgets('drive ETA journey preserves existing selection state', (
    tester,
  ) async {
    final route = app_route.Route(id: 7, name: 'Saved Route');
    final track = GpxTrack(
      gpxTrackId: 9,
      contentHash: 'track',
      trackName: 'Track',
    );
    final initialLocation = const LatLng(-42.0, 146.0);
    final robot = DriveEtaRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: initialLocation,
        tracks: [track],
        showTracks: true,
        showRoutes: true,
        selectedTrackId: track.gpxTrackId,
        selectedRouteId: route.id,
      ),
      routeRepository: RouteRepository.test(InMemoryRouteStorage([route])),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([track]),
      ),
    );

    await robot.pumpApp();
    await robot.openMap();
    robot.expectSelectedLocation(initialLocation);
    robot.expectSelectedRoute(route.id);
    robot.expectSelectedTrack(track.gpxTrackId);

    await robot.clickEtaTarget();

    robot.expectLoadingVisible();
    robot.expectSelectedLocation(initialLocation);
    robot.expectSelectedRoute(route.id);
    robot.expectSelectedTrack(track.gpxTrackId);
  });
}
