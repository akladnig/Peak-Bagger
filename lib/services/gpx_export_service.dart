import 'dart:io';

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/gpx_storage_destination_resolver.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/route_timing_service.dart';
import 'package:peak_bagger/services/track_peak_correlation_service.dart';

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

  GpxExportPlan copyWith({String? path, String? contents}) {
    return GpxExportPlan(
      path: path ?? this.path,
      contents: contents ?? this.contents,
    );
  }
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

typedef GpxPointElevationsResolver =
    Future<List<double?>> Function(List<LatLng> points);
typedef GpxDirectoryResolver = Directory Function();
typedef PeakListLoader = List<Peak> Function();
typedef PeakCorrelationThresholdLoader = Future<int> Function();

class GpxExportService {
  GpxExportService({
    GpxDirectoryResolver? trackDownloadsDirectoryResolver,
    GpxDirectoryResolver? routeExportsDirectoryResolver,
    GpxExportFileSystem? fileSystem,
    this._routePointElevationsResolver,
    this._peakListLoader,
    this._peakCorrelationThresholdLoader,
    GpxStorageDestinationResolver? storageDestinationResolver,
  }) : _trackDownloadsDirectoryResolver =
           trackDownloadsDirectoryResolver ?? _defaultTrackDownloadsDirectory,
       _routeExportsDirectoryResolver =
           routeExportsDirectoryResolver ?? _defaultRouteExportsDirectory,
       _fileSystem = fileSystem ?? const IoGpxExportFileSystem(),
       _storageDestinationResolver =
           storageDestinationResolver ?? GpxStorageDestinationResolver();

  final GpxDirectoryResolver _trackDownloadsDirectoryResolver;
  final GpxDirectoryResolver _routeExportsDirectoryResolver;
  final GpxExportFileSystem _fileSystem;
  final GpxPointElevationsResolver? _routePointElevationsResolver;
  final PeakListLoader? _peakListLoader;
  final PeakCorrelationThresholdLoader? _peakCorrelationThresholdLoader;
  final GpxStorageDestinationResolver _storageDestinationResolver;

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

  Future<GpxExportPlan> planRouteExport(app_route.Route route) async {
    final stem = _sanitizeRouteStem(route.name);
    if (stem.isEmpty) {
      throw const GpxExportException('Route name is required.');
    }
    if (route.gpxRoute.isEmpty) {
      throw const GpxExportException('Route point list is empty.');
    }

    final routesRoot = _routeExportsDirectoryResolver();
    final destination = await _storageDestinationResolver.resolveForPoint(
      route.gpxRoute.first,
    );
    if (destination == null) {
      throw const GpxExportException('Route export location is unsupported.');
    }
    final elevations = await _resolveRoutePointElevations(route);
    final correlatedPeaks = await _resolveCorrelatedPeaks(route);
    return GpxExportPlan(
      path: p.join(routesRoot.path, destination.relativeFolder, '$stem.gpx'),
      contents: _buildRouteGpx(
        route: route,
        stem: stem,
        elevations: elevations,
        correlatedPeaks: correlatedPeaks,
      ),
    );
  }

  bool fileExists(GpxExportPlan plan) => _fileSystem.exists(plan.path);

  GpxExportPlan planNewVersionExport(GpxExportPlan plan) {
    final directory = p.dirname(plan.path);
    final extension = p.extension(plan.path);
    final stem = p.basenameWithoutExtension(plan.path);
    final baseStem = _stripVersionSuffix(stem);

    var version = 1;
    while (true) {
      final candidatePath = p.join(directory, '${baseStem}_$version$extension');
      if (!_fileSystem.exists(candidatePath)) {
        return plan.copyWith(path: candidatePath);
      }
      version += 1;
    }
  }

  Future<String> writeExport(GpxExportPlan plan) async {
    await _fileSystem.createDirectory(p.dirname(plan.path));
    await _fileSystem.writeString(plan.path, plan.contents);
    return plan.path;
  }

  String _buildRouteGpx({
    required app_route.Route route,
    required String stem,
    required List<double?> elevations,
    required List<Peak> correlatedPeaks,
  }) {
    final timingProfile = _routeTimingProfile(route);
    final syntheticTimes = timingProfile.isEmpty
        ? const <DateTime>[]
        : buildSyntheticRouteTimes(timingProfile);
    final buffer = StringBuffer()
      ..write(
        '<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">',
      )
      ..write(
        '<metadata><author><name>Adrian Kladnig</name></author></metadata>',
      )
      ..write(_buildWaypointXml(correlatedPeaks))
      ..write(_buildRouteWaypointXml(route.routeWaypoints, correlatedPeaks))
      ..write('<rte><name>${_escapeXml(stem)}</name>');

    for (var index = 0; index < route.gpxRoute.length; index++) {
      final point = route.gpxRoute[index];
      buffer.write(
        '<rtept lat="${_formatCoordinate(point.latitude)}" lon="${_formatCoordinate(point.longitude)}">',
      );
      if (index < syntheticTimes.length) {
        buffer.write('<time>${_formatTimestamp(syntheticTimes[index])}</time>');
      }
      final elevation = index < elevations.length ? elevations[index] : null;
      if (elevation != null) {
        buffer.write('<ele>${_formatElevation(elevation)}</ele>');
      }
      buffer.write('</rtept>');
    }

    buffer.write('</rte></gpx>');
    return buffer.toString();
  }

  List<int> _routeTimingProfile(app_route.Route route) {
    final storedProfile = decodeRouteTimingProfile(route.routeTimingProfileJson);
    if (storedProfile.length == route.gpxRoute.length && storedProfile.isNotEmpty) {
      return storedProfile;
    }

    return buildNaismithProfile(
      points: route.gpxRoute,
      elevations: route.gpxRouteElevations,
    );
  }

  String _buildWaypointXml(List<Peak> peaks) {
    if (peaks.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    for (final peak in peaks) {
      buffer.write(
        '<wpt lat="${_formatCoordinate(peak.latitude)}" lon="${_formatCoordinate(peak.longitude)}">',
      );
      if (peak.elevation != null) {
        buffer.write('<ele>${peak.elevation!.round()}</ele>');
      }
      buffer.write('<name>${_escapeXml(peak.name)}</name></wpt>');
    }
    return buffer.toString();
  }

  String _buildRouteWaypointXml(
    List<RouteWaypoint> waypoints,
    List<Peak> correlatedPeaks,
  ) {
    if (waypoints.isEmpty) {
      return '';
    }

    final correlatedKeys = <String>{
      for (final peak in correlatedPeaks)
        _normalizedCoordinateKey(peak.latitude, peak.longitude),
    };

    final buffer = StringBuffer();
    for (final waypoint in waypoints) {
      final normalizedKey = _normalizedCoordinateKey(
        waypoint.latitude,
        waypoint.longitude,
      );
      if (correlatedKeys.contains(normalizedKey)) {
        continue;
      }

      buffer.write(
        '<wpt lat="${_formatCoordinate(waypoint.latitude)}" lon="${_formatCoordinate(waypoint.longitude)}">',
      );
      final label = waypoint.isPeakDerived
          ? (waypoint.peakName ?? waypoint.label)
          : waypoint.label;
      buffer.write('<name>${_escapeXml(label)}</name></wpt>');
    }
    return buffer.toString();
  }

  Future<List<double?>> _resolveRoutePointElevations(
    app_route.Route route,
  ) async {
    if (route.gpxRouteElevations.isNotEmpty &&
        route.gpxRouteElevations.any((value) => value != null)) {
      return List<double?>.generate(
        route.gpxRoute.length,
        (index) => index < route.gpxRouteElevations.length
            ? route.gpxRouteElevations[index]?.toDouble()
            : null,
        growable: false,
      );
    }

    final resolver = _routePointElevationsResolver;
    if (resolver == null) {
      return List<double?>.filled(route.gpxRoute.length, null, growable: false);
    }

    try {
      final elevations = await resolver(route.gpxRoute);
      if (elevations.length == route.gpxRoute.length) {
        return elevations;
      }

      return List<double?>.generate(route.gpxRoute.length, (index) {
        return index < elevations.length ? elevations[index] : null;
      }, growable: false);
    } catch (_) {
      return List<double?>.filled(route.gpxRoute.length, null, growable: false);
    }
  }

  Future<List<Peak>> _resolveCorrelatedPeaks(app_route.Route route) async {
    final peakListLoader = _peakListLoader;
    final thresholdLoader = _peakCorrelationThresholdLoader;
    if (peakListLoader == null || thresholdLoader == null) {
      return const [];
    }

    try {
      final threshold = await thresholdLoader();
      final correlationService = TrackPeakCorrelationService(
        peaks: peakListLoader(),
        thresholdMeters: threshold,
      );
      final correlationXml = _buildCorrelationRouteGpx(route.gpxRoute);
      return correlationService.matchPeaks(correlationXml);
    } catch (_) {
      return const [];
    }
  }

  String _buildCorrelationRouteGpx(List<LatLng> points) {
    final buffer = StringBuffer()..write('<gpx><rte>');
    for (final point in points) {
      buffer.write(
        '<rtept lat="${_formatCoordinate(point.latitude)}" lon="${_formatCoordinate(point.longitude)}"></rtept>',
      );
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

  String _stripVersionSuffix(String stem) {
    return stem.replaceFirst(RegExp(r'_(\d+)$'), '');
  }

  String _formatCoordinate(double value) {
    return value.toStringAsFixed(GpxConstants.precision);
  }

  String _normalizedCoordinateKey(double latitude, double longitude) {
    return '${_formatCoordinate(latitude)}|${_formatCoordinate(longitude)}';
  }

  String _formatElevation(double value) {
    return value.toString();
  }

  String _formatTimestamp(DateTime value) {
    return value.toUtc().toIso8601String().replaceFirst('.000Z', 'Z');
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
    return Directory(resolveBushwalkingRoutesPath());
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
