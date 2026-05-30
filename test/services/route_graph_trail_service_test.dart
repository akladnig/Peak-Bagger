import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_trail_service.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  test('buildVisibleTrails decodes route-graph trail geometry', () {
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
            elementCount: 3,
            payloadJson: '''
              {"elements":[
                {"type":"node","id":1,"lat":-41.5,"lon":146.5},
                {"type":"node","id":2,"lat":-41.6,"lon":146.6},
                {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}
              ]}
            ''',
          ),
        ],
        wayIndexRows: [
          RouteGraphWayIndex(
            recordKey: '1|0_0|10',
            generation: 1,
            chunkKey: '0_0',
            osmWayId: 10,
            highway: 'path',
            lengthMeters: 120,
            tagCount: 1,
            tagsJson: '{}',
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
  });

  test('buildVisibleTrails returns nothing when no trail rows match', () {
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
            elementCount: 1,
            payloadJson: '{"elements":[]}',
          ),
        ],
        wayIndexRows: const [],
      ),
    );

    final service = RouteGraphTrailService(RouteGraphQueryService(repository));
    final trails = service.buildVisibleTrails(
      minLat: -42,
      minLon: 146,
      maxLat: -41,
      maxLon: 147,
    );

    expect(trails, isEmpty);
  });
}
