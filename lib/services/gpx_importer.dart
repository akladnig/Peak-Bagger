import 'dart:io';
import 'package:xml/xml.dart';
import 'package:peak_bagger/models/gpx_track.dart';

class GpxImporter {
  static const _tasmaniaLatMin = -44.0;
  static const _tasmaniaLatMax = -39.0;
  static const _tasmaniaLngMin = 143.0;
  static const _tasmaniaLngMax = 148.0;

  String tracksFolder;
  String tasmaniaFolder;

  GpxImporter({String? tracksFolder, String? tasmaniaFolder})
    : tracksFolder = tracksFolder ?? _defaultTracksFolder(),
      tasmaniaFolder = tasmaniaFolder ?? _defaultTasmaniaFolder();

  static String _defaultTracksFolder() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Documents/Bushwalking/Tracks';
  }

  static String _defaultTasmaniaFolder() {
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Documents/Bushwalking/Tracks/Tasmania';
  }

  String getTracksFolder() => tracksFolder;
  String getTasmaniaFolder() => tasmaniaFolder;

  bool isTasmanian(double lat, double lng) {
    return lat >= _tasmaniaLatMin &&
        lat <= _tasmaniaLatMax &&
        lng >= _tasmaniaLngMin &&
        lng <= _tasmaniaLngMax;
  }

  GpxTrack? parseGpxFile(String filePath) {
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        return null;
      }

      final content = file.readAsStringSync();
      final doc = XmlDocument.parse(content);

      final trackName = _extractTrackName(doc);
      final firstPoint = _extractFirstPoint(doc);

      if (firstPoint == null) {
        return null;
      }

      final dateStr = _extractDate(doc);
      final formattedName = _formatTrackName(trackName, dateStr);
      final trackPoints = _extractAllPointsAsJson(doc);

      return GpxTrack(
        fileLocation: filePath,
        trackName: formattedName,
        trackPoints: trackPoints,
      );
    } catch (e) {
      return null;
    }
  }

  String _extractAllPointsAsJson(XmlDocument doc) {
    final buffer = StringBuffer('[');
    var first = true;

    for (final trkseg in doc.findAllElements('trkseg')) {
      for (final trkpt in trkseg.findElements('trkpt')) {
        final latStr = trkpt.getAttribute('lat');
        final lonStr = trkpt.getAttribute('lon');

        if (latStr != null && lonStr != null) {
          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);
          if (lat != null && lon != null) {
            if (!first)
              buffer.write(',[');
            else
              buffer.write('[');
            buffer.write('$lat,$lon]');
            first = false;
          }
        }
      }
    }

    buffer.write(']');
    return buffer.toString();
  }

  String? _extractTrackName(XmlDocument doc) {
    final nameElement = doc.findAllElements('name').firstOrNull;
    if (nameElement != null) {
      return nameElement.innerText;
    }
    return null;
  }

  String? _extractDate(XmlDocument doc) {
    final trkseg = doc.findAllElements('trkseg').firstOrNull;
    if (trkseg == null) return null;

    final trkpt = trkseg.findElements('trkpt').firstOrNull;
    if (trkpt == null) return null;

    final time = trkpt.findElements('time').firstOrNull;
    if (time == null) return null;

    try {
      final dt = DateTime.parse(time.innerText);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }

  String _formatTrackName(String? name, String? date) {
    final baseName = name ?? 'unknown';
    if (date != null) {
      return '$date-$baseName';
    }
    return baseName;
  }

  ({double lat, double lng})? _extractFirstPoint(XmlDocument doc) {
    final trkseg = doc.findAllElements('trkseg').firstOrNull;
    if (trkseg == null) return null;

    final trkpt = trkseg.findElements('trkpt').firstOrNull;
    if (trkpt == null) return null;

    final latStr = trkpt.getAttribute('lat');
    final lonStr = trkpt.getAttribute('lon');

    if (latStr == null || lonStr == null) return null;

    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lonStr);

    if (lat == null || lng == null) return null;

    return (lat: lat, lng: lng);
  }

  Future<List<GpxTrack>> importTracks() async {
    final tracks = <GpxTrack>[];

    final tracksDir = Directory(tracksFolder);
    final tasmaniaDir = Directory(tasmaniaFolder);

    if (!tracksDir.existsSync()) {
      await tracksDir.create(recursive: true);
    }

    if (!tasmaniaDir.existsSync()) {
      await tasmaniaDir.create(recursive: true);
    }

    if (tracksDir.existsSync()) {
      await _scanDirectory(tracksDir, tracks);
    }

    if (tasmaniaDir.existsSync()) {
      await _scanDirectory(tasmaniaDir, tracks);
    }

    return tracks;
  }

  Future<void> _scanDirectory(Directory dir, List<GpxTrack> tracks) async {
    try {
      final files = dir.listSync();
      for (final entity in files) {
        if (entity is File && entity.path.toLowerCase().endsWith('.gpx')) {
          final track = parseGpxFile(entity.path);
          if (track != null) {
            final firstPoint = _getFirstPointFromFile(entity.path);
            if (firstPoint != null &&
                isTasmanian(firstPoint.lat, firstPoint.lng)) {
              tracks.add(track);
            }
          }
        }
      }
    } catch (e) {
      // Skip directories we can't read
    }
  }

  ({double lat, double lng})? _getFirstPointFromFile(String filePath) {
    try {
      final file = File(filePath);
      final content = file.readAsStringSync();
      final doc = XmlDocument.parse(content);
      return _extractFirstPoint(doc);
    } catch (e) {
      return null;
    }
  }
}
