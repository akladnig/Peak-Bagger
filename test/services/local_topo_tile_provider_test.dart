import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:peak_bagger/services/local_topo_tile_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reports concurrent local tile connection failures once', () async {
    final failures = <Uri>[];
    final client = LocalTopoTileRequestClient(
      delegate: _FakeHttpClient(
        (_) => Future.error(http.ClientException('Operation timed out')),
      ),
      onUnavailable: failures.add,
    );
    addTearDown(client.close);
    final tile = Uri.parse('http://mac-mini.local:8090/12/3714/2583.png');

    await Future.wait([
      for (var i = 0; i < 3; i++)
        expectLater(
          client.send(http.Request('GET', tile)),
          throwsA(isA<http.ClientException>()),
        ),
    ]);

    expect(failures, [tile]);
  });

  test('times out a stalled connection and aborts the request', () async {
    final failures = <Uri>[];
    final aborted = Completer<void>();
    final client = LocalTopoTileRequestClient(
      delegate: _FakeHttpClient((request) {
        (request as http.Abortable).abortTrigger!.then(
          (_) => aborted.complete(),
        );
        return Completer<http.StreamedResponse>().future;
      }),
      onUnavailable: failures.add,
      timeout: Duration.zero,
    );
    addTearDown(client.close);
    final tile = Uri.parse('http://mac-mini.local:8090/12/3714/2583.png');

    await expectLater(
      client.send(http.Request('GET', tile)),
      throwsA(isA<TimeoutException>()),
    );
    await aborted.future;
    expect(failures, [tile]);
  });

  test('times out a stalled image body and reports the outage', () async {
    final failures = <Uri>[];
    final body = StreamController<List<int>>();
    addTearDown(body.close);
    final client = LocalTopoTileRequestClient(
      delegate: _FakeHttpClient(
        (_) async => http.StreamedResponse(body.stream, 200),
      ),
      onUnavailable: failures.add,
      timeout: Duration.zero,
    );
    addTearDown(client.close);
    final tile = Uri.parse('http://mac-mini.local:8090/12/3714/2583.png');
    final response = await client.send(http.Request('GET', tile));

    await expectLater(
      response.stream.toBytes().timeout(const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    expect(failures, [tile]);
  });

  test('reports a server failure but not a missing tile', () async {
    final failures = <Uri>[];
    final client = LocalTopoTileRequestClient(
      delegate: _FakeHttpClient(
        (request) async => http.StreamedResponse(
          Stream.value(<int>[]),
          int.parse(request.url.pathSegments.last),
        ),
      ),
      onUnavailable: failures.add,
    );
    addTearDown(client.close);

    for (final status in [200, 404, 503]) {
      final uri = Uri.parse('http://mac-mini.local:8090/$status');
      final response = await client.send(http.Request('GET', uri));
      await response.stream.drain<void>();
    }

    expect(failures, [Uri.parse('http://mac-mini.local:8090/503')]);
  });

  test('panning cancellation does not report a server outage', () async {
    final failures = <Uri>[];
    final cancel = Completer<void>();
    final client = LocalTopoTileRequestClient(
      delegate: _FakeHttpClient((request) async {
        await (request as http.Abortable).abortTrigger;
        throw http.RequestAbortedException(request.url);
      }),
      onUnavailable: failures.add,
    );
    addTearDown(client.close);
    final pending = client.send(
      http.AbortableRequest(
        'GET',
        Uri.parse('http://mac-mini.local:8090/12/3714/2583.png'),
        abortTrigger: cancel.future,
      ),
    );
    cancel.complete();

    await expectLater(pending, throwsA(isA<http.RequestAbortedException>()));
    expect(failures, isEmpty);
  });

  test(
    'a failed local tile resolves safely and reports instead of throwing an image error',
    () async {
      final failures = <Uri>[];
      final provider = LocalTopoTileProvider(
        httpClient: _FakeHttpClient(
          (_) => Future.error(http.ClientException('Operation timed out')),
        ),
        onUnavailable: failures.add,
      );
      addTearDown(provider.dispose);
      final layer = TileLayer(
        urlTemplate: 'http://mac-mini.local:8090/{z}/{x}/{y}.png',
        tileProvider: provider,
      );
      final stream = provider
          .getImageWithCancelLoadingSupport(
            const TileCoordinates(3714, 2583, 12),
            layer,
            Completer<void>().future,
          )
          .resolve(ImageConfiguration.empty);
      final result = Completer<ImageInfo>();
      final listener = ImageStreamListener(
        (image, _) => result.complete(image),
        onError: result.completeError,
      );
      stream.addListener(listener);
      addTearDown(() => stream.removeListener(listener));

      final image = await result.future;
      addTearDown(image.dispose);
      expect(image.image.width, 1);
      expect(failures, [
        Uri.parse('http://mac-mini.local:8090/12/3714/2583.png'),
      ]);
    },
  );
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this.handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest) handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);
}
