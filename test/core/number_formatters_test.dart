import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/number_formatters.dart';

void main() {
  group('formatCount', () {
    test('formats integers', () {
      expect(formatCount(42), '42');
    });
  });

  group('formatElevation', () {
    test('formats integers with units by default', () {
      expect(formatElevation(1234), '1234 m');
      expect(formatElevation(12345), '12,345 m');
    });

    test('can omit units', () {
      expect(formatElevation(1234, showUnits: false), '1234');
      expect(formatElevation(12345, showUnits: false), '12,345');
    });
  });

  group('formatCompactElevation', () {
    test('formats whole numbers without a unit separator', () {
      expect(formatCompactElevation(1234), '1234m');
    });

    test('preserves one decimal place for fractional values', () {
      expect(formatCompactElevation(1234.5), '1234.5m');
    });
  });

  group('formatFileSizeKiB', () {
    test('formats kibibytes with one decimal place by default', () {
      expect(formatFileSizeKiB(12.34), '12.3 KiB');
    });
  });

  group('formatPercentage', () {
    test('formats percentages with one decimal place by default', () {
      expect(formatPercentage(56.78), '56.8%');
    });
  });

  group('formatSpeedKmh', () {
    test('formats speeds with units by default', () {
      expect(formatSpeedKmh(12.34), '12.3 km/h');
    });

    test('renders Unknown for null', () {
      expect(formatSpeedKmh(null), 'Unknown');
    });
  });

  group('formatCoordinate', () {
    test('formats coordinates with six decimal places by default', () {
      expect(formatCoordinate(-42.1234567), '-42.123457');
    });

    test('allows overriding decimal places', () {
      expect(
        formatCoordinate(-42.1234567, decimalPlaces: 8),
        '-42.12345670',
      );
    });
  });

  group('formatCoordinatePair', () {
    test('formats latitude and longitude for display', () {
      expect(
        formatCoordinatePair(-42.123456, 147.987654),
        '(-42.123456, 147.987654)',
      );
    });
  });
}
