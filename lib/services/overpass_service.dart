import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:peak_bagger/models/peak.dart';

class OverpassService {
  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  // Spatial Extent (Bounding Box):
  // - Longitude: 143.833° to 148.482° East
  // - Latitude: -43.643° to -39.579° South

  static const String _query = '''
[out:json][timeout:60];
(
  node["natural"="peak"]["name"](-43.643,143.833,-39.579,148.482);
);
out center;
''';

  Future<List<Peak>> fetchTasmaniaPeaks() async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': _query},
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch peaks: ${response.statusCode}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      final elements = data['elements'] as List<dynamic>;

      final peaks = <Peak>[];
      for (final element in elements) {
        try {
          final peak = Peak.fromOverpass(element as Map<String, dynamic>);
          if (peak.name != 'Unknown') {
            peaks.add(peak);
          }
        } catch (e) {
          continue;
        }
      }

      return peaks;
    } catch (e) {
      rethrow;
    }
  }
}
