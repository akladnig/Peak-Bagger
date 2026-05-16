import 'package:latlong2/latlong.dart';

import '../core/date_formatters.dart';
import '../core/number_formatters.dart';
import '../models/gpx_track.dart';

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
    final sorted = orderedTracks(tracks);
    if (sorted.isEmpty) {
      return null;
    }

    return sorted.first;
  }

  static List<GpxTrack> orderedTracks(Iterable<GpxTrack> tracks) {
    final sorted = tracks
        .where((track) => track.startDateTime != null)
        .toList();
    sorted.sort((a, b) {
      final startComparison = b.startDateTime!.compareTo(a.startDateTime!);
      if (startComparison != 0) {
        return startComparison;
      }
      return b.gpxTrackId.compareTo(a.gpxTrackId);
    });
    return List<GpxTrack>.unmodifiable(sorted);
  }

  static int indexOfTrackId(List<GpxTrack> tracks, int trackId) {
    return tracks.indexWhere((track) => track.gpxTrackId == trackId);
  }

  static GpxTrack? previousTrack(List<GpxTrack> tracks, int index) {
    if (index <= 0 || index >= tracks.length) {
      return null;
    }
    return tracks[index - 1];
  }

  static GpxTrack? nextTrack(List<GpxTrack> tracks, int index) {
    if (index < 0 || index >= tracks.length - 1) {
      return null;
    }
    return tracks[index + 1];
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
