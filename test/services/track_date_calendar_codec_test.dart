import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/track_date_calendar_codec.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import '../harness/track_date_fixtures.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);

  test('explicit persisted status, not timestamp shape, selects decoding', () {
    final track = GpxTrack(
      contentHash: 'h',
      trackName: 'Walk',
      trackDate: DateTime.utc(2026, 12, 31, 23, 30),
    );
    expect(track.trackDateStatus, 0);
    expect(
      TrackDateCalendarCodec.day(track),
      DateTime.utc(
        track.trackDate!.toLocal().year,
        track.trackDate!.toLocal().month,
        track.trackDate!.toLocal().day,
      ),
    );
    track.trackDateStatus = TrackDateStatus.resolved;
    expect(TrackDateCalendarCodec.day(track), DateTime.utc(2026, 12, 31));
    expect(
      formatTrackDateShortMonth(TrackDateCalendarCodec.day(track)),
      'Thu, 31 Dec 2026',
    );
    expect(
      formatCompactCalendarDate(TrackDateCalendarCodec.day(track)!),
      '31/12/26',
    );
    track.trackDateStatus = TrackDateStatus.legacySkipped;
    expect(
      TrackDateCalendarCodec.day(track, localizeLegacy: false),
      DateTime.utc(2026, 12, 31),
    );
    track.trackDateStatus = TrackDateStatus.unresolvedImport;
    expect(TrackDateCalendarCodec.day(track), isNull);
    expect(TrackDateCalendarCodec.ascentDay(track.trackDate, track), isNull);
    expect(
      formatTrackDateShortMonth(TrackDateCalendarCodec.day(track)),
      'Unknown',
    );
  });

  test(
    'metadata survives serialization and cloning; absent metadata is legacy',
    () {
      final track = GpxTrack(
        contentHash: 'h',
        trackName: 'Walk',
        trackDate: DateTime.utc(2027),
        trackDateStatus: 1,
        trackDateDerivationVersion: 1,
        trackDateTimezoneId: 'Australia/Hobart',
      );
      final clone = GpxTrack.fromMap(track.toMap());
      expect(clone.toMap(), track.toMap());
      expect(
        clone.hasMetadataTrackDate,
        isTrue,
      ); // Even without a processed start timestamp.
      final unresolved = GpxTrack.fromMap({
        ...track.toMap(),
        'trackDate': null,
        'trackDateStatus': 3,
        'trackDateTimezoneId': null,
        'trackDateFailureReason': 'missing_time',
      });
      expect(unresolved.trackDateFailureReason, 'missing_time');
      expect(unresolved.hasMetadataTrackDate, isFalse);
      final legacy = GpxTrack.fromMap({
        'trackDate': '2027-01-01T00:00:00Z',
        'startDateTime': '2027-01-01T01:00:00Z',
      });
      expect(legacy.trackDateStatus, 0);
      expect(legacy.trackDateDerivationVersion, 0);
      expect(legacy.trackDateTimezoneId, isNull);
      expect(legacy.trackDateFailureReason, isNull);
    },
  );
}
