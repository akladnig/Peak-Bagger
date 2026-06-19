import 'package:fvg_topo_proxy/src/upstream_wms_client.dart';
import 'package:fvg_topo_proxy/src/web_mercator.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('buildGetMapUri emits expected WMS query parameters', () {
    final client = HttpUpstreamWmsClient(
      baseUrl: Uri.parse('https://example.com/wms'),
      client: MockClient((_) async => http.Response.bytes(const [], 200)),
    );
    const bbox = ProjectedBounds(
      minX: 1371609.816,
      minY: 5713440.366,
      maxX: 1549417.631,
      maxY: 5884799.174,
    );

    final uri = client.buildGetMapUri(
      bbox,
      layerName: upstreamLayerNameForZoom(12),
    );

    expect(uri.queryParameters['service'], 'WMS');
    expect(uri.queryParameters['request'], 'GetMap');
    expect(uri.queryParameters['version'], '1.3.0');
    expect(uri.queryParameters['layers'], 'IRDAT:CRN25KColore');
    expect(uri.queryParameters['crs'], 'EPSG:3857');
    expect(uri.queryParameters['width'], '$tileDimension');
    expect(uri.queryParameters['height'], '$tileDimension');
    expect(uri.queryParameters['format'], 'image/png');
    expect(uri.queryParameters['bbox'], bbox.toBboxString());
  });

  test('maps zoom levels to topo layers', () {
    expect(upstreamLayerNameForZoom(1), 'IRDAT:CRN25KColore');
    expect(upstreamLayerNameForZoom(12), 'IRDAT:CRN25KColore');
    expect(upstreamLayerNameForZoom(13), 'IRDAT:CTRN5KColore');
    expect(upstreamLayerNameForZoom(19), 'IRDAT:CTRN5KColore');
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
        minX: 1371609.816,
        minY: 5713440.366,
        maxX: 1549417.631,
        maxY: 5884799.174,
      ),
      layerName: upstreamLayerNameForZoom(13),
    );

    expect(response.statusCode, 200);
    expect(response.bodyBytes, const [1, 2, 3]);
    expect(response.contentType, 'image/png');
  });
}
