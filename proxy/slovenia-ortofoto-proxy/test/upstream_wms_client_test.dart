import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:slovenia_ortofoto_proxy/src/projection.dart';
import 'package:slovenia_ortofoto_proxy/src/upstream_wms_client.dart';
import 'package:test/test.dart';

void main() {
  test('buildGetMapUri emits expected WMS query parameters', () {
    final client = HttpUpstreamWmsClient(
      baseUrl: Uri.parse('https://example.com/wms'),
      client: MockClient((_) async => http.Response.bytes(const [], 200)),
    );
    const bbox = ProjectedBounds(
      minX: 374000,
      minY: 28000,
      maxX: 626000,
      maxY: 196000,
    );

    final uri = client.buildGetMapUri(bbox);

    expect(uri.queryParameters['service'], 'WMS');
    expect(uri.queryParameters['request'], 'GetMap');
    expect(uri.queryParameters['version'], '1.3.0');
    expect(uri.queryParameters['layers'], upstreamLayerName);
    expect(uri.queryParameters['crs'], sloveniaProjectionCode);
    expect(uri.queryParameters['width'], '$tileDimension');
    expect(uri.queryParameters['height'], '$tileDimension');
    expect(uri.queryParameters['format'], 'image/png');
    expect(uri.queryParameters['bbox'], bbox.toBboxString());
  });

  test('fetchTile returns upstream status bytes and content type', () async {
    final client = HttpUpstreamWmsClient(
      baseUrl: Uri.parse('https://example.com/wms'),
      client: MockClient(
        (_) async => http.Response.bytes(
          const [1, 2, 3],
          200,
          headers: {'content-type': 'image/png'},
        ),
      ),
    );

    final response = await client.fetchTile(
      bbox: const ProjectedBounds(
        minX: 374000,
        minY: 28000,
        maxX: 626000,
        maxY: 196000,
      ),
    );

    expect(response.statusCode, 200);
    expect(response.bodyBytes, const [1, 2, 3]);
    expect(response.contentType, 'image/png');
  });
}
