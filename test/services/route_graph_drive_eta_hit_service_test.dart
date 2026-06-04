import 'dart:ui';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_drive_eta_hit_service.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

void main() {
  test('hitTest returns snapped qualifying way for nearby pointer', () {
    final service = RouteGraphDriveEtaHitService(_queryServiceWithRoad());
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );
    final pointer = camera.latLngToScreenOffset(const LatLng(-41.5, 146.5));

    final result = service.hitTest(
      pointerPosition: pointer,
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );

    expect(result.status, RouteGraphDriveEtaHitStatus.hit);
    expect(result.matchedWayId, 10);
    expect(result.wayName, 'Forestry Road');
    expect(result.snappedPoint!.latitude, closeTo(-41.5, 0.0001));
    expect(result.snappedPoint!.longitude, closeTo(146.5, 0.0001));
  });

  test('hitTest rejects far pointer misses', () {
    final service = RouteGraphDriveEtaHitService(_queryServiceWithRoad());
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );

    final result = service.hitTest(
      pointerPosition: const Offset(0, 0),
      camera: camera,
      tappedLocation: const LatLng(-41.4, 146.4),
    );

    expect(result.status, RouteGraphDriveEtaHitStatus.noHit);
  });

  test('hitTest still rejects pointer miss even when tapped location is on the road', () {
    final service = RouteGraphDriveEtaHitService(_queryServiceWithRoad());
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );

    final result = service.hitTest(
      pointerPosition: const Offset(0, 0),
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );

    expect(result.status, RouteGraphDriveEtaHitStatus.noHit);
  });

  test('hitTest returns noHit below drive ETA zoom gate', () {
    final service = RouteGraphDriveEtaHitService(_queryServiceWithRoad());
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 5,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );

    final result = service.hitTest(
      pointerPosition: const Offset(400, 300),
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );

    expect(result.status, RouteGraphDriveEtaHitStatus.noHit);
  });

  test('hitTest returns unavailable when no route graph chunks are visible', () {
    final service = RouteGraphDriveEtaHitService(
      RouteGraphQueryService(
        RouteGraphRepository.test(
          InMemoryRouteGraphStorage(
            manifest: RouteGraphManifest(
              activeGeneration: 1,
              readinessState: RouteGraphManifest.readinessReady,
            ),
            chunks: const [],
            wayIndexRows: const [],
          ),
        ),
      ),
    );
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );

    final result = service.hitTest(
      pointerPosition: const Offset(400, 300),
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );

    expect(result.status, RouteGraphDriveEtaHitStatus.unavailable);
  });

  test('hitTest reuses cached visible way geometry for identical viewport', () {
    final service = RouteGraphDriveEtaHitService(_queryServiceWithRoad());
    final camera = MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      rotation: 0,
      nonRotatedSize: const Size(800, 600),
    );
    final pointer = camera.latLngToScreenOffset(const LatLng(-41.5, 146.5));

    service.hitTest(
      pointerPosition: pointer,
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );
    final firstChunkKey = service.debugCachedVisibleChunkKey;
    final firstIdentity = service.debugCachedVisibleWaysIdentity;

    service.hitTest(
      pointerPosition: pointer,
      camera: camera,
      tappedLocation: const LatLng(-41.5, 146.5),
    );

    expect(service.debugCachedVisibleChunkKey, firstChunkKey);
    expect(identical(service.debugCachedVisibleWaysIdentity, firstIdentity), isTrue);
  });
}

RouteGraphQueryService _queryServiceWithRoad() {
  return RouteGraphQueryService(
    RouteGraphRepository.test(
      InMemoryRouteGraphStorage(
        manifest: RouteGraphManifest(
          activeGeneration: 1,
          readinessState: RouteGraphManifest.readinessReady,
        ),
        chunks: [
          RouteGraphChunk(
            recordKey: '1|0_0',
            chunkKey: '0_0',
            generation: 1,
            minLat: -42.0,
            minLon: 146.0,
            maxLat: -41.0,
            maxLon: 147.0,
            elementCount: 3,
            payloadJson:
                '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.49},{"type":"node","id":2,"lat":-41.5,"lon":146.51},{"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"service","name":"Forestry Road"}}]}',
          ),
        ],
        wayIndexRows: [
          RouteGraphWayIndex(
            recordKey: '1|0_0|10',
            generation: 1,
            chunkKey: '0_0',
            osmWayId: 10,
            highway: 'service',
            access: 'public',
            name: 'Forestry Road',
            normalizedName: 'forestry road',
            lengthMeters: 200,
            tagCount: 2,
            tagsJson: '{}',
          ),
        ],
      ),
    ),
  );
}
