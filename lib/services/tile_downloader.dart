import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class TileDownloader {
  static const _tracestrackBaseUrl = 'https://tile.tracestrack.com/topo__';
  static const _osmBaseUrl = 'https://tile.openstreetmap.org';
  static const _tracestrackApiKey = '8bd67b17be9041b60f241c2aa45ecf0d';

  static const _minZoom = 6;
  static const _maxZoom = 14;

  static const _tasmaniaBounds = {
    'minLat': -43.8,
    'maxLat': -40.5,
    'minLng': 144.0,
    'maxLng': 149.0,
  };

  static Future<String> get _documentsPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  static Future<String> getTilePath(String type, int zoom, int x, int y) async {
    final basePath = await _documentsPath;
    final folder = type == 'tracestrack' ? 'tiles_tracestrack' : 'tiles_osm';
    final ext = type == 'tracestrack' ? 'webp' : 'png';
    return '$basePath/$folder/$zoom/$x/$y.$ext';
  }

  static (int, int) _latLngToTile(double lat, double lng, int zoom) {
    final n = 1 << zoom;
    final x = ((lng + 180.0) / 360.0 * n).floor();
    final latRad = lat * 3.141592653589793 / 180.0;
    final y =
        ((1 - (latRad.abs() + latRad.sign.abs()) / 3.141592653589793) / 2 * n)
            .floor();
    return (x, y);
  }

  static String _getTileUrl(String type, int x, int y, int zoom) {
    if (type == 'tracestrack') {
      return '$_tracestrackBaseUrl/$zoom/$x/$y.webp?key=$_tracestrackApiKey';
    } else {
      return '$_osmBaseUrl/$zoom/$x/$y.png';
    }
  }

  static Future<bool> tileExists(String type, int zoom, int x, int y) async {
    final path = await getTilePath(type, zoom, x, y);
    return File(path).exists();
  }

  static Future<String> getTileUrl(String type, int zoom, int x, int y) async {
    return 'file://${await getTilePath(type, zoom, x, y)}';
  }

  static Future<void> downloadTiles(String type) async {
    final basePath = await _documentsPath;
    final folderPath = type == 'tracestrack'
        ? '$basePath/tiles_tracestrack'
        : '$basePath/tiles_osm';

    final directory = Directory(folderPath);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    for (int zoom = _minZoom; zoom <= _maxZoom; zoom++) {
      final (minX, maxY) = _latLngToTile(
        _tasmaniaBounds['minLat']!,
        _tasmaniaBounds['minLng']!,
        zoom,
      );
      final (maxX, minY) = _latLngToTile(
        _tasmaniaBounds['maxLat']!,
        _tasmaniaBounds['maxLng']!,
        zoom,
      );

      for (int x = minX; x <= maxX; x++) {
        for (int y = minY; y <= maxY; y++) {
          final tilePath = await getTilePath(type, zoom, x, y);
          final tileFile = File(tilePath);

          if (await tileFile.exists()) continue;

          try {
            final url = _getTileUrl(type, x, y, zoom);
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              await tileFile.writeAsBytes(response.bodyBytes);
            }
          } catch (e) {
            // Continue on error
          }
        }
      }
    }
  }

  static Future<void> downloadAllTiles() async {
    await downloadTiles('tracestrack');
    await downloadTiles('osm');
  }
}
