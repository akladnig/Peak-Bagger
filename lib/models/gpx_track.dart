import 'dart:convert';

import 'package:latlong2/latlong.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class GpxTrack {
  @Id()
  int gpxTrackId = 0;

  String contentHash;
  String trackName;
  DateTime? trackDate;
  String trackPoints;
  DateTime? startDateTime;
  DateTime? endDateTime;
  double? distance;
  double? ascent;
  int? totalTimeMillis;
  int trackColour;

  GpxTrack({
    this.gpxTrackId = 0,
    required this.contentHash,
    required this.trackName,
    this.trackDate,
    this.trackPoints = '[]',
    this.startDateTime,
    this.endDateTime,
    this.distance,
    this.ascent,
    this.totalTimeMillis,
    this.trackColour = 0xFFa726bc,
  });

  static GpxTrack fromMap(Map<String, dynamic> map) {
    return GpxTrack(
      gpxTrackId: map['gpxTrackId'] as int? ?? 0,
      contentHash: map['contentHash'] as String? ?? '',
      trackName: map['trackName'] as String? ?? '',
      trackDate: map['trackDate'] != null
          ? DateTime.tryParse(map['trackDate'] as String)
          : null,
      trackPoints: map['trackPoints'] as String? ?? '[]',
      startDateTime: map['startDateTime'] != null
          ? DateTime.tryParse(map['startDateTime'] as String)
          : null,
      endDateTime: map['endDateTime'] != null
          ? DateTime.tryParse(map['endDateTime'] as String)
          : null,
      distance: map['distance'] as double?,
      ascent: map['ascent'] as double?,
      totalTimeMillis: map['totalTimeMillis'] as int?,
      trackColour: map['trackColour'] as int? ?? 0xFFa726bc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'gpxTrackId': gpxTrackId,
      'contentHash': contentHash,
      'trackName': trackName,
      'trackDate': trackDate?.toIso8601String(),
      'trackPoints': trackPoints,
      'startDateTime': startDateTime?.toIso8601String(),
      'endDateTime': endDateTime?.toIso8601String(),
      'distance': distance,
      'ascent': ascent,
      'totalTimeMillis': totalTimeMillis,
      'trackColour': trackColour,
    };
  }

  bool get hasMetadataTrackDate => startDateTime != null;

  List<List<LatLng>> getSegments() {
    try {
      return _decodeSegments(trackPoints);
    } catch (e) {
      return const [];
    }
  }

  List<LatLng> getPoints() {
    return getSegments().expand((segment) => segment).toList(growable: false);
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
}
