import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_trail_service.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  test(
    'buildVisibleTrails reads cached trail geometry and dedupes overlap',
    () {
      final repository = RouteGraphRepository.test(
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
              minLat: -42,
              minLon: 146,
              maxLat: -41,
              maxLon: 147,
              elementCount: 0,
              payloadJson: '{"elements":[]}',
            ),
            RouteGraphChunk(
              recordKey: '1|0_1',
              chunkKey: '0_1',
              generation: 1,
              minLat: -42,
              minLon: 146,
              maxLat: -41,
              maxLon: 147,
              elementCount: 0,
              payloadJson: '{"elements":[]}',
            ),
          ],
          trailDisplayChunks: [
            RouteGraphTrailDisplayChunk(
              recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
                generation: 1,
                cacheZoom: 15,
                chunkKey: '0_0',
              ),
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
              payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
                const RouteGraphTrailDisplayWay(
                  osmWayId: 10,
                  points: [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
                ),
              ]),
            ),
            RouteGraphTrailDisplayChunk(
              recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
                generation: 1,
                cacheZoom: 15,
                chunkKey: '0_1',
              ),
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_1',
              payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
                const RouteGraphTrailDisplayWay(
                  osmWayId: 10,
                  points: [LatLng(-41.5, 146.5), LatLng(-41.6, 146.6)],
                ),
              ]),
            ),
          ],
        ),
      );

      final service = RouteGraphTrailService(
        RouteGraphQueryService(repository),
      );
      final trails = service.buildVisibleTrails(
        minLat: -42,
        minLon: 146,
        maxLat: -41,
        maxLon: 147,
        zoom: 15,
      );

      expect(trails, hasLength(2));
      expect(trails[0].points, [
        const LatLng(-41.5, 146.5),
        const LatLng(-41.6, 146.6),
      ]);
      expect(trails[0].color, TrailDisplayTheme.baseColor);
      expect(trails[0].pattern, const StrokePattern.solid());
      expect(trails[1].color, TrailDisplayTheme.overlayColor);
      expect(
        trails[1].pattern,
        StrokePattern.dashed(segments: TrailDisplayTheme.overlayDashSegments),
      );
    },
  );

  test('buildVisibleTrails returns nothing when no trail rows match', () {
    final repository = RouteGraphRepository.test(
      InMemoryRouteGraphStorage(
        manifest: RouteGraphManifest(
          activeGeneration: 1,
          readinessState: RouteGraphManifest.readinessReady,
        ),
        chunks: const [],
        wayIndexRows: const [],
      ),
    );

    final service = RouteGraphTrailService(RouteGraphQueryService(repository));
    final trails = service.buildVisibleTrails(
      minLat: -42,
      minLon: 146,
      maxLat: -41,
      maxLon: 147,
      zoom: 15,
    );

    expect(trails, isEmpty);
  });

  test('buildVisibleTrails fails closed when a cache row is malformed', () {
    final repository = RouteGraphRepository.test(
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
            minLat: -42,
            minLon: 146,
            maxLat: -41,
            maxLon: 147,
            elementCount: 0,
            payloadJson: '{"elements":[]}',
          ),
        ],
        trailDisplayChunks: [
          RouteGraphTrailDisplayChunk(
            recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
            ),
            generation: 1,
            cacheZoom: 15,
            chunkKey: '0_0',
            payloadJson: '{"bad":"payload"}',
          ),
        ],
      ),
    );

    final service = RouteGraphTrailService(RouteGraphQueryService(repository));
    final trails = service.buildVisibleTrails(
      minLat: -42,
      minLon: 146,
      maxLat: -41,
      maxLon: 147,
      zoom: 15,
    );

    expect(trails, isEmpty);
  });
}
