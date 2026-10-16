import '../models/gpx_track.dart';
import '../models/track_date_status.dart';

/// Canonical values are UTC-midnight calendar carriers, never local instants.
/// Legacy values retain the caller's former interpretation until recalculated.
abstract final class TrackDateCalendarCodec {
  static DateTime? day(GpxTrack track, {bool localizeLegacy = true}) {
    if (track.trackDateStatus == TrackDateStatus.unresolvedImport) return null;
    final stored = track.trackDate;
    if (stored == null) return null;
    final value =
        track.trackDateStatus == TrackDateStatus.resolved || !localizeLegacy
        ? stored
        : stored.toLocal();
    return DateTime.utc(value.year, value.month, value.day);
  }

  static DateTime? ascentDay(
    DateTime? stored,
    GpxTrack? track, {
    bool localizeLegacy = true,
  }) {
    if (track?.trackDateStatus == TrackDateStatus.unresolvedImport) return null;
    if (stored == null) return null;
    final value =
        track?.trackDateStatus == TrackDateStatus.resolved || !localizeLegacy
        ? stored
        : stored.toLocal();
    return DateTime.utc(value.year, value.month, value.day);
  }
}
