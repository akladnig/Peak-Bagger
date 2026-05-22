import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';

import 'tr_export_robot.dart';

void main() {
  testWidgets('track export journey opens drawer and exports selection', (
    tester,
  ) async {
    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'hash',
      trackName: 'Robot Track',
      gpxFile: '<gpx><trk></trk></gpx>',
    );
    final robot = TrExportRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showTracks: true,
        tracks: [track],
      ),
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage([track])),
      routeRepository: RouteRepository.test(InMemoryRouteStorage()),
    );

    await robot.pumpApp();
    await robot.selectTrack(1);
    await robot.openTracksRoutesDrawer();

    robot.expectDrawerVisible();
    await robot.exportSelected();

    robot.expectExportWritten();
    robot.expectSnackbarContains('Exported to /fake/track/Robot-Track.gpx');
  });

  testWidgets('route export journey opens drawer and exports selection', (
    tester,
  ) async {
    final route = app_route.Route(
      id: 1,
      name: 'Robot Route',
      gpxRoute: const [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
    );
    final robot = TrExportRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        showRoutes: true,
      ),
      trackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      routeRepository: RouteRepository.test(InMemoryRouteStorage([route])),
    );

    await robot.pumpApp();
    await robot.selectRoute(1);
    await robot.openTracksRoutesDrawer();

    robot.expectDrawerVisible();
    await robot.exportSelected();

    robot.expectExportWritten();
    robot.expectSnackbarContains('Exported to /fake/route/Robot-Route.gpx');
  });
}
