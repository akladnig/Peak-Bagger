import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;

class GpxExportException implements Exception {
  const GpxExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class GpxExportPlan {
  const GpxExportPlan({required this.path, required this.contents});

  final String path;
  final String contents;
}

abstract class GpxExportFileSystem {
  bool exists(String path);

  Future<void> createDirectory(String path);

  Future<void> writeString(String path, String contents);
}

class IoGpxExportFileSystem implements GpxExportFileSystem {
  const IoGpxExportFileSystem();

  @override
  bool exists(String path) => File(path).existsSync();

  @override
  Future<void> createDirectory(String path) {
    return Directory(path).create(recursive: true);
  }

  @override
  Future<void> writeString(String path, String contents) {
    return File(path).writeAsString(contents, flush: true);
  }
}

typedef GpxPointElevationResolver = double? Function(LatLng point, int index);
typedef GpxDirectoryResolver = Directory Function();

class GpxExportService {
  GpxExportService({
    GpxDirectoryResolver? trackDownloadsDirectoryResolver,
    GpxDirectoryResolver? routeExportsDirectoryResolver,
    GpxExportFileSystem? fileSystem,
    GpxPointElevationResolver? routePointElevationResolver,
  }) : _trackDownloadsDirectoryResolver =
           trackDownloadsDirectoryResolver ?? _defaultTrackDownloadsDirectory,
       _routeExportsDirectoryResolver =
           routeExportsDirectoryResolver ?? _defaultRouteExportsDirectory,
       _fileSystem = fileSystem ?? const IoGpxExportFileSystem(),
       _routePointElevationResolver = routePointElevationResolver;

  final GpxDirectoryResolver _trackDownloadsDirectoryResolver;
  final GpxDirectoryResolver _routeExportsDirectoryResolver;
  final GpxExportFileSystem _fileSystem;
  final GpxPointElevationResolver? _routePointElevationResolver;

  GpxExportPlan planTrackExport(GpxTrack track) {
    final stem = _sanitizeTrackStem(track.trackName);
    if (track.gpxFile.isEmpty) {
      throw const GpxExportException('Track GPX payload is empty.');
    }

    final directory = _trackDownloadsDirectoryResolver();
    return GpxExportPlan(
      path: p.join(directory.path, '$stem.gpx'),
      contents: track.gpxFile,
    );
  }

  GpxExportPlan planRouteExport(app_route.Route route) {
    final stem = _sanitizeRouteStem(route.name);
    if (stem.isEmpty) {
      throw const GpxExportException('Route name is required.');
    }
    if (route.gpxRoute.isEmpty) {
      throw const GpxExportException('Route point list is empty.');
    }

    final directory = _routeExportsDirectoryResolver();
    return GpxExportPlan(
      path: p.join(directory.path, '$stem.gpx'),
      contents: _buildRouteGpx(route: route, stem: stem),
    );
  }

  bool fileExists(GpxExportPlan plan) => _fileSystem.exists(plan.path);

  Future<String> writeExport(GpxExportPlan plan) async {
    await _fileSystem.createDirectory(p.dirname(plan.path));
    await _fileSystem.writeString(plan.path, plan.contents);
    return plan.path;
  }

  String _buildRouteGpx({required app_route.Route route, required String stem}) {
    final buffer = StringBuffer()
      ..write(
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..write('<metadata><author><name>Adrian Kladnig</name></author></metadata>')
      ..write('<rte><name>${_escapeXml(stem)}</name>');

    for (var index = 0; index < route.gpxRoute.length; index++) {
      final point = route.gpxRoute[index];
      buffer.write(
        '<rtept lat="${_formatCoordinate(point.latitude)}" lon="${_formatCoordinate(point.longitude)}">',
      );
      final elevation = _routePointElevationResolver?.call(point, index);
      if (elevation != null) {
        buffer.write('<ele>${_formatElevation(elevation)}</ele>');
      }
      buffer.write('</rtept>');
    }

    buffer.write('</rte></gpx>');
    return buffer.toString();
  }

  String _sanitizeTrackStem(String value) {
    final sanitized = _sanitizeStem(value);
    return sanitized.isEmpty ? 'track-export' : sanitized;
  }

  String _sanitizeRouteStem(String value) {
    return _sanitizeStem(value);
  }

  String _sanitizeStem(String value) {
    var stem = value.trim();
    stem = stem.replaceAll(RegExp(r'[\s/\\]+'), '-');
    stem = stem.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    stem = stem.replaceAll(RegExp(r'-+'), '-');
    stem = stem.replaceAll(RegExp(r'^-+|-+$'), '');
    stem = stem.replaceAll(RegExp(r'^\.+|\.+$'), '');
    return stem;
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(8);
  }

  String _formatElevation(double value) {
    return value.toString();
  }

  String _escapeXml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static Directory _defaultTrackDownloadsDirectory() {
    return Directory(p.join(_resolveHomeDirectory(), 'Downloads'));
  }

  static Directory _defaultRouteExportsDirectory() {
    return Directory(
      p.join(_resolveHomeDirectory(), 'Documents', 'Bushwalking', 'routes'),
    );
  }

  static String _resolveHomeDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return home;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return userProfile;
    }

    throw const GpxExportException('Unable to resolve home directory.');
  }
}
