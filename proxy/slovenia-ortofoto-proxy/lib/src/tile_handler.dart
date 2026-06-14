import 'dart:async';
import 'package:shelf/shelf.dart';

import 'projection.dart';
import 'transparent_tile.dart';
import 'upstream_wms_client.dart';

export 'projection.dart' show ProjectedBounds, TileCoordinate, projectTileBoundsToSloveniaCrs, sloveniaCoverageBounds;
export 'upstream_wms_client.dart' show HttpUpstreamWmsClient, UpstreamTileResponse, UpstreamWmsClient;

const _routePrefix = 'slovenia-ortofoto';

class SloveniaOrtofotoTileHandler {
  SloveniaOrtofotoTileHandler({
    required UpstreamWmsClient upstreamClient,
    int maxZoom = 18,
  }) : _upstreamClient = upstreamClient,
       _maxZoom = maxZoom;

  final UpstreamWmsClient _upstreamClient;
  final int _maxZoom;

  Future<Response> handle(Request request) async {
    final coordinate = TileCoordinate.tryParse(
      request.url.pathSegments,
      routePrefix: _routePrefix,
    );
    if (coordinate == null) {
      return Response.badRequest(body: 'Invalid tile path');
    }

    if (coordinate.z > _maxZoom) {
      return _transparentTileResponse();
    }

    final bbox = projectTileBoundsToSloveniaCrs(coordinate);
    if (!bbox.intersects(sloveniaCoverageBounds)) {
      return _transparentTileResponse();
    }

    try {
      final upstreamResponse = await _upstreamClient.fetchTile(bbox: bbox);
      if (upstreamResponse.statusCode != 200 ||
          !(upstreamResponse.contentType?.startsWith('image/png') ?? false)) {
        return _badGatewayResponse();
      }

      return Response.ok(
        upstreamResponse.bodyBytes,
        headers: {
          'Content-Type': 'image/png',
          'Cache-Control': 'public, max-age=86400',
        },
      );
    } on TimeoutException catch (_) {
      return _badGatewayResponse();
    } catch (_) {
      return _badGatewayResponse();
    }
  }
}

Response _transparentTileResponse() {
  return Response.ok(
    transparentTilePngBytes,
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=3600',
    },
  );
}

Response _badGatewayResponse() {
  return Response(
    502,
    body: 'Upstream WMS request failed',
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=60',
    },
  );
}
