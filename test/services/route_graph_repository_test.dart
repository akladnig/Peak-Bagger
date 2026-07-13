import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test(
    'writePreparedGeneration activates new generation and prunes stale chunks',
    () async {
      final storage = InMemoryRouteGraphStorage(
        manifest: RouteGraphManifest(
          sourceHash: 'old',
          schemaVersion: 'route-graph-v1',
          activeGeneration: 1,
          importedAt: DateTime.utc(2024),
          chunkCount: 1,
          nodeCount: 1,
          edgeCount: 1,
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
            payloadJson: '{"elements": []}',
          ),
        ],
        wayIndexRows: [
          RouteGraphWayIndex(
            recordKey: RouteGraphWayIndex.recordKeyFor(
              generation: 1,
              chunkKey: '0_0',
              osmWayId: 10,
            ),
            generation: 1,
            chunkKey: '0_0',
            osmWayId: 10,
            lengthMeters: 10,
            tagCount: 1,
            tagsJson: '{"highway":"path"}',
          ),
        ],
        trailDisplayChunks: [
          _trailDisplayChunk(generation: 1, cacheZoom: 15, chunkKey: '0_0'),
        ],
      );
      final repository = RouteGraphRepository.test(storage);

      await repository.writePreparedGeneration(
        RouteGraphPreparedGeneration(
          generation: 2,
          sourceHash: 'new',
          schemaVersion: 'route-graph-v1',
          importedAt: DateTime.utc(2025),
          chunkCount: 1,
          nodeCount: 2,
          edgeCount: 1,
          chunks: [
            RouteGraphChunk(
              recordKey: '2|1_1',
              chunkKey: '1_1',
              generation: 2,
              minLat: -42,
              minLon: 146,
              maxLat: -41,
              maxLon: 147,
              elementCount: 3,
              payloadJson: '{"elements": []}',
            ),
          ],
          wayIndexRows: [
            RouteGraphWayIndex(
              recordKey: RouteGraphWayIndex.recordKeyFor(
                generation: 2,
                chunkKey: '1_1',
                osmWayId: 11,
              ),
              generation: 2,
              chunkKey: '1_1',
              osmWayId: 11,
              lengthMeters: 11,
              tagCount: 2,
              tagsJson: '{"highway":"path"}',
            ),
          ],
          trailDisplayChunks: [
            _trailDisplayChunk(generation: 2, cacheZoom: 15, chunkKey: '1_1'),
          ],
        ),
        pruneStaleGenerations: true,
      );

      expect(repository.manifest?.activeGeneration, 2);
      expect(
        repository.manifest?.readinessState,
        RouteGraphManifest.readinessReady,
      );
      expect(repository.activeChunks(), hasLength(1));
      expect(repository.activeChunks().single.generation, 2);
      expect(repository.activeWayIndexRows(), hasLength(1));
      expect(repository.activeWayIndexRows().single.generation, 2);
      expect(repository.activeTrailDisplayChunks(), hasLength(1));
      expect(repository.activeTrailDisplayChunks().single.generation, 2);
    },
  );

  test('writePreparedGeneration prunes stale trail display rows', () async {
    final storage = InMemoryRouteGraphStorage(
      manifest: RouteGraphManifest(
        sourceHash: 'old',
        schemaVersion: 'route-graph-v2',
        activeGeneration: 1,
        importedAt: DateTime.utc(2024),
        chunkCount: 1,
        nodeCount: 1,
        edgeCount: 1,
        readinessState: RouteGraphManifest.readinessReady,
      ),
      trailDisplayChunks: [
        _trailDisplayChunk(generation: 1, cacheZoom: 15, chunkKey: '0_0'),
      ],
    );
    final repository = RouteGraphRepository.test(storage);

    await repository.writePreparedGeneration(
      RouteGraphPreparedGeneration(
        generation: 2,
        sourceHash: 'new',
        schemaVersion: 'route-graph-v2',
        importedAt: DateTime.utc(2025),
        chunkCount: 1,
        nodeCount: 2,
        edgeCount: 1,
        chunks: const [],
        wayIndexRows: const [],
        trailDisplayChunks: [
          _trailDisplayChunk(generation: 2, cacheZoom: 15, chunkKey: '1_1'),
        ],
      ),
      pruneStaleGenerations: true,
    );

    await storage.replaceGeneration(
      manifest: RouteGraphManifest(
        sourceHash: 'old',
        schemaVersion: 'route-graph-v2',
        activeGeneration: 1,
        importedAt: DateTime.utc(2024),
        chunkCount: 0,
        nodeCount: 0,
        edgeCount: 0,
        readinessState: RouteGraphManifest.readinessReady,
      ),
      chunks: const [],
      wayIndexRows: const [],
      trailDisplayChunks: const [],
      pruneStaleGenerations: false,
    );

    expect(storage.activeTrailDisplayChunks(), isEmpty);
  });

  test('buildTripServiceForActiveGeneration loads active payloads', () async {
    final storage = InMemoryRouteGraphStorage(
      manifest: RouteGraphManifest(
        sourceHash: 'hash',
        schemaVersion: 'route-graph-v1',
        activeGeneration: 7,
        importedAt: DateTime.utc(2025),
        chunkCount: 1,
        nodeCount: 2,
        edgeCount: 1,
        readinessState: RouteGraphManifest.readinessReady,
      ),
      chunks: [
        RouteGraphChunk(
          recordKey: '7|0_0',
          chunkKey: '0_0',
          generation: 7,
          minLat: -42,
          minLon: 146,
          maxLat: -41,
          maxLon: 147,
          elementCount: 3,
          payloadJson: '''
          {"elements":[
            {"type":"node","id":1,"lat":-42.0,"lon":146.0},
            {"type":"node","id":2,"lat":-42.01,"lon":146.01},
            {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}
          ]}
          ''',
        ),
      ],
      wayIndexRows: [
        RouteGraphWayIndex(
          recordKey: RouteGraphWayIndex.recordKeyFor(
            generation: 7,
            chunkKey: '0_0',
            osmWayId: 10,
          ),
          generation: 7,
          chunkKey: '0_0',
          osmWayId: 10,
          lengthMeters: 10,
          tagCount: 1,
          tagsJson: '{"highway":"path"}',
        ),
      ],
    );
    final repository = RouteGraphRepository.test(storage);

    final service = await repository.buildTripServiceForActiveGeneration();

    expect(service, isA<trip_routing.TripService>());
  });
}

RouteGraphTrailDisplayChunk _trailDisplayChunk({
  required int generation,
  required int cacheZoom,
  required String chunkKey,
}) {
  return RouteGraphTrailDisplayChunk(
    recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
      generation: generation,
      cacheZoom: cacheZoom,
      chunkKey: chunkKey,
    ),
    generation: generation,
    cacheZoom: cacheZoom,
    chunkKey: chunkKey,
    payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
      const RouteGraphTrailDisplayWay(
        osmWayId: 10,
        points: [LatLng(-42.0, 146.0), LatLng(-42.01, 146.01)],
      ),
    ]),
  );
}
