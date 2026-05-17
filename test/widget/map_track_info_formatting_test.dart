import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/date_formatters.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';

void main() {
  test('formatTrackDate uses stored calendar fields directly', () {
    expect(
      formatTrackDate(DateTime.utc(2026, 1, 7, 23, 30)),
      'Wed, 7 January 2026',
    );
    expect(formatTrackDate(null), 'Unknown');
  });

  test('formatTrackTimeRange renders partial cases', () {
    expect(
      formatTrackTimeRange(
        DateTime(2026, 1, 7, 14, 5),
        DateTime(2026, 1, 7, 16, 40),
      ),
      'from 14:05 to 16:40',
    );
    expect(
      formatTrackTimeRange(DateTime(2026, 1, 7, 14, 5), null),
      'from 14:05 to Unknown',
    );
    expect(
      formatTrackTimeRange(null, DateTime(2026, 1, 7, 16, 40)),
      'from Unknown to 16:40',
    );
    expect(formatTrackTimeRange(null, null), 'from Unknown to Unknown');
  });

  test('formatDistance and formatDuration use local panel rules', () {
    expect(formatDistance(840), '840 m');
    expect(formatDistance(12400), '12 km');
    expect(formatDuration(0), '0m');
    expect(formatDuration(59 * 60 * 1000), '59m');
    expect(formatDuration(2 * 60 * 60 * 1000 + 5 * 60 * 1000), '2h 5m');
    expect(formatDuration(null), 'Unknown');
  });

  test('normalizeTrackPeakNames sorts and deduplicates by raw osmId', () {
    final peaks = [
      Peak(osmId: 2, name: 'beta', latitude: 0, longitude: 0),
      Peak(osmId: 1, name: 'Alpha', latitude: 0, longitude: 0),
      Peak(osmId: 1, name: 'Alpha duplicate', latitude: 0, longitude: 0),
      Peak(osmId: 0, name: '', latitude: 0, longitude: 0),
      Peak(osmId: 0, name: 'Ignored duplicate name', latitude: 0, longitude: 0),
    ];

    expect(normalizeTrackPeakNames(peaks), ['Alpha', 'beta', 'Unknown Peak']);
  });
}
