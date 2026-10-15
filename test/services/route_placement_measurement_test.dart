import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_placement_measurement.dart';

void main() {
  test('ordinary start feedback qualifies without any segment sampling', () {
    final placement = RoutePlacementMeasurement(
      mode: RouteMode.snapToTrail,
      ordinaryStart: true,
      beforeDistanceMeters: 0,
      beforeGeometryVersion: 0,
    );
    const point = LatLng(-41.5, 146.5);
    const state = MapState(
      center: point,
      zoom: 10,
      basemap: Basemap.tracestrack,
      isRouteDrafting: true,
      routeDraftStage: RouteDraftStage.awaitingNextPoint,
      routeDraftControlEndpoints: [
        RouteDraftControlEndpoint(
          id: '1',
          point: point,
          kind: RouteDraftEndpointKind.tapped,
        ),
      ],
    );
    expect(placement.isComplete(state), isTrue);
    expect(state.routeDraftCommittedPoints, isEmpty);
    expect(state.routeDraftElevationSummary, isNull);
    expect(
      placement.isComplete(state.copyWith(isRouteDrafting: false)),
      isFalse,
    );
  });
  test(
    'committed geometry with old statistics is not a complete placement',
    () {
      final placement = RoutePlacementMeasurement(
        mode: RouteMode.snapToTrail,
        ordinaryStart: false,
        beforeDistanceMeters: 0,
        beforeGeometryVersion: 1,
      );
      const geometry = [LatLng(-41.5, 146.5), LatLng(-41.51, 146.51)];
      final state = MapState(
        center: geometry.first,
        zoom: 10,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftCommittedPoints: geometry,
        routeDraftGeometryVersion: 2,
        routeDraftElevationRequestId: 2,
        routeDraftElevationSummary: const RouteElevationSummary.zero(
          requestId: 1,
          geometryVersion: 1,
        ),
        routeDraftPointElevations: const [100, 120],
      );
      expect(placement.isComplete(state), isFalse);
      expect(
        placement.isComplete(
          state.copyWith(
            routeDraftElevationSummary: const RouteElevationSummary(
              requestId: 2,
              geometryVersion: 2,
              ascent: 20,
            ),
          ),
        ),
        isTrue,
      );
    },
  );
}
