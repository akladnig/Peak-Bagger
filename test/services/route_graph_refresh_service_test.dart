import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:peak_bagger/services/route_graph_refresh_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

void main() {
  test('refreshRouteGraph uses the exact query and reloads the cache', () async {
    final store = _FakeRouteGraphStore();
    late final MockClient client;
    client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(
        request.body,
        'data=${Uri.encodeQueryComponent(_expectedQuery)}',
      );
      return http.Response(
        '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.5}]}',
        200,
      );
    });

    final service = RouteGraphRefreshService(store, httpClient: client);
    final result = await service.refreshRouteGraph();

    expect(result.elementCount, 1);
    expect(store.replaceCallCount, 1);
    expect(store.reloadCallCount, 1);
  });

  test('refreshRouteGraph rejects empty graph results', () async {
    final store = _FakeRouteGraphStore();
    final client = MockClient((request) async {
      return http.Response('{"elements":[]}', 200);
    });

    final service = RouteGraphRefreshService(store, httpClient: client);

    await expectLater(
      () => service.refreshRouteGraph(),
      throwsA(isA<RouteGraphLoadException>()),
    );
    expect(store.replaceCallCount, 0);
    expect(store.reloadCallCount, 0);
  });

  test('refreshRouteGraph preserves the prior graph when write fails', () async {
    final store = _FakeRouteGraphStore(replaceShouldThrow: true);
    final client = MockClient((request) async {
      return http.Response(
        '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.5}]}',
        200,
      );
    });

    final service = RouteGraphRefreshService(store, httpClient: client);

    await expectLater(
      () => service.refreshRouteGraph(),
      throwsA(isA<RouteGraphLoadException>()),
    );
    expect(store.replaceCallCount, 1);
    expect(store.reloadCallCount, 0);
  });

  test('refreshRouteGraph preserves the prior graph when reload fails', () async {
    final store = _FakeRouteGraphStore(reloadShouldThrow: true);
    final client = MockClient((request) async {
      return http.Response(
        '{"elements":[{"type":"node","id":1,"lat":-41.5,"lon":146.5}]}',
        200,
      );
    });

    final service = RouteGraphRefreshService(store, httpClient: client);

    await expectLater(
      () => service.refreshRouteGraph(),
      throwsA(isA<RouteGraphLoadException>()),
    );
    expect(store.replaceCallCount, 1);
    expect(store.reloadCallCount, 1);
  });
}

const _expectedQuery = '''
[out:json];
way["highway"](-43.643,143.833,-39.579,148.482);
out body;
>;
out skel qt;
''';

class _FakeRouteGraphStore implements RouteGraphStore {
  _FakeRouteGraphStore({
    this.replaceShouldThrow = false,
    this.reloadShouldThrow = false,
  });

  final bool replaceShouldThrow;
  final bool reloadShouldThrow;
  int replaceCallCount = 0;
  int reloadCallCount = 0;

  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async {
    reloadCallCount += 1;
    if (reloadShouldThrow) {
      throw const RouteGraphLoadException('reload failed');
    }
    return trip_routing.TripService();
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {
    replaceCallCount += 1;
    if (replaceShouldThrow) {
      throw const RouteGraphLoadException('replace failed');
    }
  }

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}
