import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:shelf/shelf.dart';
import 'package:slovenia_ortofoto_proxy/src/tile_handler.dart';
import 'package:test/test.dart';

const _pngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=';

void main() {
  test('returns 400 for malformed tile path', () async {
    final handler = SloveniaOrtofotoTileHandler(
      upstreamClient: _FakeUpstreamWmsClient(),
    );

    final response = await handler.handle(
      Request('GET', Uri.parse('https://example.com/slovenia-topo/nope/1.png')),
    );

    expect(response.statusCode, 400);
  });

  test(
    'returns transparent tile when request does not intersect Slovenia',
    () async {
      final upstream = _FakeUpstreamWmsClient();
      final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
      final tile = _tileForLatLng(latitude: 0, longitude: 0, zoom: 10);

      final response = await handler.handle(
        Request(
          'GET',
          Uri.parse(
            'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
          ),
        ),
      );

      expect(response.statusCode, 200);
      expect(response.headers['Content-Type'], 'image/png');
      expect(response.headers['Cache-Control'], 'public, max-age=3600');
      expect(upstream.callCount, 0);
    },
  );

  test('uses exact projected bbox for intersecting tile request', () async {
    final upstream = _FakeUpstreamWmsClient();
    final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
    final tile = _tileForLatLng(latitude: 46.05, longitude: 14.5, zoom: 10);
    final expectedBounds = projectTileBoundsToSloveniaCrs(tile);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['Cache-Control'], 'public, max-age=86400');
    expect(upstream.callCount, 1);
    expect(upstream.lastBounds?.toBboxString(), expectedBounds.toBboxString());
    expect(upstream.lastLayerName, 'SI.GURS.DK:DPK750');
  });

  test('switches upstream layer by zoom band', () async {
    final cases = <int, String>{
      1: 'SI.GURS.DK:DPK1000',
      9: 'SI.GURS.DK:DPK1000',
      10: 'SI.GURS.DK:DPK750',
      11: 'SI.GURS.DK:DPK500',
      12: 'SI.GURS.DK:DPK250',
      13: 'SI.GURS.DK:DTK50',
      14: 'SI.GURS.DK:DTK50',
    };

    for (final entry in cases.entries) {
      final upstream = _FakeUpstreamWmsClient();
      final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
      final tile = _tileForLatLng(
        latitude: 46.05,
        longitude: 14.5,
        zoom: entry.key,
      );

      await handler.handle(
        Request(
          'GET',
          Uri.parse(
            'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
          ),
        ),
      );

      expect(upstream.lastLayerName, entry.value);
    }
  });

  test(
    'returns transparent tile above configured max zoom without upstream call',
    () async {
      final upstream = _FakeUpstreamWmsClient();
      final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);

      final response = await handler.handle(
        Request(
          'GET',
          Uri.parse('https://example.com/slovenia-topo/20/566523/372803.png'),
        ),
      );

      expect(response.statusCode, 200);
      expect(response.headers['Content-Type'], 'image/png');
      expect(response.headers['Cache-Control'], 'public, max-age=3600');
      expect(upstream.callCount, 0);
    },
  );

  test('maps upstream HTML failure to 502 without leaking body', () async {
    final handler = SloveniaOrtofotoTileHandler(
      upstreamClient: _FakeUpstreamWmsClient(
        response: const UpstreamTileResponse(
          statusCode: 500,
          bodyBytes: [60, 104, 116, 109, 108, 62],
          contentType: 'text/html',
        ),
      ),
    );
    final tile = _tileForLatLng(latitude: 46.05, longitude: 14.5, zoom: 10);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 502);
    expect(response.headers['Cache-Control'], 'public, max-age=60');
    expect(await response.readAsString(), 'Upstream WMS request failed');
  });

  test('retries transient upstream failure before succeeding', () async {
    final upstream = _FakeUpstreamWmsClient(
      responses: [
        const UpstreamTileResponse(
          statusCode: 500,
          bodyBytes: [60, 104, 116, 109, 108, 62],
          contentType: 'text/html',
        ),
      ],
    );
    final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
    final tile = _tileForLatLng(latitude: 46.05, longitude: 14.5, zoom: 14);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['Content-Type'], 'image/png');
    expect(upstream.callCount, 2);
  });

  test('retries transient upstream timeout before succeeding', () async {
    final upstream = _FakeUpstreamWmsClient(throwTimeoutCount: 1);
    final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
    final tile = _tileForLatLng(latitude: 46.05, longitude: 14.5, zoom: 14);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-topo/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['Content-Type'], 'image/png');
    expect(upstream.callCount, 2);
  });
}

TileCoordinate _tileForLatLng({
  required double latitude,
  required double longitude,
  required int zoom,
}) {
  final tileCount = 1 << zoom;
  final x = ((longitude + 180) / 360 * tileCount).floor();
  final latitudeRadians = latitude * math.pi / 180;
  final mercatorY =
      (1 -
          math.log(math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians)) /
              math.pi) /
      2;
  final y = (mercatorY * tileCount).floor();
  return TileCoordinate(z: zoom, x: x, y: y);
}

class _FakeUpstreamWmsClient implements UpstreamWmsClient {
  _FakeUpstreamWmsClient({
    UpstreamTileResponse? response,
    List<UpstreamTileResponse>? responses,
    this.throwTimeoutCount = 0,
  }) : _response =
           response ??
           UpstreamTileResponse(
             statusCode: 200,
             bodyBytes: base64Decode(_pngBase64),
             contentType: 'image/png',
           ),
       _responses = responses != null
           ? List<UpstreamTileResponse>.from(responses)
           : null;

  final UpstreamTileResponse _response;
  final List<UpstreamTileResponse>? _responses;
  int throwTimeoutCount;
  int callCount = 0;
  ProjectedBounds? lastBounds;
  String? lastLayerName;

  @override
  Future<UpstreamTileResponse> fetchTile({
    required ProjectedBounds bbox,
    required String layerName,
  }) async {
    callCount++;
    lastBounds = bbox;
    lastLayerName = layerName;
    if (throwTimeoutCount > 0) {
      throwTimeoutCount--;
      throw TimeoutException('transient timeout');
    }
    if (_responses != null && _responses!.isNotEmpty) {
      return _responses!.removeAt(0);
    }
    return _response;
  }
}
