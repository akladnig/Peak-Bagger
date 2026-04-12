import 'package:objectbox/objectbox.dart';

@Entity()
class GpxTrack {
  @Id()
  int gpxTrackId = 0;

  String fileLocation;
  String trackName;
  String trackPoints;
  DateTime? startDateTime;
  double? distance;
  double? ascent;
  int? totalTimeMillis;
  int trackColour;

  GpxTrack({
    this.gpxTrackId = 0,
    required this.fileLocation,
    required this.trackName,
    this.trackPoints = '[]',
    this.startDateTime,
    this.distance,
    this.ascent,
    this.totalTimeMillis,
    this.trackColour = 0xFFa726bc,
  });

  static GpxTrack fromMap(Map<String, dynamic> map) {
    return GpxTrack(
      gpxTrackId: map['gpxTrackId'] as int? ?? 0,
      fileLocation: map['fileLocation'] as String? ?? '',
      trackName: map['trackName'] as String? ?? '',
      trackPoints: map['trackPoints'] as String? ?? '[]',
      startDateTime: map['startDateTime'] != null
          ? DateTime.tryParse(map['startDateTime'] as String)
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
      'fileLocation': fileLocation,
      'trackName': trackName,
      'trackPoints': trackPoints,
      'startDateTime': startDateTime?.toIso8601String(),
      'distance': distance,
      'ascent': ascent,
      'totalTimeMillis': totalTimeMillis,
      'trackColour': trackColour,
    };
  }

  List<({double lat, double lng})> getPoints() {
    try {
      final decoded = _decodePoints(trackPoints);
      return decoded;
    } catch (e) {
      return [];
    }
  }

  static List<({double lat, double lng})> _decodePoints(String json) {
    if (json.isEmpty || json == '[]') return [];

    final List<({double lat, double lng})> points = [];
    final trimmed = json.trim();
    if (!trimmed.startsWith('[') || !trimmed.endsWith(']')) return [];

    var content = trimmed.substring(1, trimmed.length - 1);
    content = content.trim();
    if (content.isEmpty) return [];

    final pairs = content.split('],[');
    for (final pair in pairs) {
      var part = pair.replaceAll('[', '').replaceAll(']', '').trim();
      if (part.isEmpty) continue;

      final coords = part.split(',');
      if (coords.length != 2) continue;

      final lat = double.tryParse(coords[0].trim());
      final lng = double.tryParse(coords[1].trim());
      if (lat != null && lng != null) {
        points.add((lat: lat, lng: lng));
      }
    }
    return points;
  }
}
