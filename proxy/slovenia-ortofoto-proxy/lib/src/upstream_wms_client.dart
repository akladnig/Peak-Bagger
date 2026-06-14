import 'dart:async';

import 'package:http/http.dart' as http;

import 'projection.dart';

const upstreamLayerName = 'SI.GURS.ZPDZ:DOF5';
const tileDimension = 256;

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
    final response = await _client.get(buildGetMapUri(bbox)).timeout(timeout);
    return UpstreamTileResponse(
      statusCode: response.statusCode,
      bodyBytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  Uri buildGetMapUri(ProjectedBounds bbox) {
    return baseUrl.replace(
      queryParameters: {
        'service': 'WMS',
        'request': 'GetMap',
        'version': '1.3.0',
        'layers': upstreamLayerName,
        'styles': '',
        'crs': sloveniaProjectionCode,
        'bbox': bbox.toBboxString(),
        'width': '$tileDimension',
        'height': '$tileDimension',
        'format': 'image/png',
        'transparent': 'true',
      },
    );
  }
}
