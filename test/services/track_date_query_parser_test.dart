import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/track_date_query_parser.dart';

void main() {
  const parser = TrackDateQueryParser();

  test('parses day-first Australian numeric dates deterministically', () {
    final result = parser.parseQuery('28/7/62');

    expect(result.kind, TrackDateQueryKind.valid);
    expect(result.range!.start, const TrackCalendarDay(1962, 7, 28));
    expect(result.range!.end, const TrackCalendarDay(1962, 7, 28));
  });

  test('accepts supported month formats and inclusive range separators', () {
    final shortYear = parser.parseQuery('28 JUL 62');
    final longYear = parser.parseQuery(' 28   Jul   1962 ');
    final hyphenRange = parser.parseQuery('28/7/62 - 30/7/1962');
    final dotRange = parser.parseQuery('28 Jul 62..30 Jul 62');

    expect(shortYear.range!.start, const TrackCalendarDay(1962, 7, 28));
    expect(longYear.range!.start, const TrackCalendarDay(1962, 7, 28));
    expect(hyphenRange.range!.end, const TrackCalendarDay(1962, 7, 30));
    expect(dotRange.range!.end, const TrackCalendarDay(1962, 7, 30));
  });

  test('uses the specified two digit year boundary', () {
    expect(
      parser.parseQuery('1/1/00').range!.start,
      const TrackCalendarDay(2000, 1, 1),
    );
    expect(
      parser.parseQuery('1/1/49').range!.start,
      const TrackCalendarDay(2049, 1, 1),
    );
    expect(
      parser.parseQuery('1/1/50').range!.start,
      const TrackCalendarDay(1950, 1, 1),
    );
    expect(
      parser.parseQuery('1/1/99').range!.start,
      const TrackCalendarDay(1999, 1, 1),
    );
  });

  test('distinguishes invalid date-like input from name input', () {
    expect(
      parser.parseQuery('29/2/2023').kind,
      TrackDateQueryKind.invalidDateLike,
    );
    expect(
      parser.parseQuery('28 Jul').kind,
      TrackDateQueryKind.invalidDateLike,
    );
    expect(
      parser.parseQuery('28 Jul 62 - Bonnet').kind,
      TrackDateQueryKind.invalidDateLike,
    );
    expect(parser.parseQuery('123 Peak').kind, TrackDateQueryKind.nonDateLike);
    expect(
      parser.parseQuery('Bonnet 28 Jul 62').kind,
      TrackDateQueryKind.nonDateLike,
    );
  });

  test(
    'endpoint parsing reuses the single date grammar and rejects ranges',
    () {
      final endpoint = parser.parseEndpoint('28 Jul 62');

      expect(endpoint.kind, TrackDateQueryKind.valid);
      expect(endpoint.range!.start, const TrackCalendarDay(1962, 7, 28));
      expect(
        parser.parseEndpoint('28 Jul 62 - 29 Jul 62').kind,
        TrackDateQueryKind.invalidDateLike,
      );
    },
  );
}
