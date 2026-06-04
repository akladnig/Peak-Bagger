import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/models/route_graph_way_index.dart';
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

  test('queryWays selects matching indexed ways before chunk resolution', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [_chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0)],
          wayIndexRows: [
            _wayRow(
              recordKey: '1|0_0|10',
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'footway',
              access: 'public',
              name: 'Tassy Paths',
              normalizedName: 'tassy paths',
              lengthMeters: 600,
              tagCount: 7,
            ),
            _wayRow(
              recordKey: '1|0_1|11',
              chunkKey: '0_1',
              osmWayId: 11,
              highway: 'path',
              access: 'private',
              name: 'Private Spur',
              normalizedName: 'private spur',
              lengthMeters: 200,
              tagCount: 2,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryWays(
      RouteGraphWayQuery(
        include: const [TagFilter(key: 'highway', value: 'footway')],
        exclude: const [TagFilter(key: 'access', value: 'private')],
        nameContains: 'tassy',
        minLengthMeters: 500,
        maxLengthMeters: 1000,
        minTagCount: 5,
      ),
    );

    expect(rows, hasLength(1));
    expect(rows.single.chunkKey, '0_0');
    expect(rows.single.osmWayId, 10);
  });

  test('queryTrailWays applies the exact trail source filter', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          wayIndexRows: [
            _wayRow(
              recordKey: '1|0_0|10',
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'path',
              access: 'public',
              name: 'Trail',
              normalizedName: 'trail',
              lengthMeters: 600,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|11',
              chunkKey: '0_0',
              osmWayId: 11,
              highway: 'footway',
              access: 'public',
              surface: 'gravel',
              name: 'Long Footway',
              normalizedName: 'long footway',
              lengthMeters: 501,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|12',
              chunkKey: '0_0',
              osmWayId: 12,
              highway: 'footway',
              access: 'public',
              name: 'Short Footway',
              normalizedName: 'short footway',
              lengthMeters: 500,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|13',
              chunkKey: '0_0',
              osmWayId: 13,
              highway: 'path',
              access: 'private',
              name: 'Private Path',
              normalizedName: 'private path',
              lengthMeters: 800,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|14',
              chunkKey: '0_0',
              osmWayId: 14,
              highway: 'path',
              access: 'public',
              surface: 'concrete',
              name: 'Concrete Path',
              normalizedName: 'concrete path',
              lengthMeters: 800,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|15',
              chunkKey: '0_0',
              osmWayId: 15,
              highway: 'path',
              access: 'public',
              footway: 'sidewalk',
              name: 'Sidewalk Path',
              normalizedName: 'sidewalk path',
              lengthMeters: 800,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|16',
              chunkKey: '0_0',
              osmWayId: 16,
              highway: 'path',
              access: 'public',
              foot: 'no',
              name: 'No Foot Path',
              normalizedName: 'no foot path',
              lengthMeters: 800,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|17',
              chunkKey: '0_0',
              osmWayId: 17,
              highway: 'path',
              access: 'public',
              route: 'mtb',
              name: 'MTB Route',
              normalizedName: 'mtb route',
              lengthMeters: 800,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|18',
              chunkKey: '0_0',
              osmWayId: 18,
              highway: 'track',
              surface: 'earth',
              access: 'public',
              name: 'Track',
              normalizedName: 'track',
              lengthMeters: 800,
              tagCount: 2,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryTrailWays();

    expect(rows.map((row) => row.osmWayId), [10, 11, 18]);
  });

  test('queryDriveEtaWaysForBounds applies the drive ETA filter', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [_chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0)],
          wayIndexRows: [
            _wayRow(
              recordKey: '1|0_0|10',
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'service',
              access: 'public',
              name: 'Allowed Service Road',
              normalizedName: 'allowed service road',
              lengthMeters: 300,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|11',
              chunkKey: '0_0',
              osmWayId: 11,
              highway: 'track',
              surface: 'earth',
              access: 'public',
              name: 'Earth Track',
              normalizedName: 'earth track',
              lengthMeters: 300,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|12',
              chunkKey: '0_0',
              osmWayId: 12,
              highway: 'service',
              access: 'private',
              name: 'Private Road',
              normalizedName: 'private road',
              lengthMeters: 300,
              tagCount: 2,
            ),
            _wayRow(
              recordKey: '1|0_0|13',
              chunkKey: '0_0',
              osmWayId: 13,
              highway: 'path',
              access: 'public',
              name: 'Walking Path',
              normalizedName: 'walking path',
              lengthMeters: 300,
              tagCount: 2,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryDriveEtaWaysForBounds(
      minLat: -41.8,
      minLon: 146.2,
      maxLat: -41.2,
      maxLon: 146.8,
    );

    expect(rows.map((row) => row.osmWayId), [10]);
  });

  test('queryTrailMergedPayloadsForBounds merges trail chunks only', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [
            _chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0, payloadJson: _payload),
            _chunk('1|2_2', '2_2', -35.0, 140.0, -34.0, 141.0, payloadJson: _payload),
          ],
          wayIndexRows: [
            _wayRow(
              recordKey: '1|0_0|10',
              chunkKey: '0_0',
              osmWayId: 10,
              highway: 'path',
              access: 'public',
              name: 'Trail',
              normalizedName: 'trail',
              lengthMeters: 600,
              tagCount: 2,
            ),
          ],
        ),
      ),
    );

    final payloads = service.queryTrailMergedPayloadsForBounds(
      minLat: -41.8,
      minLon: 146.2,
      maxLat: -41.2,
      maxLon: 146.8,
    );

    expect(payloads, hasLength(1));
    final elements = payloads.single['elements'] as List;
    expect(elements, hasLength(3));
  });

  test(
    'queryTrailDisplayChunksForBounds returns active-generation rows for visible chunks and rounded zoom',
    () {
      final service = RouteGraphQueryService(
        RouteGraphRepository.test(
          InMemoryRouteGraphStorage(
            manifest: _manifest,
            chunks: [
              _chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0),
              _chunk('1|2_2', '2_2', -35.0, 140.0, -34.0, 141.0),
            ],
            trailDisplayChunks: [
              _trailDisplayChunk(
                generation: 1,
                cacheZoom: 16,
                chunkKey: '0_0',
                osmWayId: 10,
              ),
              _trailDisplayChunk(
                generation: 1,
                cacheZoom: 15,
                chunkKey: '0_0',
                osmWayId: 11,
              ),
              _trailDisplayChunk(
                generation: 1,
                cacheZoom: 16,
                chunkKey: '2_2',
                osmWayId: 12,
              ),
              _trailDisplayChunk(
                generation: 2,
                cacheZoom: 16,
                chunkKey: '0_0',
                osmWayId: 13,
              ),
            ],
          ),
        ),
      );

      final rows = service.queryTrailDisplayChunksForBounds(
        minLat: -41.8,
        minLon: 146.2,
        maxLat: -41.2,
        maxLon: 146.8,
        zoom: 15.6,
      );

      expect(rows, hasLength(1));
      expect(rows.single.chunkKey, '0_0');
      expect(rows.single.cacheZoom, 16);
      expect(rows.single.decodeWays().single.osmWayId, 10);
    },
  );

  test('queryTrailDisplayChunksForBounds returns empty for empty viewport', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [_chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0)],
          trailDisplayChunks: [
            _trailDisplayChunk(
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
              osmWayId: 10,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryTrailDisplayChunksForBounds(
      minLat: -30.0,
      minLon: 120.0,
      maxLat: -29.0,
      maxLon: 121.0,
      zoom: 15,
    );

    expect(rows, isEmpty);
  });

  test('queryTrailDisplayChunksForBounds returns empty when zoom bucket is missing', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [_chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0)],
          trailDisplayChunks: [
            _trailDisplayChunk(
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
              osmWayId: 10,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryTrailDisplayChunksForBounds(
      minLat: -41.8,
      minLon: 146.2,
      maxLat: -41.2,
      maxLon: 146.8,
      zoom: 16.0,
    );

    expect(rows, isEmpty);
  });

  test('queryTrailDisplayChunksForBounds returns rows for all visible chunks', () {
    final service = RouteGraphQueryService(
      RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: _manifest,
          chunks: [
            _chunk('1|0_0', '0_0', -42.0, 146.0, -41.0, 147.0),
            _chunk('1|0_1', '0_1', -42.0, 146.0, -41.0, 147.0),
          ],
          trailDisplayChunks: [
            _trailDisplayChunk(
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
              osmWayId: 10,
            ),
            _trailDisplayChunk(
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_1',
              osmWayId: 11,
            ),
          ],
        ),
      ),
    );

    final rows = service.queryTrailDisplayChunksForBounds(
      minLat: -41.8,
      minLon: 146.2,
      maxLat: -41.2,
      maxLon: 146.8,
      zoom: 15.0,
    );

    expect(rows.map((row) => row.chunkKey).toSet(), {'0_0', '0_1'});
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

RouteGraphWayIndex _wayRow({
  required String recordKey,
  required String chunkKey,
  required int osmWayId,
  required String highway,
  required String access,
  String? surface,
  String? footway,
  String? foot,
  String? route,
  required String name,
  required String normalizedName,
  required int lengthMeters,
  required int tagCount,
}) {
  return RouteGraphWayIndex(
    recordKey: recordKey,
    generation: 1,
    chunkKey: chunkKey,
    osmWayId: osmWayId,
    highway: highway,
    surface: surface,
    footway: footway,
    foot: foot,
    route: route,
    access: access,
    name: name,
    normalizedName: normalizedName,
    lengthMeters: lengthMeters,
    tagCount: tagCount,
    tagsJson: '{}',
  );
}

RouteGraphTrailDisplayChunk _trailDisplayChunk({
  required int generation,
  required int cacheZoom,
  required String chunkKey,
  required int osmWayId,
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
      RouteGraphTrailDisplayWay(
        osmWayId: osmWayId,
        points: const [
          LatLng(-41.5, 146.5),
          LatLng(-41.6, 146.6),
        ],
      ),
    ]),
  );
}
