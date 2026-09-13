import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/local_topo_overlay_tile_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';

void main() {
  test('reports a 5xx terrain relief tile outage once', () async {
    final messages = <String>[];
    final reporter = OverlayTileOutageReporter(messages.add);
    final client = OverlayTileRequestClient(
      delegate: _FakeHttpClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 503),
      ),
      overlayKey: terrainReliefShadingOverlayKey,
      reporter: reporter,
    );

    await Future.wait([
      for (var tile = 0; tile < 10; tile += 1)
        client.send(
          http.Request('GET', Uri.parse('http://tiles.test/0/0/$tile')),
        ),
    ]);

    expect(messages, [
      'Terrain relief shading is unavailable from the local tile server',
    ]);
  });

  test('injects the overlay tile provider into its standalone layer', () {
    final provider = OverlayTileProvider(
      overlayKey: terrainReliefShadingOverlayKey,
      reporter: OverlayTileOutageReporter(),
    );
    addTearDown(provider.dispose);

    final layer = buildStandaloneOverlayTileLayer(
      snapshot: LocalTopoCapabilitySnapshot(
        baseUrl: Uri.parse('http://tiles.test'),
        regions: const [],
        overlays: const [
          LocalTopoOverlayCapability(
            key: terrainReliefShadingOverlayKey,
            label: 'Terrain relief shading',
            regions: [
              LocalTopoRegionCapability(
                regionKey: 'tasmania',
                tilePathTemplate: '/relief/{z}/{x}/{y}.png',
              ),
            ],
          ),
        ],
      ),
      overlayKey: terrainReliefShadingOverlayKey,
      opacityPercent: 35,
      tileProvider: provider,
    );

    expect(layer!.tileProvider, same(provider));
  });

  test('does not report 4xx, no-data, or successful tile responses', () async {
    final messages = <String>[];
    final reporter = OverlayTileOutageReporter(messages.add);

    for (final statusCode in [204, 404, 200]) {
      final client = OverlayTileRequestClient(
        delegate: _FakeHttpClient(
          (_) async => http.StreamedResponse(const Stream.empty(), statusCode),
        ),
        overlayKey: contourLinesOverlayKey,
        reporter: reporter,
      );
      await client.send(
        http.Request('GET', Uri.parse('http://tiles.test/0/0/$statusCode')),
      );
    }

    expect(messages, isEmpty);
  });

  test('reports tile transport exceptions and timeout expiry', () async {
    final messages = <String>[];
    final reporter = OverlayTileOutageReporter(messages.add);
    final transportClient = OverlayTileRequestClient(
      delegate: _FakeHttpClient(
        (_) => Future<http.StreamedResponse>.error(
          http.ClientException('connection refused'),
        ),
      ),
      overlayKey: contourLinesOverlayKey,
      reporter: reporter,
    );
    final timeoutClient = OverlayTileRequestClient(
      delegate: _FakeHttpClient(
        (_) => Completer<http.StreamedResponse>().future,
      ),
      overlayKey: contourLinesOverlayKey,
      reporter: reporter,
      timeout: Duration.zero,
    );

    await expectLater(
      transportClient.send(
        http.Request('GET', Uri.parse('http://tiles.test/0')),
      ),
      throwsA(isA<http.ClientException>()),
    );
    await expectLater(
      timeoutClient.send(http.Request('GET', Uri.parse('http://tiles.test/1'))),
      throwsA(isA<TimeoutException>()),
    );

    expect(messages, [
      'Contour lines are unavailable from the local tile server',
    ]);
  });

  test(
    'a successful tile response does not reset outage suppression',
    () async {
      final messages = <String>[];
      final reporter = OverlayTileOutageReporter(messages.add);
      final unavailable = OverlayTileRequestClient(
        delegate: _FakeHttpClient(
          (_) async => http.StreamedResponse(const Stream.empty(), 503),
        ),
        overlayKey: contourLinesOverlayKey,
        reporter: reporter,
      );
      final available = OverlayTileRequestClient(
        delegate: _FakeHttpClient(
          (_) async => http.StreamedResponse(const Stream.empty(), 200),
        ),
        overlayKey: contourLinesOverlayKey,
        reporter: reporter,
      );

      await unavailable.send(
        http.Request('GET', Uri.parse('http://tiles.test/0')),
      );
      await available.send(
        http.Request('GET', Uri.parse('http://tiles.test/1')),
      );
      await unavailable.send(
        http.Request('GET', Uri.parse('http://tiles.test/2')),
      );

      expect(messages, [
        'Contour lines are unavailable from the local tile server',
      ]);
    },
  );
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _handler(request);
}
