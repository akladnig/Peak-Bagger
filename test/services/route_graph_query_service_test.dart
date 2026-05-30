import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/services/route_graph_query_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';

void main() {
  test('queryChunksForRoute selects intersecting chunks only', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [
            _chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0),
            _chunk('1|2_2', '2_2', -35.0, 140.0, -34.0, 141.0),
            _chunk('1|3_3', '3_3', -36.0, 141.0, -35.0, 142.0),
          ],
        ),
      ),
    );

    final chunks = service.queryChunksForRoute(
      start: const LatLng(-41.5, 146.5),
      end: const LatLng(-41.6, 146.6),
    );

    expect(chunks, hasLength(1));
    expect(chunks.single.chunkKey, '0_0');
  });

  test('queryMergedPayloadsForRoute deduplicates overlapping OSM elements', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [
            _chunk(
              '1|0_0',
              '0_0',
              -42.0,
              146.0,
              -41.0,
              147.0,
              payloadJson: _payload,
            ),
            _chunk(
              '1|0_1',
              '0_1',
              -42.0,
              146.0,
              -41.0,
              147.0,
              payloadJson: _payload,
            ),
          ],
        ),
      ),
    );

    final payloads = service.queryMergedPayloadsForRoute(
      start: const LatLng(-41.5, 146.5),
      end: const LatLng(-41.6, 146.6),
    );

    expect(payloads, hasLength(1));
    final elements = payloads.single['elements'] as List;
    expect(elements, hasLength(3));
    expect(
      elements.map((element) => '${element['type']}:${element['id']}').toSet(),
      hasLength(3),
    );
  });

  test('prefetchBounds is a safe visible-area warmup entrypoint', () async {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [_chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0)],
        ),
      ),
    );

    await service.prefetchBounds(
      minLat: -41.8,
      minLon: 146.2,
      maxLat: -41.2,
      maxLon: 146.8,
    );
  });
}

final _manifest = RouteGraphManifest(
  sourceHash: 'hash',
  schemaVersion: 'route-graph-v1',
  activeGeneration: 1,
  importedAt: DateTime.utc(2025),
  chunkCount: 2,
  nodeCount: 2,
  edgeCount: 1,
  readinessState: RouteGraphManifest.readinessReady,
);

RouteGraphChunk _chunk(
  String recordKey,
  String chunkKey,
  double minLat,
  double minLon,
  double maxLat,
  double maxLon, {
  String payloadJson = _payload,
}) {
  return RouteGraphChunk(
    recordKey: recordKey,
    chunkKey: chunkKey,
    generation: 1,
    minLat: minLat,
    minLon: minLon,
    maxLat: maxLat,
    maxLon: maxLon,
    elementCount: 3,
    payloadJson: payloadJson,
  );
}

const _payload = '''
{"elements":[
  {"type":"node","id":1,"lat":-41.5,"lon":146.5},
  {"type":"node","id":2,"lat":-41.6,"lon":146.6},
  {"type":"way","id":10,"nodes":[1,2],"tags":{"highway":"path"}}
]}
''';
