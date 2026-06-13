import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:proj4dart/proj4dart.dart' as proj4;
import 'package:shelf/shelf.dart';

const _routePrefix = 'slovenia-ortofoto';
const _tileDimension = 256;
const _originShift = 20037508.342789244;
const _sloveniaProjectionCode = 'EPSG:3794';
const _sloveniaProjectionDef =
    '+proj=tmerc +lat_0=0 +lon_0=15 +k=0.9999 +x_0=500000 +y_0=-5000000 +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +units=m +no_defs +type=crs';
const _upstreamLayerName = 'SI.GURS.ZPDZ:DOF5';
const _transparentPngBase64 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a1ioAAAAASUVORK5CYII=';
final _transparentPngBytes = base64Decode(_transparentPngBase64);

final _webMercatorProjection = proj4.Projection.get('EPSG:3857')!;
final _sloveniaProjection =
    proj4.Projection.get(_sloveniaProjectionCode) ??
    proj4.Projection.add(_sloveniaProjectionCode, _sloveniaProjectionDef);

const sloveniaCoverageBounds = ProjectedBounds(
  minX: 374000,
  minY: 28000,
  maxX: 626000,
  maxY: 196000,
);

class TileCoordinate {
  const TileCoordinate({required this.z, required this.x, required this.y});

  final int z;
  final int x;
  final int y;

  static TileCoordinate? tryParse(List<String> pathSegments) {
    if (pathSegments.length != 4 || pathSegments.first != _routePrefix) {
      return null;
    }

    final z = int.tryParse(pathSegments[1]);
    final x = int.tryParse(pathSegments[2]);
    final ySegment = pathSegments[3];
    if (!ySegment.endsWith('.png')) {
      return null;
    }
    final y = int.tryParse(ySegment.substring(0, ySegment.length - 4));

    if (z == null || x == null || y == null || z < 0 || x < 0 || y < 0) {
      return null;
    }

    final tileCount = 1 << z;
    if (x >= tileCount || y >= tileCount) {
      return null;
    }

    return TileCoordinate(z: z, x: x, y: y);
  }
}

class ProjectedBounds {
  const ProjectedBounds({
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
  });

  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  bool intersects(ProjectedBounds other) {
    return maxX > other.minX &&
        minX < other.maxX &&
        maxY > other.minY &&
        minY < other.maxY;
  }

  String toBboxString() {
    return '${_formatCoord(minX)},${_formatCoord(minY)},${_formatCoord(maxX)},${_formatCoord(maxY)}';
  }
}

String _formatCoord(double value) => value.toStringAsFixed(3);

ProjectedBounds tileBoundsInWebMercator(TileCoordinate coordinate) {
  final tileCount = 1 << coordinate.z;
  final fullExtent = _originShift * 2;
  final minX = coordinate.x / tileCount * fullExtent - _originShift;
  final maxX = (coordinate.x + 1) / tileCount * fullExtent - _originShift;
  final maxY = _originShift - coordinate.y / tileCount * fullExtent;
  final minY = _originShift - (coordinate.y + 1) / tileCount * fullExtent;
  return ProjectedBounds(minX: minX, minY: minY, maxX: maxX, maxY: maxY);
}

ProjectedBounds projectTileBoundsToSloveniaCrs(TileCoordinate coordinate) {
  final webBounds = tileBoundsInWebMercator(coordinate);
  final points = [
    proj4.Point(x: webBounds.minX, y: webBounds.minY),
    proj4.Point(x: webBounds.minX, y: webBounds.maxY),
    proj4.Point(x: webBounds.maxX, y: webBounds.minY),
    proj4.Point(x: webBounds.maxX, y: webBounds.maxY),
  ];

  final transformed = points
      .map((point) => _webMercatorProjection.transform(_sloveniaProjection, point))
      .toList(growable: false);

  final xs = transformed.map((point) => point.x);
  final ys = transformed.map((point) => point.y);
  return ProjectedBounds(
    minX: xs.reduce((left, right) => left < right ? left : right),
    minY: ys.reduce((left, right) => left < right ? left : right),
    maxX: xs.reduce((left, right) => left > right ? left : right),
    maxY: ys.reduce((left, right) => left > right ? left : right),
  );
}

class UpstreamTileResponse {
  const UpstreamTileResponse({
    required this.statusCode,
    required this.bodyBytes,
    required this.contentType,
  });

  final int statusCode;
  final List<int> bodyBytes;
  final String? contentType;
}

abstract class UpstreamWmsClient {
  Future<UpstreamTileResponse> fetchTile({required ProjectedBounds bbox});
}

class HttpUpstreamWmsClient implements UpstreamWmsClient {
  HttpUpstreamWmsClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  @override
  Future<UpstreamTileResponse> fetchTile({required ProjectedBounds bbox}) async {
    final response = await _client.get(_buildGetMapUri(bbox)).timeout(timeout);
    return UpstreamTileResponse(
      statusCode: response.statusCode,
      bodyBytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  Uri _buildGetMapUri(ProjectedBounds bbox) {
    return baseUrl.replace(
      queryParameters: {
        'service': 'WMS',
        'request': 'GetMap',
        'version': '1.3.0',
        'layers': _upstreamLayerName,
        'styles': '',
        'crs': _sloveniaProjectionCode,
        'bbox': bbox.toBboxString(),
        'width': '$_tileDimension',
        'height': '$_tileDimension',
        'format': 'image/png',
        'transparent': 'true',
      },
    );
  }
}

class SloveniaOrtofotoTileHandler {
  SloveniaOrtofotoTileHandler({
    required UpstreamWmsClient upstreamClient,
    int maxZoom = 18,
  }) : _upstreamClient = upstreamClient,
       _maxZoom = maxZoom;

  final UpstreamWmsClient _upstreamClient;
  final int _maxZoom;

  Future<Response> handle(Request request) async {
    final coordinate = TileCoordinate.tryParse(request.url.pathSegments);
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
    _transparentPngBytes,
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
