import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/track_date_derivation_service.dart';
import 'package:timezone_finder/timezone_finder.dart' as geography;
import 'package:timezone/timezone.dart' as tz;

import '../harness/track_date_fixtures.dart';

void main() {
  late TrackDateDerivationService service;
  setUpAll(() {
    expectTrackDateHostOffsets();
    service = TrackDateDerivationService.offline();
  });

  test(
    'packaged versions and independent geographic midnight/year fixtures',
    () {
      expect(geography.boundaryDataVersion, '2026e');
      final hobart = service.derive(datedGpx());
      expect(hobart.timezoneId, 'Australia/Hobart');
      expect(hobart.offset, const Duration(hours: 11));
      expect(hobart.day, DateTime.utc(2027, 1, 1));
      final la = service.derive(
        datedGpx(
          latitude: '34.0522',
          longitude: '-118.2437',
          time: '2027-01-01T07:30:00Z',
        ),
      );
      expect(la.timezoneId, 'America/Los_Angeles');
      expect(la.offset, const Duration(hours: -8));
      expect(
        la.day,
        DateTime.utc(2026, 12, 31),
      ); // Hobart is already 1 January.
      final slovenia = service.derive(
        datedGpx(
          latitude: '46.0569',
          longitude: '14.5058',
          time: '2026-07-01T22:30:00Z',
        ),
      );
      expect(slovenia.timezoneId, 'Europe/Ljubljana');
      expect(slovenia.offset, const Duration(hours: 2));
      expect(slovenia.day, DateTime.utc(2026, 7, 2));
      // This linked identifier is absent from timezone/data/latest.dart.
      expect(tz.getLocation('Europe/Ljubljana').name, 'Europe/Ljubljana');
    },
  );

  test('historical Hobart DST offsets on either side of both transitions', () {
    for (final fixture in [
      ('2026-04-04T15:59:00Z', 11, DateTime.utc(2026, 4, 5)),
      ('2026-04-04T16:01:00Z', 10, DateTime.utc(2026, 4, 5)),
      ('2026-10-03T15:59:00Z', 10, DateTime.utc(2026, 10, 4)),
      ('2026-10-03T16:01:00Z', 11, DateTime.utc(2026, 10, 4)),
      ('1970-07-01T14:30:00Z', 10, DateTime.utc(1970, 7, 2)),
    ]) {
      final result = service.derive(datedGpx(time: fixture.$1));
      expect(result.offset, Duration(hours: fixture.$2));
      expect(result.day, fixture.$3);
    }
  });

  test(
    'explicit source offset defines an instant, not its written calendar day',
    () {
      expect(
        service.derive(datedGpx(time: '2026-12-31T23:30:00-08:00')).day,
        DateTime.utc(2027, 1, 1),
      );
    },
  );

  test('first point cannot be replaced by a later point or segment', () {
    final xml = datedGpx(
      time: null,
      extraPoints:
          '<trkpt lat="-42" lon="147"><time>2026-01-01T00:00:00Z</time></trkpt>',
    );
    expect(service.derive(xml).failure, TrackDateFailure.missingTime);
    final withLaterSegment = xml.replaceFirst(
      '</trk>',
      '<trkseg><trkpt lat="-42" lon="147"><time>2026-01-01T00:00:00Z</time></trkpt></trkseg></trk>',
    );
    expect(
      service.derive(withLaterSegment).failure,
      TrackDateFailure.missingTime,
    );
  });

  test(
    'empty first segment falls back to first route point, not later segment',
    () {
      const xml =
          '<gpx><trk><trkseg/><trkseg><trkpt lat="34" lon="-118"><time>2026-01-01T07:30:00Z</time></trkpt></trkseg></trk><rte><rtept lat="-42.8821" lon="147.3272"><time>2026-12-31T13:30:00Z</time></rtept></rte></gpx>';
      expect(service.derive(xml).day, DateTime.utc(2027, 1, 1));
    },
  );

  test('malformed GPX and missing point have stable actionable outcomes', () {
    expect(service.derive('<gpx>').failure, TrackDateFailure.invalidGpx);
    expect(service.derive('<other/>').failure, TrackDateFailure.invalidGpx);
    expect(service.derive('<gpx/>').failure, TrackDateFailure.missingPoint);
  });

  test('rejects missing, ambiguous, malformed and overflowing timestamps', () {
    for (final fixture in <(String?, TrackDateFailure)>[
      (null, TrackDateFailure.missingTime),
      ('2026-01-01T12:00:00', TrackDateFailure.ambiguousTime),
      ('badZ', TrackDateFailure.invalidTime),
      ('2026-02-30T12:00:00Z', TrackDateFailure.invalidTime),
      ('2026-01-01T24:00:00Z', TrackDateFailure.invalidTime),
      ('2026-01-01T12:60:00Z', TrackDateFailure.invalidTime),
      ('2026-01-01T12:00:00+99:00', TrackDateFailure.invalidTime),
    ]) {
      final result = service.derive(datedGpx(time: fixture.$1));
      expect(result.failure, fixture.$2, reason: '${fixture.$1}');
      expect(result.day, isNull);
      expect(result.failure!.message, isNotEmpty);
    }
  });

  test('invalid coordinates and uncovered ocean are unresolved', () {
    for (final coords in [
      ('NaN', '147'),
      ('Infinity', '147'),
      ('-91', '147'),
      ('-42', '181'),
      ('', '147'),
    ]) {
      expect(
        service
            .derive(datedGpx(latitude: coords.$1, longitude: coords.$2))
            .failure,
        TrackDateFailure.invalidCoordinates,
      );
    }
    expect(
      service.derive(datedGpx(latitude: '0', longitude: '-140')).failure,
      TrackDateFailure.uncoveredLocation,
    );
  });

  test('geographic and historical-rules failures never supply a fallback', () {
    final geographicFailure = TrackDateDerivationService(
      lookupTimezone: ({required latitude, required longitude}) =>
          throw StateError('fixture lookup'),
      localTime: ({required instant, required timezoneId}) =>
          throw StateError('must not run'),
    );
    expect(
      geographicFailure.derive(datedGpx()).failure,
      TrackDateFailure.geographicLookupFailed,
    );
    final rulesFailure = TrackDateDerivationService(
      lookupTimezone: ({required latitude, required longitude}) =>
          'Missing/Zone',
      localTime: ({required instant, required timezoneId}) =>
          throw StateError('fixture rules'),
    );
    expect(
      rulesFailure.derive(datedGpx()).failure,
      TrackDateFailure.timezoneRulesFailed,
    );
  });
}
