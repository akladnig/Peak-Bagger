import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:peak_bagger/models/peak.dart';

class OverpassService {
  static const List<String> _endpoints = [
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];

  Future<List<Peak>> fetchPeaks({
    required String region,
    required LatLngBounds bounds,
  }) async {
    Exception? lastError;
    for (final endpoint in _endpoints) {
      try {
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'data': _queryForBounds(bounds)},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body) as Map<String, dynamic>;
          final elements = data['elements'] as List<dynamic>;

          final peaks = <Peak>[];
          for (final element in elements) {
            try {
              final peak = Peak.fromOverpass(
                element as Map<String, dynamic>,
              ).copyWith(region: region);
              if (peak.name != 'Unknown') {
                peaks.add(peak);
              }
            } catch (e) {
              continue;
            }
          }
          return peaks;
        }
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        continue;
      }
    }
    throw lastError ??
        Exception('Failed to fetch peaks: no endpoints available');
  }

  String _queryForBounds(LatLngBounds bounds) {
    final south = bounds.southWest.latitude;
    final west = bounds.southWest.longitude;
    final north = bounds.northEast.latitude;
    final east = bounds.northEast.longitude;

    return '''
[out:json][timeout:60];
(
  node["natural"="peak"]["name"]($south,$west,$north,$east);
);
out center;
''';
  }
}
