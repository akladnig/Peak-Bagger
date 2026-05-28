import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import '../harness/test_map_notifier.dart';

void main() {
  test('route draft hover state sets, clears, and resets on draft lifecycle', () async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        hoveredRouteId: 9,
        hoveredRouteDraftMarkerId: 'stale',
      ),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    container.read(mapProvider);
    await Future<void>.delayed(Duration.zero);

    final mapNotifier = container.read(mapProvider.notifier);

    mapNotifier.beginRouteDraft();
    expect(container.read(mapProvider).hoveredRouteId, isNull);
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);

    mapNotifier.setHoveredRouteDraftMarkerId('marker-1');
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, 'marker-1');

    mapNotifier.clearHoveredRouteDraftMarker('marker-2');
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, 'marker-1');

    mapNotifier.clearHoveredRouteDraftMarker('marker-1');
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);

    mapNotifier.setHoveredRouteDraftMarkerId('marker-2');
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, 'marker-2');

    mapNotifier.endRouteDraft();
    expect(container.read(mapProvider).hoveredRouteDraftMarkerId, isNull);
  });

  test('route draft preview inserts into the ordered chain and clears hover', () {
    const a = LatLng(-41.5, 146.5);
    const b = LatLng(-41.51, 146.51);
    const c = LatLng(-41.52, 146.52);
    const preview = LatLng(-41.505, 146.505);

    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftNextMarkerId: 3,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(id: '0', point: a, kind: RouteDraftEndpointKind.tapped),
          RouteDraftControlEndpoint(id: '1', point: b, kind: RouteDraftEndpointKind.tapped),
          RouteDraftControlEndpoint(id: '2', point: c, kind: RouteDraftEndpointKind.tapped),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(
            id: '0',
            point: a,
            kind: RouteMarkerKind.circle,
          ),
          RouteDraftDisplayMarker(
            id: '1',
            point: b,
            kind: RouteMarkerKind.numbered,
            number: 1,
          ),
          RouteDraftDisplayMarker(
            id: '2',
            point: c,
            kind: RouteMarkerKind.target,
          ),
        ],
        routeDraftMarkers: const [a, b, c],
        routeDraftCommittedPoints: const [a, b, c],
        routeDraftProvisionalPoints: const [],
      ),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    final mapNotifier = container.read(mapProvider.notifier);
    mapNotifier.setHoveredRouteDraftSegmentPreview(
      segmentIndex: 0,
      committedSegmentIndex: 0,
      point: preview,
    );

    expect(container.read(mapProvider).hoveredRouteDraftSegmentIndex, 0);
    expect(container.read(mapProvider).hoveredRouteDraftCommittedSegmentIndex, 0);
    expect(container.read(mapProvider).hoveredRouteDraftSegmentPoint, preview);

    mapNotifier.commitHoveredRouteDraftSegmentPreview();

    final state = container.read(mapProvider);
    expect(state.hoveredRouteDraftSegmentIndex, isNull);
    expect(state.hoveredRouteDraftSegmentPoint, isNull);
    expect(state.routeDraftControlEndpoints.map((e) => e.point), [a, preview, b, c]);
    expect(state.routeDraftCommittedPoints, [a, preview, b, c]);
    expect(state.routeDraftDisplayMarkers[0].kind, RouteMarkerKind.circle);
    expect(state.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.numbered);
    expect(state.routeDraftDisplayMarkers[1].number, 1);
    expect(state.routeDraftDisplayMarkers[2].kind, RouteMarkerKind.numbered);
    expect(state.routeDraftDisplayMarkers[2].number, 2);
    expect(state.routeDraftDisplayMarkers[3].kind, RouteMarkerKind.target);
  });

  test('route draft preview inserts into the hovered committed segment', () {
    const a = LatLng(-41.5, 146.47);
    const b = LatLng(-41.49, 146.5);
    const c = LatLng(-41.5, 146.53);
    const preview = LatLng(-41.495, 146.515);

    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        isRouteDrafting: true,
        routeDraftStage: RouteDraftStage.awaitingNextPoint,
        routeDraftNextMarkerId: 2,
        routeDraftControlEndpoints: const [
          RouteDraftControlEndpoint(id: '0', point: a, kind: RouteDraftEndpointKind.tapped),
          RouteDraftControlEndpoint(id: '1', point: c, kind: RouteDraftEndpointKind.tapped),
        ],
        routeDraftDisplayMarkers: const [
          RouteDraftDisplayMarker(id: '0', point: a, kind: RouteMarkerKind.circle),
          RouteDraftDisplayMarker(id: '1', point: c, kind: RouteMarkerKind.target),
        ],
        routeDraftMarkers: const [a, c],
        routeDraftCommittedPoints: const [a, b, c],
        routeDraftProvisionalPoints: const [],
      ),
    );
    final container = ProviderContainer(
      overrides: [mapProvider.overrideWith(() => notifier)],
    );
    addTearDown(container.dispose);

    final mapNotifier = container.read(mapProvider.notifier);
    mapNotifier.setHoveredRouteDraftSegmentPreview(
      segmentIndex: 0,
      committedSegmentIndex: 1,
      point: preview,
    );

    mapNotifier.commitHoveredRouteDraftSegmentPreview();

    final state = container.read(mapProvider);
    expect(state.routeDraftControlEndpoints.map((e) => e.point), [a, preview, c]);
    expect(state.routeDraftCommittedPoints, [a, b, preview, c]);
    expect(state.routeDraftDisplayMarkers[0].kind, RouteMarkerKind.circle);
    expect(state.routeDraftDisplayMarkers[1].kind, RouteMarkerKind.numbered);
    expect(state.routeDraftDisplayMarkers[1].number, 1);
    expect(state.routeDraftDisplayMarkers[2].kind, RouteMarkerKind.target);
  });
}
