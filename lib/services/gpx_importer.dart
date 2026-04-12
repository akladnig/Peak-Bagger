import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/models/gpx_track.dart';

class TrackImportResult {
  const TrackImportResult({
    required this.tracks,
    required this.importedCount,
    required this.replacedCount,
    required this.unchangedCount,
    required this.nonTasmanianCount,
    required this.errorSkippedCount,
    this.warning,
  });

  final List<GpxTrack> tracks;
  final int importedCount;
  final int replacedCount;
  final int unchangedCount;
  final int nonTasmanianCount;
  final int errorSkippedCount;
  final String? warning;
}

class GpxImporter {
  static const _tasmaniaLatMin = -44.0;
  static const _tasmaniaLatMax = -39.0;
  static const _tasmaniaLngMin = 143.0;
  static const _tasmaniaLngMax = 148.0;
  static String? debugTracksFolderOverride;
  static String? debugTasmaniaFolderOverride;

  String tracksFolder;
  String tasmaniaFolder;

  GpxImporter({String? tracksFolder, String? tasmaniaFolder})
    : tracksFolder = tracksFolder ?? _defaultTracksFolder(),
      tasmaniaFolder = tasmaniaFolder ?? _defaultTasmaniaFolder();

  static String _defaultTracksFolder() {
    if (debugTracksFolderOverride != null) {
      return debugTracksFolderOverride!;
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Documents/Bushwalking/Tracks';
  }

  static String _defaultTasmaniaFolder() {
    if (debugTasmaniaFolderOverride != null) {
      return debugTasmaniaFolderOverride!;
    }
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

      final bytes = file.readAsBytesSync();
      final content = utf8.decode(bytes);
      final doc = XmlDocument.parse(content);

      final trackName = _extractTrackName(doc, filePath);
      final firstPoint = _extractFirstPoint(doc);

      if (firstPoint == null) {
        return null;
      }

      final startDateTime = _extractStartDateTime(doc);
      final endDateTime = _extractEndDateTime(doc);
      final modified = file.lastModifiedSync();
      final trackDate = _normalizeTrackDate(startDateTime ?? modified);
      final trackPoints = _extractAllPointsAsJson(doc);
      final contentHash = sha256.convert(bytes).toString();

      return GpxTrack(
        contentHash: contentHash,
        trackName: trackName,
        trackDate: trackDate,
        trackPoints: trackPoints,
        startDateTime: startDateTime,
        endDateTime: endDateTime,
      );
    } catch (e) {
      return null;
    }
  }

  String _extractAllPointsAsJson(XmlDocument doc) {
    final segments = <List<List<double>>>[];

    for (final trkseg in doc.findAllElements('trkseg')) {
      final segment = <List<double>>[];
      for (final trkpt in trkseg.findElements('trkpt')) {
        final latStr = trkpt.getAttribute('lat');
        final lonStr = trkpt.getAttribute('lon');

        if (latStr != null && lonStr != null) {
          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);
          if (lat != null && lon != null) {
            segment.add([lat, lon]);
          }
        }
      }
      if (segment.isNotEmpty) {
        segments.add(segment);
      }
    }

    return jsonEncode(segments);
  }

  String _extractTrackName(XmlDocument doc, String filePath) {
    final nameElement = doc.findAllElements('name').firstOrNull;
    if (nameElement != null) {
      final text = nameElement.innerText.trim();
      if (text.isNotEmpty) {
        return text;
      }
    }
    return _basenameWithoutExtension(filePath);
  }

  DateTime? _extractStartDateTime(XmlDocument doc) {
    final trkseg = doc.findAllElements('trkseg').firstOrNull;
    if (trkseg == null) return null;

    final trkpt = trkseg.findElements('trkpt').firstOrNull;
    if (trkpt == null) return null;

    final time = trkpt.findElements('time').firstOrNull;
    if (time == null) return null;

    try {
      return DateTime.parse(time.innerText).toLocal();
    } catch (e) {
      return null;
    }
  }

  DateTime? _extractEndDateTime(XmlDocument doc) {
    DateTime? latest;
    for (final trkpt in doc.findAllElements('trkpt')) {
      final time = trkpt.findElements('time').firstOrNull;
      if (time == null) continue;
      try {
        latest = DateTime.parse(time.innerText).toLocal();
      } catch (_) {
        continue;
      }
    }
    return latest;
  }

  DateTime _normalizeTrackDate(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  String _basenameWithoutExtension(String filePath) {
    final separator = Platform.pathSeparator;
    final filename = filePath.split(separator).last;
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0) {
      return filename;
    }
    return filename.substring(0, dotIndex);
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

  Future<TrackImportResult> importTracks({
    bool includeTasmaniaFolder = true,
  }) async {
    final tracks = <GpxTrack>[];
    final seenContentHashes = <String>{};
    var unchangedCount = 0;
    var nonTasmanianCount = 0;
    var errorSkippedCount = 0;

    final tracksDir = Directory(tracksFolder);
    final tasmaniaDir = Directory(tasmaniaFolder);

    if (!tracksDir.existsSync()) {
      await tracksDir.create(recursive: true);
    }

    if (!tasmaniaDir.existsSync()) {
      await tasmaniaDir.create(recursive: true);
    }

    final snapshot = <File>[];
    if (tracksDir.existsSync()) {
      snapshot.addAll(_snapshotDirectory(tracksDir));
    }

    if (includeTasmaniaFolder && tasmaniaDir.existsSync()) {
      snapshot.addAll(_snapshotDirectory(tasmaniaDir));
    }

    snapshot.sort((a, b) => a.path.compareTo(b.path));

    for (final file in snapshot) {
      final track = parseGpxFile(file.path);
      if (track == null) {
        errorSkippedCount += 1;
        continue;
      }

      final firstPoint = _getFirstPointFromFile(file.path);
      if (firstPoint == null) {
        errorSkippedCount += 1;
        continue;
      }

      if (!isTasmanian(firstPoint.lat, firstPoint.lng)) {
        nonTasmanianCount += 1;
        continue;
      }

      if (!seenContentHashes.add(track.contentHash)) {
        unchangedCount += 1;
        continue;
      }

      tracks.add(track);
    }

    return TrackImportResult(
      tracks: tracks,
      importedCount: tracks.length,
      replacedCount: 0,
      unchangedCount: unchangedCount,
      nonTasmanianCount: nonTasmanianCount,
      errorSkippedCount: errorSkippedCount,
    );
  }

  List<File> _snapshotDirectory(Directory dir) {
    try {
      return dir
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.gpx'))
          .toList(growable: false);
    } catch (e) {
      return const [];
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
