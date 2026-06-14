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
      Request('GET', Uri.parse('https://example.com/slovenia-ortofoto/nope/1.png')),
    );

    expect(response.statusCode, 400);
  });

  test('returns transparent tile when request does not intersect Slovenia', () async {
    final upstream = _FakeUpstreamWmsClient();
    final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
    final tile = _tileForLatLng(latitude: 0, longitude: 0, zoom: 10);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-ortofoto/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['Content-Type'], 'image/png');
    expect(response.headers['Cache-Control'], 'public, max-age=3600');
    expect(upstream.callCount, 0);
  });

  test('uses exact projected bbox for intersecting tile request', () async {
    final upstream = _FakeUpstreamWmsClient();
    final handler = SloveniaOrtofotoTileHandler(upstreamClient: upstream);
    final tile = _tileForLatLng(latitude: 46.05, longitude: 14.5, zoom: 10);
    final expectedBounds = projectTileBoundsToSloveniaCrs(tile);

    final response = await handler.handle(
      Request(
        'GET',
        Uri.parse(
          'https://example.com/slovenia-ortofoto/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 200);
    expect(response.headers['Cache-Control'], 'public, max-age=86400');
    expect(upstream.callCount, 1);
    expect(upstream.lastBounds?.toBboxString(), expectedBounds.toBboxString());
  });

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
          'https://example.com/slovenia-ortofoto/${tile.z}/${tile.x}/${tile.y}.png',
        ),
      ),
    );

    expect(response.statusCode, 502);
    expect(response.headers['Cache-Control'], 'public, max-age=60');
    expect(await response.readAsString(), 'Upstream WMS request failed');
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
      (1 - math.log(math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians)) / math.pi) /
      2;
  final y = (mercatorY * tileCount).floor();
  return TileCoordinate(z: zoom, x: x, y: y);
}

class _FakeUpstreamWmsClient implements UpstreamWmsClient {
  _FakeUpstreamWmsClient({UpstreamTileResponse? response})
    : _response =
          response ??
          UpstreamTileResponse(
            statusCode: 200,
            bodyBytes: base64Decode(_pngBase64),
            contentType: 'image/png',
          );

  final UpstreamTileResponse _response;
  int callCount = 0;
  ProjectedBounds? lastBounds;

  @override
  Future<UpstreamTileResponse> fetchTile({required ProjectedBounds bbox}) async {
    callCount++;
    lastBounds = bbox;
    return _response;
  }
}
