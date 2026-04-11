import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/grid_reference_parser.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:latlong2/latlong.dart';

void main() {
  group('GridReferenceParser', () {
    group('interpretDigit', () {
      test('1-digit "1" → "10000"', () {
        expect(GridReferenceParser.interpretDigit('1', 1), '10000');
      });

      test('2-digit "19" → "19000"', () {
        expect(GridReferenceParser.interpretDigit('19', 2), '19000');
      });

      test('3-digit "194" → "19400"', () {
        expect(GridReferenceParser.interpretDigit('194', 3), '19400');
      });

      test('4-digit "1943" → "19430"', () {
        expect(GridReferenceParser.interpretDigit('1943', 4), '19430');
      });

      test('5-digit "19432" → "19432"', () {
        expect(GridReferenceParser.interpretDigit('19432', 5), '19432');
      });
    });

    group('validateEvenDigitCount', () {
      test('odd digit count "194" returns error', () {
        expect(
          GridReferenceParser.validateEvenDigitCount('194'),
          'Coordinate digits must be even count',
        );
      });

      test('even digit count "194507" returns null', () {
        expect(GridReferenceParser.validateEvenDigitCount('194507'), isNull);
      });
    });

    group('validateSpaceSeparatedDigits', () {
      test('mismatched digit counts "19 4507" returns error', () {
        expect(
          GridReferenceParser.validateSpaceSeparatedDigits('19', '4507'),
          'Easting and northing must have same digit count when space-separated',
        );
      });

      test('matching digit counts "194 507" returns null', () {
        expect(
          GridReferenceParser.validateSpaceSeparatedDigits('194', '507'),
          isNull,
        );
      });
    });

    group('parseCoordinates', () {
      test('2-digit continuous "15" → easting="10000", northing="50000"', () {
        final result = GridReferenceParser.parseCoordinates('15');
        expect(result, isNotNull);
        expect(result!.easting, '10000');
        expect(result.northing, '50000');
      });

      test('4-digit continuous "1951" → easting="19000", northing="51000"', () {
        final result = GridReferenceParser.parseCoordinates('1951');
        expect(result, isNotNull);
        expect(result!.easting, '19000');
        expect(result.northing, '51000');
      });

      test(
        '6-digit continuous "194507" → easting="19400", northing="50700"',
        () {
          final result = GridReferenceParser.parseCoordinates('194507');
          expect(result, isNotNull);
          expect(result!.easting, '19400');
          expect(result.northing, '50700');
        },
      );

      test(
        '8-digit continuous "19435078" → easting="19430", northing="50780"',
        () {
          final result = GridReferenceParser.parseCoordinates('19435078');
          expect(result, isNotNull);
          expect(result!.easting, '19430');
          expect(result.northing, '50780');
        },
      );

      test(
        '10-digit continuous "1943250789" → easting="19432", northing="50789"',
        () {
          final result = GridReferenceParser.parseCoordinates('1943250789');
          expect(result, isNotNull);
          expect(result!.easting, '19432');
          expect(result.northing, '50789');
        },
      );

      test('odd digit count "194" returns null', () {
        expect(GridReferenceParser.parseCoordinates('194'), isNull);
      });
    });

    group('MGRS to LatLng conversion', () {
      test('55GEN1940050700 → (-42.89606, 147.23761) ±0.00001', () {
        final mgrsString = '55GEN1940050700';
        final coords = mgrs.Mgrs.toPoint(mgrsString);
        final location = LatLng(coords[1], coords[0]);

        expect(location.latitude, closeTo(-42.89606, 0.00001));
        expect(location.longitude, closeTo(147.23761, 0.00001));
      });
    });
  });
}
