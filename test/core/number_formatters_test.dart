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
}
