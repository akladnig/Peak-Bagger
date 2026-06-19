import 'dart:async';

import 'package:http/http.dart' as http;

import 'web_mercator.dart';

const tileDimension = 256;

String upstreamLayerNameForZoom(int zoom) {
  if (zoom <= 12) {
    return 'IRDAT:CRN25KColore';
  }

  return 'IRDAT:CTRN5KColore';
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
  Future<UpstreamTileResponse> fetchTile({
    required ProjectedBounds bbox,
    required String layerName,
  });
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
  Future<UpstreamTileResponse> fetchTile({
    required ProjectedBounds bbox,
    required String layerName,
  }) async {
    final response = await _client
        .get(buildGetMapUri(bbox, layerName: layerName))
        .timeout(timeout);
    return UpstreamTileResponse(
      statusCode: response.statusCode,
      bodyBytes: response.bodyBytes,
      contentType: response.headers['content-type'],
    );
  }

  Uri buildGetMapUri(ProjectedBounds bbox, {required String layerName}) {
    return baseUrl.replace(
      queryParameters: {
        'service': 'WMS',
        'request': 'GetMap',
        'version': '1.3.0',
        'layers': layerName,
        'styles': '',
        'crs': 'EPSG:3857',
        'bbox': bbox.toBboxString(),
        'width': '$tileDimension',
        'height': '$tileDimension',
        'format': 'image/png',
        'transparent': 'true',
      },
    );
  }
}
