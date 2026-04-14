import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

class TrackImportResult {
  const TrackImportResult({
    required this.tracks,
    required this.importedCount,
    required this.replacedCount,
    required this.unchangedCount,
    required this.nonTasmanianCount,
    required this.errorSkippedCount,
    this.noGpxFilesFound = false,
    this.warning,
  });

  final List<GpxTrack> tracks;
  final int importedCount;
  final int replacedCount;
  final int unchangedCount;
  final int nonTasmanianCount;
  final int errorSkippedCount;
  final bool noGpxFilesFound;
  final String? warning;
}

class _FileOrganizationResult {
  const _FileOrganizationResult({
    required this.finalPath,
    this.manualReviewReason,
  });

  final String finalPath;
  final String? manualReviewReason;

  bool get requiresManualReview => manualReviewReason != null;
}

class GpxImporter {
  static const _tasmaniaLatMin = -44.0;
  static const _tasmaniaLatMax = -39.0;
  static const _tasmaniaLngMin = 143.0;
  static const _tasmaniaLngMax = 149.0;
  static String? debugTracksFolderOverride;
  static String? debugTasmaniaFolderOverride;
  static String? debugRoutesFolderOverride;

  String tracksFolder;
  String tasmaniaFolder;
  String routesFolder;

  GpxImporter({
    String? tracksFolder,
    String? tasmaniaFolder,
    String? routesFolder,
  }) : tracksFolder = tracksFolder ?? _defaultTracksFolder(),
       tasmaniaFolder = tasmaniaFolder ?? _defaultTasmaniaFolder(),
       routesFolder = routesFolder ?? _defaultRoutesFolder();

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

  static String _defaultRoutesFolder() {
    if (debugRoutesFolderOverride != null) {
      return debugRoutesFolderOverride!;
    }
    final home = Platform.environment['HOME'] ?? '';
    return '$home/Documents/Bushwalking/Routes';
  }

  String getTracksFolder() => tracksFolder;
  String getTasmaniaFolder() => tasmaniaFolder;
  String getRoutesFolder() => routesFolder;

  String getImportLogPath() {
    final root = Directory(tracksFolder).parent.path;
    return '$root${Platform.pathSeparator}import.log';
  }

  Future<bool> moveReplacementFile({
    required String sourcePath,
    required GpxTrack replacementTrack,
    required Future<void> Function() applyDatabaseReplacement,
  }) async {
    final sourceFile = File(sourcePath);
    final destinationPath = _resolveReplacementDestinationPath(
      sourcePath,
      replacementTrack,
    );
    final destinationFile = File(destinationPath);

    if (sourcePath != destinationPath && destinationFile.existsSync()) {
      final destinationTrack = parseGpxFile(destinationPath);
      if (destinationTrack == null ||
          !_isSameLogicalMatch(destinationTrack, replacementTrack)) {
        await _appendImportLog(sourcePath, 'Overwrite verification failed');
        return false;
      }
    }

    final backupPath = '$destinationPath.__bak';
    final backupFile = File(backupPath);
    var moved = false;

    try {
      if (sourcePath != destinationPath) {
        if (destinationFile.existsSync()) {
          await destinationFile.copy(backupPath);
          await destinationFile.delete();
        }
        await sourceFile.rename(destinationPath);
        moved = true;
      }

      await applyDatabaseReplacement();
      if (backupFile.existsSync()) {
        await backupFile.delete();
      }
      return true;
    } catch (_) {
      if (moved) {
        final movedFile = File(destinationPath);
        if (movedFile.existsSync()) {
          await movedFile.rename(sourcePath);
        }
      }
      if (backupFile.existsSync()) {
        if (destinationFile.existsSync()) {
          await destinationFile.delete();
        }
        await backupFile.rename(destinationPath);
      }
      await _appendImportLog(
        sourcePath,
        'Replacement rollback after database failure',
      );
      return false;
    }
  }

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
      final segments = _extractAllSegments(doc);
      final contentHash = sha256.convert(bytes).toString();

      return GpxTrack(
        contentHash: contentHash,
        trackName: trackName,
        trackDate: trackDate,
        gpxFile: content,
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson(segments),
        startDateTime: startDateTime,
        endDateTime: endDateTime,
      );
    } catch (e) {
      return null;
    }
  }

  List<List<LatLng>> _extractAllSegments(XmlDocument doc) {
    final segments = <List<LatLng>>[];

    final trackSegments = doc.findAllElements('trkseg').toList(growable: false);
    if (trackSegments.isNotEmpty) {
      for (final trkseg in trackSegments) {
        final segment = <LatLng>[];
        for (final trkpt in trkseg.findElements('trkpt')) {
          final latStr = trkpt.getAttribute('lat');
          final lonStr = trkpt.getAttribute('lon');

          if (latStr != null && lonStr != null) {
            final lat = double.tryParse(latStr);
            final lon = double.tryParse(lonStr);
            if (lat != null && lon != null) {
              segment.add(LatLng(lat, lon));
            }
          }
        }
        if (segment.isNotEmpty) {
          segments.add(segment);
        }
      }
    } else {
      final routeSegment = <LatLng>[];
      for (final rtept in doc.findAllElements('rtept')) {
        final latStr = rtept.getAttribute('lat');
        final lonStr = rtept.getAttribute('lon');

        if (latStr != null && lonStr != null) {
          final lat = double.tryParse(latStr);
          final lon = double.tryParse(lonStr);
          if (lat != null && lon != null) {
            routeSegment.add(LatLng(lat, lon));
          }
        }
      }
      if (routeSegment.isNotEmpty) {
        segments.add(routeSegment);
      }
    }

    return segments;
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
    final point = _firstPointElement(doc);
    if (point == null) return null;

    final time = point.findElements('time').firstOrNull;
    if (time == null) return null;

    try {
      return DateTime.parse(time.innerText).toLocal();
    } catch (e) {
      return null;
    }
  }

  DateTime? _extractEndDateTime(XmlDocument doc) {
    DateTime? latest;
    for (final point in _allPointElements(doc)) {
      final time = point.findElements('time').firstOrNull;
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

  String _basename(String filePath) {
    return filePath.split(Platform.pathSeparator).last;
  }

  String _canonicalFilename(String filePath, DateTime? fallbackDate) {
    final originalName = _basename(filePath);
    if (_isCanonicalFilename(originalName)) {
      return originalName;
    }

    final originalStem = _basenameWithoutExtension(filePath);
    final dateOverride = _extractDateOverrideFromFilename(originalStem);
    final stemWithoutDate = dateOverride.stemWithoutDate.trim().isEmpty
        ? originalStem
        : dateOverride.stemWithoutDate.trim();
    final normalizedStem = _normalizeFilenameStem(stemWithoutDate);
    final chosenDate = dateOverride.date ?? fallbackDate;
    final formattedDate = chosenDate == null
        ? ''
        : '_(${_formatDateForFilename(chosenDate)})';
    final extension = '.${_basename(filePath).split('.').last.toLowerCase()}';
    final safeStem = normalizedStem.isEmpty ? 'track' : normalizedStem;
    return '$safeStem$formattedDate$extension';
  }

  bool _isCanonicalFilename(String filename) {
    return RegExp(
      r'^[a-z0-9]+(?:-[a-z0-9]+)*_\(\d{2}-\d{2}-\d{4}\)\.gpx$',
    ).hasMatch(filename);
  }

  ({DateTime? date, String stemWithoutDate}) _extractDateOverrideFromFilename(
    String stem,
  ) {
    final matches = RegExp(r'\(([^()]*)\)').allMatches(stem).toList();
    for (final match in matches.reversed) {
      final inside = match.group(1)?.trim() ?? '';
      final parsed = _tryParseFilenameDate(inside);
      if (parsed != null) {
        final without =
            '${stem.substring(0, match.start)} ${stem.substring(match.end)}';
        return (date: parsed, stemWithoutDate: without.trim());
      }
    }
    return (date: null, stemWithoutDate: stem);
  }

  DateTime? _tryParseFilenameDate(String value) {
    final iso = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})(?:[ T].*)?$',
    ).firstMatch(value);
    if (iso != null) {
      return DateTime(
        int.parse(iso.group(1)!),
        int.parse(iso.group(2)!),
        int.parse(iso.group(3)!),
      );
    }

    final dmy = RegExp(
      r'^(\d{2})-(\d{2})-(\d{4})(?:[ T].*)?$',
    ).firstMatch(value);
    if (dmy != null) {
      return DateTime(
        int.parse(dmy.group(3)!),
        int.parse(dmy.group(2)!),
        int.parse(dmy.group(1)!),
      );
    }

    return null;
  }

  String _normalizeFilenameStem(String value) {
    return value
        .toLowerCase()
        .replaceAll('.', '-')
        .replaceAll('&', '-')
        .replaceAll(',', '-')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  String _formatDateForFilename(DateTime date) {
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }

  ({double lat, double lng})? _extractFirstPoint(XmlDocument doc) {
    final point = _firstPointElement(doc);
    if (point == null) return null;

    final latStr = point.getAttribute('lat');
    final lonStr = point.getAttribute('lon');

    if (latStr == null || lonStr == null) return null;

    final lat = double.tryParse(latStr);
    final lng = double.tryParse(lonStr);

    if (lat == null || lng == null) return null;

    return (lat: lat, lng: lng);
  }

  XmlElement? _firstPointElement(XmlDocument doc) {
    final trkseg = doc.findAllElements('trkseg').firstOrNull;
    if (trkseg != null) {
      final trkpt = trkseg.findElements('trkpt').firstOrNull;
      if (trkpt != null) {
        return trkpt;
      }
    }
    return doc.findAllElements('rtept').firstOrNull;
  }

  Iterable<XmlElement> _allPointElements(XmlDocument doc) sync* {
    final trkpts = doc.findAllElements('trkpt');
    if (trkpts.isNotEmpty) {
      yield* trkpts;
      return;
    }
    yield* doc.findAllElements('rtept');
  }

  Future<TrackImportResult> importTracks({
    bool includeTasmaniaFolder = true,
    List<GpxTrack> existingTracks = const [],
    bool surfaceWarnings = true,
    bool resetIds = false,
  }) async {
    final tracks = <GpxTrack>[];
    final seenContentHashes = <String>{};
    final seenLogicalMatches = <String>{};
    final existingContentHashes = existingTracks
        .map((track) => track.contentHash)
        .where((hash) => hash.isNotEmpty)
        .toSet();
    var importedCount = 0;
    var replacedCount = 0;
    var unchangedCount = 0;
    var nonTasmanianCount = 0;
    var errorSkippedCount = 0;
    var logWriteFailed = false;

    final tracksDir = Directory(tracksFolder);
    final tasmaniaDir = Directory(tasmaniaFolder);
    final routesDir = Directory(routesFolder);

    if (!tracksDir.existsSync()) {
      await tracksDir.create(recursive: true);
    }

    if (!tasmaniaDir.existsSync()) {
      await tasmaniaDir.create(recursive: true);
    }

    if (!routesDir.existsSync()) {
      await routesDir.create(recursive: true);
    }

    final snapshot = <File>[];
    if (tracksDir.existsSync()) {
      snapshot.addAll(_snapshotDirectory(tracksDir));
    }

    if (includeTasmaniaFolder && tasmaniaDir.existsSync()) {
      snapshot.addAll(_snapshotDirectory(tasmaniaDir));
    }

    snapshot.sort((a, b) => a.path.compareTo(b.path));

    if (snapshot.isEmpty) {
      return const TrackImportResult(
        tracks: [],
        importedCount: 0,
        replacedCount: 0,
        unchangedCount: 0,
        nonTasmanianCount: 0,
        errorSkippedCount: 0,
        noGpxFilesFound: true,
      );
    }

    for (final file in snapshot) {
      if (await _isRouteFile(file.path)) {
        final routeTrack = parseGpxFile(file.path);
        final organization = await _organizeFile(
          file.path,
          destinationFolder: routesFolder,
          canonicalDate: routeTrack?.trackDate,
        );
        if (organization.requiresManualReview) {
          errorSkippedCount += 1;
          logWriteFailed = !await _appendImportLog(
            file.path,
            organization.manualReviewReason!,
          );
        }
        continue;
      }

      final track = parseGpxFile(file.path);
      if (track == null) {
        final parseFailureReason = _classifyParseFailure(file.path);
        errorSkippedCount += 1;
        logWriteFailed = !await _appendImportLog(file.path, parseFailureReason);
        continue;
      }

      final firstPoint = _getFirstPointFromFile(file.path);
      if (firstPoint == null) {
        errorSkippedCount += 1;
        logWriteFailed = !await _appendImportLog(
          file.path,
          'First track point unreadable',
        );
        continue;
      }

      if (!isTasmanian(firstPoint.lat, firstPoint.lng)) {
        await _organizeFile(
          file.path,
          destinationFolder: tracksFolder,
          canonicalDate: track.trackDate,
        );
        nonTasmanianCount += 1;
        continue;
      }

      final organization = await _organizeFile(
        file.path,
        destinationFolder: tasmaniaFolder,
        canonicalDate: track.trackDate,
      );
      if (organization.requiresManualReview) {
        errorSkippedCount += 1;
        logWriteFailed = !await _appendImportLog(
          file.path,
          organization.manualReviewReason!,
        );
        continue;
      }

      if (!seenContentHashes.add(track.contentHash) ||
          existingContentHashes.contains(track.contentHash)) {
        unchangedCount += 1;
        continue;
      }

      if (track.hasMetadataTrackDate && track.trackDate != null) {
        final logicalKey =
            '${track.trackName}|${track.trackDate!.toIso8601String()}';
        if (!seenLogicalMatches.add(logicalKey)) {
          errorSkippedCount += 1;
          logWriteFailed = !await _appendImportLog(
            file.path,
            'Same-operation logical-match conflict',
          );
          continue;
        }
        final existing = _findExistingLogicalMatch(existingTracks, track);
        if (existing != null && existing.contentHash != track.contentHash) {
          track.gpxTrackId = existing.gpxTrackId;
          replacedCount += 1;
          tracks.add(track);
          continue;
        }
      }

      importedCount += 1;
      tracks.add(track);
    }

    if (resetIds) {
      for (var i = 0; i < tracks.length; i++) {
        tracks[i].gpxTrackId = i + 1;
      }
    }

    return TrackImportResult(
      tracks: tracks,
      importedCount: importedCount,
      replacedCount: replacedCount,
      unchangedCount: unchangedCount,
      nonTasmanianCount: nonTasmanianCount,
      errorSkippedCount: errorSkippedCount,
      noGpxFilesFound: false,
      warning: errorSkippedCount > 0 && surfaceWarnings
          ? (logWriteFailed
                ? 'Some files need manual review. import.log could not be updated.'
                : 'Some files need manual review. See import.log.')
          : null,
    );
  }

  Future<bool> _appendImportLog(String filePath, String reason) async {
    try {
      final logFile = File(getImportLogPath());
      await logFile.writeAsString(
        '${DateTime.now().toIso8601String()} | $filePath | $reason\n',
        mode: FileMode.append,
        flush: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String _resolveReplacementDestinationPath(
    String sourcePath,
    GpxTrack replacementTrack,
  ) {
    final existingPath = _findExistingOrganizedLogicalMatchPath(
      replacementTrack,
    );
    if (existingPath != null) {
      return existingPath;
    }
    return '$tasmaniaFolder${Platform.pathSeparator}${_canonicalFilename(sourcePath, replacementTrack.trackDate)}';
  }

  String? _findExistingOrganizedLogicalMatchPath(GpxTrack replacementTrack) {
    try {
      final folder = Directory(tasmaniaFolder);
      if (!folder.existsSync()) {
        return null;
      }

      final candidates = folder
          .listSync()
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.gpx'))
          .map((file) => (path: file.path, track: parseGpxFile(file.path)))
          .where((entry) => entry.track != null)
          .where((entry) => _isSameLogicalMatch(entry.track!, replacementTrack))
          .map((entry) => entry.path)
          .toList();

      if (candidates.isEmpty) {
        return null;
      }

      candidates.sort();
      return candidates.first;
    } catch (_) {
      return null;
    }
  }

  Future<_FileOrganizationResult> _organizeFile(
    String sourcePath, {
    required String destinationFolder,
    DateTime? canonicalDate,
  }) async {
    final targetPath =
        '$destinationFolder${Platform.pathSeparator}${_canonicalFilename(sourcePath, canonicalDate)}';

    if (sourcePath == targetPath) {
      return _FileOrganizationResult(finalPath: sourcePath);
    }

    final targetFile = File(targetPath);
    if (targetFile.existsSync()) {
      return _FileOrganizationResult(
        finalPath: sourcePath,
        manualReviewReason: 'Destination path collision',
      );
    }

    try {
      final moved = await File(sourcePath).rename(targetPath);
      return _FileOrganizationResult(finalPath: moved.path);
    } catch (_) {
      return _FileOrganizationResult(
        finalPath: sourcePath,
        manualReviewReason: 'Permission denied moving file',
      );
    }
  }

  Future<bool> _isRouteFile(String filePath) async {
    try {
      final file = File(filePath);
      final content = await file.readAsString();
      final doc = XmlDocument.parse(content);
      return doc.findAllElements('trkpt').isEmpty &&
          doc.findAllElements('rtept').isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  bool _isSameLogicalMatch(GpxTrack a, GpxTrack b) {
    return a.hasMetadataTrackDate &&
        b.hasMetadataTrackDate &&
        a.trackName == b.trackName &&
        a.trackDate == b.trackDate;
  }

  GpxTrack? _findExistingLogicalMatch(
    List<GpxTrack> existingTracks,
    GpxTrack incoming,
  ) {
    final matches = existingTracks
        .where(
          (track) =>
              track.hasMetadataTrackDate &&
              track.trackDate == incoming.trackDate &&
              track.trackName == incoming.trackName,
        )
        .toList();
    if (matches.isEmpty) {
      return null;
    }
    matches.sort((a, b) => b.gpxTrackId.compareTo(a.gpxTrackId));
    return matches.first;
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

  String _classifyParseFailure(String filePath) {
    try {
      final file = File(filePath);
      final content = file.readAsStringSync();
      final doc = XmlDocument.parse(content);
      return _extractFirstPoint(doc) == null
          ? 'No track points found'
          : 'Invalid or unreadable GPX';
    } catch (_) {
      return 'Invalid or unreadable GPX';
    }
  }
}
