import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';
import 'package:peak_bagger/models/peak.dart';

import '../core/constants.dart';

@Entity()
class GpxTrack {
  static const minDisplayZoom = MapConstants.trackMinZoom;
  static const maxDisplayZoom = MapConstants.trackMaxZoom;

  @Id(assignable: true)
  int gpxTrackId = 0;

  final peaks = ToMany<Peak>();

  String contentHash;
  String trackName;
  @Property(type: PropertyType.dateUtc)
  DateTime? trackDate;
  String gpxFile;
  String gpxFileRepaired;
  String filteredTrack;
  String displayTrackPointsByZoom;
  @Property(type: PropertyType.dateUtc)
  DateTime? startDateTime;
  @Property(type: PropertyType.dateUtc)
  DateTime? endDateTime;
  double distance2d;
  double distance3d;
  double distanceToPeak;
  double distanceFromPeak;
  double lowestElevation;
  double highestElevation;
  double descent;
  double startElevation;
  double endElevation;
  String elevationProfile;
  double? ascent;
  int? totalTimeMillis;
  int? movingTime;
  int? restingTime;
  int? pausedTime;
  int trackColour;
  bool peakCorrelationProcessed;
  bool managedPlacementPending;
  String? managedRelativePath;

  GpxTrack({
    this.gpxTrackId = 0,
    required this.contentHash,
    required this.trackName,
    this.trackDate,
    this.gpxFile = '',
    this.gpxFileRepaired = '',
    this.filteredTrack = '',
    this.displayTrackPointsByZoom = '{}',
    this.startDateTime,
    this.endDateTime,
    this.distance2d = 0,
    this.distance3d = 0,
    this.distanceToPeak = 0,
    this.distanceFromPeak = 0,
    this.lowestElevation = 0,
    this.highestElevation = 0,
    this.descent = 0,
    this.startElevation = 0,
    this.endElevation = 0,
    this.elevationProfile = '[]',
    this.ascent,
    this.totalTimeMillis,
    this.movingTime,
    this.restingTime,
    this.pausedTime,
    this.trackColour = 0xFFa726bc,
    this.peakCorrelationProcessed = false,
    this.managedPlacementPending = false,
    this.managedRelativePath,
  });

  static GpxTrack fromMap(Map<String, dynamic> map) {
    return GpxTrack(
      gpxTrackId: map['gpxTrackId'] as int? ?? 0,
      contentHash: map['contentHash'] as String? ?? '',
      trackName: map['trackName'] as String? ?? '',
      trackDate: map['trackDate'] != null
          ? DateTime.tryParse(map['trackDate'] as String)
          : null,
      gpxFile: map['gpxFile'] as String? ?? '',
      gpxFileRepaired: map['gpxFileRepaired'] as String? ?? '',
      filteredTrack: map['filteredTrack'] as String? ?? '',
      displayTrackPointsByZoom:
          map['displayTrackPointsByZoom'] as String? ?? '{}',
      startDateTime: map['startDateTime'] != null
          ? DateTime.tryParse(map['startDateTime'] as String)
          : null,
      endDateTime: map['endDateTime'] != null
          ? DateTime.tryParse(map['endDateTime'] as String)
          : null,
      distance2d: _doubleFromMap(map['distance2d']),
      distance3d: _doubleFromMap(map['distance3d']),
      distanceToPeak: _doubleFromMap(map['distanceToPeak']),
      distanceFromPeak: _doubleFromMap(map['distanceFromPeak']),
      lowestElevation: _doubleFromMap(map['lowestElevation']),
      highestElevation: _doubleFromMap(map['highestElevation']),
      descent: _doubleFromMap(map['descent']),
      startElevation: _doubleFromMap(map['startElevation']),
      endElevation: _doubleFromMap(map['endElevation']),
      elevationProfile: map['elevationProfile'] as String? ?? '[]',
      ascent: map['ascent'] as double?,
      totalTimeMillis: map['totalTimeMillis'] as int?,
      movingTime: map['movingTime'] as int?,
      restingTime: map['restingTime'] as int?,
      pausedTime: map['pausedTime'] as int?,
      trackColour: map['trackColour'] as int? ?? 0xFFa726bc,
      peakCorrelationProcessed:
          map['peakCorrelationProcessed'] as bool? ?? false,
      managedPlacementPending: map['managedPlacementPending'] as bool? ?? false,
      managedRelativePath: map['managedRelativePath'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gpxTrackId': gpxTrackId,
      'contentHash': contentHash,
      'trackName': trackName,
      'trackDate': trackDate?.toIso8601String(),
      'gpxFile': gpxFile,
      'gpxFileRepaired': gpxFileRepaired,
      'filteredTrack': filteredTrack,
      'displayTrackPointsByZoom': displayTrackPointsByZoom,
      'startDateTime': startDateTime?.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'distance2d': distance2d,
      'distance3d': distance3d,
      'distanceToPeak': distanceToPeak,
      'distanceFromPeak': distanceFromPeak,
      'lowestElevation': lowestElevation,
      'highestElevation': highestElevation,
      'descent': descent,
      'startElevation': startElevation,
      'endElevation': endElevation,
      'elevationProfile': elevationProfile,
      'ascent': ascent,
      'totalTimeMillis': totalTimeMillis,
      'movingTime': movingTime,
      'restingTime': restingTime,
      'pausedTime': pausedTime,
      'trackColour': trackColour,
      'peakCorrelationProcessed': peakCorrelationProcessed,
      'managedPlacementPending': managedPlacementPending,
      'managedRelativePath': managedRelativePath,
    };
  }

  bool get hasMetadataTrackDate => startDateTime != null;

  List<List<LatLng>> getSegments() {
    return getSegmentsForZoom(MapConstants.defaultZoom.toInt());
  }

  List<List<LatLng>> getSegmentsForZoom(int zoom) {
    final caches = decodeDisplayTrackPointsByZoom(displayTrackPointsByZoom);
    if (caches.isEmpty) {
      return const [];
    }
    final clampedZoom = zoom.clamp(MapConstants.trackMinZoom, MapConstants.trackMaxZoom);
    return caches[clampedZoom] ?? const [];
  }

  List<LatLng> getPoints() {
    return getSegments().expand((segment) => segment).toList(growable: false);
  }

  bool hasValidOptimizedDisplayData() {
    if (gpxFile.isEmpty) {
      return false;
    }

    final caches = decodeDisplayTrackPointsByZoom(displayTrackPointsByZoom);
    if (caches.isEmpty) {
      return false;
    }

    for (var zoom = minDisplayZoom; zoom <= maxDisplayZoom; zoom++) {
      if (!caches.containsKey(zoom)) {
        return false;
      }
    }

    return true;
  }

  static Map<int, List<List<LatLng>>> decodeDisplayTrackPointsByZoom(
    String jsonString,
  ) {
    if (jsonString.isEmpty || jsonString == '{}') {
      return const {};
    }

    final decoded = json.decode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      return const {};
    }

    final caches = <int, List<List<LatLng>>>{};
    for (final entry in decoded.entries) {
      final zoom = int.tryParse(entry.key);
      if (zoom == null || entry.value is! List) {
        continue;
      }
      caches[zoom] = _decodeSegments(json.encode(entry.value));
    }
    return caches;
  }

  static List<List<LatLng>> _decodeSegments(String jsonString) {
    if (jsonString.isEmpty || jsonString == '[]') {
      return const [];
    }

    final dynamic decoded = json.decode(jsonString);
    if (decoded is! List) {
      return const [];
    }

    final segments = <List<LatLng>>[];
    for (final segment in decoded) {
      if (segment is! List) continue;
      final latLngs = <LatLng>[];
      for (final point in segment) {
        if (point is! List || point.length != 2) continue;
        final lat = (point[0] as num?)?.toDouble();
        final lng = (point[1] as num?)?.toDouble();
        if (lat != null && lng != null) {
          latLngs.add(LatLng(lat, lng));
        }
      }
      if (latLngs.isNotEmpty) {
        segments.add(latLngs);
      }
    }

    return segments;
  }

  static double _doubleFromMap(dynamic value) {
    return value is num ? value.toDouble() : 0;
  }
}
