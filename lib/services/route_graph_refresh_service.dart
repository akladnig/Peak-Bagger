import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

class RouteGraphRefreshResult {
  const RouteGraphRefreshResult({required this.elementCount});

  final int elementCount;
}

class RouteGraphRefreshService {
  RouteGraphRefreshService(
    this._store, {
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  final RouteGraphStore _store;
  final http.Client _httpClient;

  static const _overpassEndpoints = [
    'https://lz4.overpass-api.de/api/interpreter',
    'https://z.overpass-api.de/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  static const String _query = '''
[out:json];
way["highway"](-43.643,143.833,-39.579,148.482);
out body;
>;
out skel qt;
''';

  Future<RouteGraphRefreshResult> refreshRouteGraph() async {
    final rawJson = await _fetchSnapshot();
    final decodedJson = _decodeSnapshot(rawJson);

    final elements = decodedJson['elements'];
    if (elements is! List || elements.isEmpty) {
      throw const RouteGraphLoadException('No usable route graph elements.');
    }

    await _store.replaceSnapshot(rawJson);
    await _store.reload();

    return RouteGraphRefreshResult(elementCount: elements.length);
  }

  Map<String, dynamic> _decodeSnapshot(String rawJson) {
    try {
      final decodedJson = jsonDecode(rawJson);
      if (decodedJson is! Map<String, dynamic>) {
        throw const RouteGraphLoadException(
          'Expected decoded Overpass JSON object.',
        );
      }
      return decodedJson;
    } catch (error) {
      if (error is RouteGraphLoadException) {
        rethrow;
      }
      throw RouteGraphLoadException('Failed to decode route graph snapshot: $error');
    }
  }

  Future<String> _fetchSnapshot() async {
    Object? lastError;

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _httpClient.post(
          Uri.parse(endpoint),
          headers: const {
            'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
            'Accept': 'application/json',
            'User-Agent': 'peak-bagger/route-graph-refresh',
          },
          body: 'data=${Uri.encodeQueryComponent(_query)}',
        );

        if (response.statusCode != 200) {
          lastError = StateError('HTTP ${response.statusCode}');
          continue;
        }

        return response.body;
      } catch (error, stackTrace) {
        developer.log(
          'Route graph refresh failed for $endpoint',
          error: error,
          stackTrace: stackTrace,
        );
        lastError = error;
      }
    }

    throw RouteGraphLoadException('Failed to refresh route graph: $lastError');
  }
}

final routeGraphRefreshServiceProvider = Provider<RouteGraphRefreshService>((ref) {
  return RouteGraphRefreshService(ref.read(routeGraphStoreProvider));
});
