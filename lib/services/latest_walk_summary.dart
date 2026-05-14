import 'package:latlong2/latlong.dart';

import '../models/gpx_track.dart';
import '../screens/map_screen_panels.dart';

class LatestWalkSummary {
  const LatestWalkSummary._({
    required this.track,
    required this.segments,
    required this.title,
    required this.dateText,
    required this.distanceText,
    required this.ascentText,
  });

  const LatestWalkSummary.empty()
      : track = null,
        segments = const [],
        title = '',
        dateText = '',
        distanceText = '',
        ascentText = '';

  final GpxTrack? track;
  final List<List<LatLng>> segments;
  final String title;
  final String dateText;
  final String distanceText;
  final String ascentText;

  bool get isEmpty => track == null;

  List<LatLng> get points {
    if (segments.isEmpty) {
      return const [];
    }

    return segments.expand((segment) => segment).toList(growable: false);
  }

  factory LatestWalkSummary.fromTrack(GpxTrack track) {
    final segments = _safeSegments(track);
    if (segments.isEmpty) {
      return const LatestWalkSummary.empty();
    }

    return LatestWalkSummary._(
      track: track,
      segments: List<List<LatLng>>.unmodifiable(
        segments.map((segment) => List<LatLng>.unmodifiable(segment)),
      ),
      title: track.trackName.isEmpty ? 'Unnamed Track' : track.trackName,
      dateText: formatTrackDate(track.startDateTime),
      distanceText: formatDistance(track.distance2d),
      ascentText: formatAscent(track.ascent),
    );
  }

  factory LatestWalkSummary.fromTracks(Iterable<GpxTrack> tracks) {
    final track = selectLatestTrack(tracks);
    if (track == null) {
      return const LatestWalkSummary.empty();
    }

    return LatestWalkSummary.fromTrack(track);
  }

  static GpxTrack? selectLatestTrack(Iterable<GpxTrack> tracks) {
    final sorted = tracks.where((track) => track.startDateTime != null).toList();
    if (sorted.isEmpty) {
      return null;
    }

    sorted.sort((a, b) {
      final startComparison = b.startDateTime!.compareTo(a.startDateTime!);
      if (startComparison != 0) {
        return startComparison;
      }
      return b.gpxTrackId.compareTo(a.gpxTrackId);
    });

    return sorted.first;
  }

  static List<List<LatLng>> _safeSegments(GpxTrack track) {
    try {
      return track
          .getSegments()
          .where((segment) => segment.isNotEmpty)
          .map((segment) => List<LatLng>.unmodifiable(segment))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
