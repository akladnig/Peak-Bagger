import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';

import 'drop_marker_robot.dart';

void main() {
  testWidgets('drop marker journey opens popup and drops marker', (
    tester,
  ) async {
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    final r = DropMarkerRobot(tester);

    await r.pumpMap(
      initialState: const MapState(
        center: LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      waypointsRepository: waypointsRepository,
    );

    await r.openDropMarkerPopup();
    expect(r.chooser, findsOneWidget);
    await r.chooseDropMarker();

    final marker = waypointsRepository.getCurrentMarker();
    expect(marker, isNotNull);
    expect(r.container().read(mapProvider).selectedLocation, isNotNull);
  });

  testWidgets(
    'drop marker journey saves favourite then goto remains camera only',
    (tester) async {
      final waypointsRepository = WaypointsRepository.test(
        InMemoryWaypointsStorage([
          Waypoints(
            id: 1,
            name: 'Existing Marker',
            type: Waypoints.typeMarker,
            latitude: -41.5,
            longitude: 146.5,
            mgrs: '55G EN 10000 10000',
          ),
        ]),
      );
      final r = DropMarkerRobot(tester);

      await r.pumpMap(
        initialState: const MapState(
          center: LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          selectedLocation: LatLng(-41.5, 146.5),
        ),
        waypointsRepository: waypointsRepository,
      );

      await r.tapMapCenter();
      await r.chooseDropFavourite('South Ridge');
      final favourite = waypointsRepository.getFavourites().last;
      expect(r.favouriteMarkerName(favourite.id), findsOneWidget);

      await r.openDropMarkerPopup();
      await r.chooseDropMarker();

      final currentMarker = r.container().read(mapProvider).selectedLocation;
      expect(currentMarker, isNotNull);

      await r.openFavourites();
      expect(r.favouritesPopup, findsOneWidget);
      await r.selectFavouriteRow(favourite.id);

      final state = r.container().read(mapProvider);
      expect(state.center.latitude, closeTo(favourite.latitude, 1e-9));
      expect(state.center.longitude, closeTo(favourite.longitude, 1e-9));
      expect(state.zoom, MapConstants.defaultZoom);
      expect(state.selectedLocation, currentMarker);
    },
  );
}
