import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/date_formatters.dart';

void main() {
  group('formatElevationDateRange', () {
    test('omits the year from the first date when the year matches', () {
      expect(
        formatElevationDateRange(DateTime(2026, 5, 9), DateTime(2026, 5, 15)),
        'Sat, 9 May - Fri, 15 May 2026',
      );
    });

    test('includes the year on the first date when years differ', () {
      expect(
        formatElevationDateRange(DateTime(2025, 12, 31), DateTime(2026, 1, 1)),
        'Wed, 31 Dec 2025 - Thu, 1 Jan 2026',
      );
    });
  });

  group('formatTrackDateShortMonth', () {
    test('renders a three-letter month', () {
      expect(
        formatTrackDateShortMonth(DateTime.utc(2026, 1, 7, 23, 30)),
        'Wed, 7 Jan 2026',
      );
    });

    test('renders Unknown for null', () {
      expect(formatTrackDateShortMonth(null), 'Unknown');
    });
  });

  group('formatCompactDate', () {
    test('renders leading-zero day, month, and two-digit year', () {
      expect(formatCompactDate(DateTime(2024, 1, 9)), '09/01/24');
    });

    test('uses the local calendar date for UTC input', () {
      final utc = DateTime.utc(2024, 1, 11, 12);

      expect(formatCompactDate(utc), formatCompactDate(utc.toLocal()));
    });
  });
}
