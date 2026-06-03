import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  group('selected route contract', () {
    test(
      'hidden route is not selectable until showRoute restores it',
      () async {
        SharedPreferences.setMockInitialValues({'show_routes': true});
        final routeRepository = RouteRepository.test(
          InMemoryRouteStorage([_route(1), _route(2)]),
        );
        final tasmapRepository = await TestTasmapRepository.create();
        final container = ProviderContainer(
          overrides: [
            mapProvider.overrideWith(
              () => MapNotifier(
                peakRepository: PeakRepository.test(InMemoryPeakStorage()),
                overpassService: OverpassService(),
                tasmapRepository: tasmapRepository,
                gpxTrackRepository: GpxTrackRepository.test(
                  InMemoryGpxTrackStorage(),
                ),
                routeRepository: routeRepository,
                peaksBaggedRepository: PeaksBaggedRepository.test(
                  InMemoryPeaksBaggedStorage(),
                ),
                migrationMarkerStore: const MigrationMarkerStore(),
                loadPositionOnBuild: false,
                loadPeaksOnBuild: false,
                loadTracksOnBuild: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(mapProvider.notifier);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(mapProvider.notifier);
        notifier.setRouteVisibility(1, false);
        notifier.selectRoute(1);
        expect(container.read(mapProvider).selectedRouteId, isNull);

        final focusSerialBefore = container
            .read(mapProvider)
            .selectedRouteFocusSerial;
        notifier.showRoute(1);

        expect(container.read(mapProvider).selectedRouteId, 1);
        expect(routeRepository.findById(1)?.visible, isTrue);
        expect(
          container.read(mapProvider).selectedRouteFocusSerial,
          focusSerialBefore + 1,
        );
      },
    );

    test(
      'invalid selectRoute is no-op and visible selection clears track then bumps focus',
      () async {
        SharedPreferences.setMockInitialValues({'show_routes': true});
        final routeRepository = RouteRepository.test(
          InMemoryRouteStorage([_route(1), _route(2)]),
        );
        final notifier = TestMapNotifier(
          MapState(
            center: const LatLng(-41.5, 146.5),
            zoom: 15,
            basemap: Basemap.tracestrack,
            showRoutes: true,
            selectedTrackId: 1,
          ),
          routeRepository: routeRepository,
        );
        final container = ProviderContainer(
          overrides: [mapProvider.overrideWith(() => notifier)],
        );
        addTearDown(container.dispose);

        container.read(mapProvider);
        await Future<void>.delayed(Duration.zero);

        final mapNotifier = container.read(mapProvider.notifier);

        mapNotifier.selectRoute(999);
        expect(container.read(mapProvider).selectedRouteId, isNull);
        expect(container.read(mapProvider).selectedRouteFocusSerial, 0);

        mapNotifier.selectRoute(2);
        expect(container.read(mapProvider).selectedRouteId, 2);
        expect(container.read(mapProvider).selectedTrackId, isNull);
        expect(container.read(mapProvider).selectedRouteFocusSerial, 1);

        mapNotifier.selectRoute(2);
        expect(container.read(mapProvider).selectedRouteId, 2);
        expect(container.read(mapProvider).selectedRouteFocusSerial, 2);
      },
    );

    test('reconcileSelectedRouteState clears stale selected id', () async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final routeRepository = RouteRepository.test(
        InMemoryRouteStorage([_route(1)]),
      );
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
          selectedRouteId: 999,
        ),
        routeRepository: routeRepository,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      container.read(mapProvider.notifier).reconcileSelectedRouteState();

      expect(container.read(mapProvider).selectedRouteId, isNull);
    });

    test('setShowRoutes(false) clears selected route and hover', () async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final routeRepository = RouteRepository.test(
        InMemoryRouteStorage([_route(1)]),
      );
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
          hoveredRouteId: 1,
          selectedRouteId: 1,
        ),
        routeRepository: routeRepository,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      container.read(mapProvider.notifier).setShowRoutes(false);

      expect(container.read(mapProvider).selectedRouteId, isNull);
      expect(container.read(mapProvider).hoveredRouteId, isNull);
    });

    test('showRoute selects visible route and bumps focus serial', () async {
      SharedPreferences.setMockInitialValues({'show_routes': true});
      final routeRepository = RouteRepository.test(
        InMemoryRouteStorage([_route(1), _route(2)]),
      );
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
          selectedTrackId: 7,
        ),
        routeRepository: routeRepository,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container.read(mapProvider);
      await Future<void>.delayed(Duration.zero);

      final focusSerialBefore = container
          .read(mapProvider)
          .selectedRouteFocusSerial;

      container.read(mapProvider.notifier).showRoute(2);

      expect(container.read(mapProvider).selectedRouteId, 2);
      expect(container.read(mapProvider).selectedTrackId, isNull);
      expect(
        container.read(mapProvider).selectedRouteFocusSerial,
        focusSerialBefore + 1,
      );
    });
  });
}

Route _route(int id) {
  return _routeWithVisibility(id, visible: true);
}

Route _routeWithVisibility(int id, {required bool visible}) {
  return Route(
    id: id,
    name: 'Route $id',
    visible: visible,
    gpxRoute: [const LatLng(-41.5, 146.49), const LatLng(-41.5, 146.51)],
  );
}
