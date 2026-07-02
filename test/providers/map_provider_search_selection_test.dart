import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'selectMapFromSearch updates selected map location and focus serial',
    () async {
      final map = (await TestTasmapRepository.create()).getAllMaps().first;
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
        ),
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container
          .read(mapProvider.notifier)
          .selectMapFromSearch(
            map,
            selectedLocation: const LatLng(-43.0, 147.0),
          );

      final state = container.read(mapProvider);
      expect(state.selectedMap, same(map));
      expect(state.selectedLocation, const LatLng(-43.0, 147.0));
      expect(state.selectedMapFocusSerial, 1);
      expect(state.tasmapDisplayMode, TasmapDisplayMode.selectedMap);
    },
  );

  test(
    'showRoute keeps marker anchor while bumping route focus serial',
    () async {
      final routeRepository = RouteRepository.test(
        InMemoryRouteStorage([_route(2)]),
      );
      final notifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          showRoutes: true,
        ),
        routeRepository: routeRepository,
      );
      final container = ProviderContainer(
        overrides: [mapProvider.overrideWith(() => notifier)],
      );
      addTearDown(container.dispose);

      container
          .read(mapProvider.notifier)
          .showRoute(2, selectedLocation: const LatLng(-43.0, 147.0));

      final state = container.read(mapProvider);
      expect(state.selectedRouteId, 2);
      expect(state.selectedLocation, const LatLng(-43.0, 147.0));
      expect(state.selectedRouteFocusSerial, 1);
    },
  );

  test('updateSearchPopupQuery tracks typed query in generic state', () async {
    final tasmapRepository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: const [],
      ),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([_track(1, 'Alpha Track')]),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
      ],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).updateSearchPopupQuery('alpha');

    final state = container.read(mapProvider);
    expect(state.searchPopupQuery, 'alpha');
    expect(state.searchPopupResults, isNotEmpty);
  });

  test('openSearchPopup preselects the single visible region', () {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        visibleBounds: LatLngBounds(
          const LatLng(-43.01, 146.99),
          const LatLng(-42.99, 147.01),
        ),
      ),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    container.read(mapProvider.notifier).openSearchPopup();

    final state = container.read(mapProvider);
    expect(state.showPeakSearch, isTrue);
    expect(state.searchPopupRegionKey, 'tasmania');
  });
}

GpxTrack _track(int id, String name) {
  final segments = [
    [const LatLng(-43.0, 147.0), const LatLng(-43.001, 147.001)],
  ];
  return GpxTrack(
    gpxTrackId: id,
    contentHash: '$id',
    trackName: name,
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson(segments),
  );
}

Route _route(int id) {
  return Route(
    id: id,
    name: 'Route $id',
    gpxRoute: const [LatLng(-43.0, 147.0), LatLng(-43.001, 147.001)],
  );
}
