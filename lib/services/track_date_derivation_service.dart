import 'dart:developer' as developer;

import 'package:timezone/data/latest_all.dart' as rules;
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone_finder/timezone_finder.dart' as geography;
import 'package:xml/xml.dart';
export '../models/track_date_status.dart';

enum TrackDateFailure {
  invalidGpx(
    'invalid_gpx',
    'The original GPX could not be read. Check the file.',
  ),
  missingPoint('missing_point', 'The first recorded GPX point is missing.'),
  invalidCoordinates(
    'invalid_coordinates',
    'The first recorded point needs valid latitude and longitude.',
  ),
  missingTime('missing_time', 'The first recorded point has no timestamp.'),
  invalidTime('invalid_time', 'The first recorded timestamp is invalid.'),
  ambiguousTime(
    'ambiguous_time',
    'The first recorded timestamp needs Z or an explicit UTC offset.',
  ),
  uncoveredLocation(
    'uncovered_location',
    'No offline timezone covers the first recorded location.',
  ),
  geographicLookupFailed(
    'geographic_lookup_failed',
    'Offline timezone lookup failed. Retry the import.',
  ),
  timezoneRulesFailed(
    'timezone_rules_failed',
    'Historical timezone rules could not be applied. Retry the import.',
  );

  const TrackDateFailure(this.code, this.message);
  final String code;
  final String message;

  static String messageFor(String? code) =>
      values.where((failure) => failure.code == code).firstOrNull?.message ??
      'The walk date could not be determined. Check the original GPX.';
}

class TrackDateDerivation {
  const TrackDateDerivation.resolved({
    required DateTime this.day,
    required String this.timezoneId,
    required Duration this.offset,
  }) : failure = null;

  const TrackDateDerivation.unresolved(this.failure)
    : day = null,
      timezoneId = null,
      offset = null;

  final DateTime? day;
  final String? timezoneId;
  final Duration? offset;
  final TrackDateFailure? failure;
}

typedef TrackTimezoneLookup =
    String? Function({required double latitude, required double longitude});
typedef TrackLocalTimeResolver =
    DateTime Function({required DateTime instant, required String timezoneId});

/// Derives a calendar carrier from ORIGINAL GPX, independently of the host zone.
/// Construction is owned by the import/startup action (or its injected provider).
class TrackDateDerivationService {
  TrackDateDerivationService({
    required this.lookupTimezone,
    required this.localTime,
  });

  factory TrackDateDerivationService.offline() {
    if (!_initialized) {
      rules.initializeTimeZones();
      // Reading the version decodes the embedded VM geographic index once.
      if (geography.boundaryDataVersion != geographicDataVersion) {
        throw StateError('Unexpected offline timezone boundary version');
      }
      _initialized = true;
    }
    return TrackDateDerivationService(
      lookupTimezone: ({required latitude, required longitude}) =>
          geography.findLocation(longitude, latitude)?.name,
      localTime: ({required instant, required timezoneId}) =>
          tz.TZDateTime.from(instant, tz.getLocation(timezoneId)),
    );
  }

  static bool _initialized = false;
  static const version = 1;
  static const geographicDataVersion = '2026e';
  static const ianaDataVersion = '2026e';
  final TrackTimezoneLookup lookupTimezone;
  final TrackLocalTimeResolver localTime;

  TrackDateDerivation derive(String originalGpx) {
    final XmlDocument document;
    try {
      document = XmlDocument.parse(originalGpx);
      if (document.rootElement.name.local != 'gpx') {
        return const TrackDateDerivation.unresolved(
          TrackDateFailure.invalidGpx,
        );
      }
    } catch (_) {
      return const TrackDateDerivation.unresolved(TrackDateFailure.invalidGpx);
    }
    final segment = document.findAllElements('trkseg').firstOrNull;
    final point =
        segment?.findElements('trkpt').firstOrNull ??
        document.findAllElements('rtept').firstOrNull;
    if (point == null) {
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.missingPoint,
      );
    }
    final latitude = double.tryParse(point.getAttribute('lat') ?? '');
    final longitude = double.tryParse(point.getAttribute('lon') ?? '');
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.invalidCoordinates,
      );
    }
    final time = point.getElement('time')?.innerText.trim();
    if (time == null || time.isEmpty) {
      return const TrackDateDerivation.unresolved(TrackDateFailure.missingTime);
    }
    if (!RegExp(r'(Z|[+-]\d{2}:\d{2})$').hasMatch(time)) {
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.ambiguousTime,
      );
    }
    final instant = _parseInstant(time);
    if (instant == null) {
      return const TrackDateDerivation.unresolved(TrackDateFailure.invalidTime);
    }
    final String? timezoneId;
    try {
      timezoneId = lookupTimezone(latitude: latitude, longitude: longitude);
    } catch (error, stack) {
      developer.log(
        'Track timezone lookup failed',
        name: 'track_date',
        error: error,
        stackTrace: stack,
      );
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.geographicLookupFailed,
      );
    }
    if (timezoneId == null || timezoneId.isEmpty) {
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.uncoveredLocation,
      );
    }
    try {
      final local = localTime(instant: instant, timezoneId: timezoneId);
      return TrackDateDerivation.resolved(
        day: DateTime.utc(local.year, local.month, local.day),
        timezoneId: timezoneId,
        offset: local.timeZoneOffset,
      );
    } catch (error, stack) {
      developer.log(
        'Track timezone rules failed for $timezoneId',
        name: 'track_date',
        error: error,
        stackTrace: stack,
      );
      return const TrackDateDerivation.unresolved(
        TrackDateFailure.timezoneRulesFailed,
      );
    }
  }

  // DateTime.parse accepts overflow (e.g. February 30); validate components first.
  static DateTime? _parseInstant(String text) {
    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?(Z|[+-](\d{2}):(\d{2}))$',
    ).firstMatch(text);
    if (match == null) return null;
    final components = [
      for (var i = 1; i <= 6; i++) int.parse(match.group(i)!),
    ];
    final [year, month, day, hour, minute, second] = components;
    final date = DateTime.utc(year, month, day);
    if (date.year != year ||
        date.month != month ||
        date.day != day ||
        hour > 23 ||
        minute > 59 ||
        second > 59 ||
        (int.tryParse(match.group(8) ?? '0') ?? 99) > 23 ||
        (int.tryParse(match.group(9) ?? '0') ?? 99) > 59) {
      return null;
    }
    return DateTime.tryParse(text)?.toUtc();
  }
}
