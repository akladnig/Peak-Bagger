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

      test('Maria corners - TL: EN8000099999', () {
        final mgrsString = '55GEN8000099999';
        final coords = mgrs.Mgrs.toPoint(mgrsString);
        final location = LatLng(coords[1], coords[0]);
        expect(location.latitude, closeTo(-42.44821, 0.001));
        expect(location.longitude, closeTo(147.97283, 0.001));
      });

      test('Maria corners - TR: FN1999999999', () {
        final mgrsString = '55GFN1999999999';
        final coords = mgrs.Mgrs.toPoint(mgrsString);
        final location = LatLng(coords[1], coords[0]);
        expect(location.latitude, closeTo(-42.44305, 0.001));
        expect(location.longitude, closeTo(148.45911, 0.001));
      });

      test('Maria corners - BL: EN8000070000', () {
        final mgrsString = '55GEN8000070000';
        final coords = mgrs.Mgrs.toPoint(mgrsString);
        final location = LatLng(coords[1], coords[0]);
        expect(location.latitude, closeTo(-42.71834, 0.001));
        expect(location.longitude, closeTo(147.97704, 0.001));
      });

      test('Maria corners - BR: FN1999970000', () {
        final mgrsString = '55GFN1999970000';
        final coords = mgrs.Mgrs.toPoint(mgrsString);
        final location = LatLng(coords[1], coords[0]);
        expect(location.latitude, closeTo(-42.71313, 0.001));
        expect(location.longitude, closeTo(148.46542, 0.001));
      });

      test('Maria corners - verify easting/northing from MGRS output', () {
        final tl = mgrs.Mgrs.toPoint('55GEN8000099999');
        final tr = mgrs.Mgrs.toPoint('55GFN1999999999');
        final bl = mgrs.Mgrs.toPoint('55GEN8000070000');
        final br = mgrs.Mgrs.toPoint('55GFN1999970000');

        final tlMgrs = mgrs.Mgrs.forward([tl[0], tl[1]], 5);
        final trMgrs = mgrs.Mgrs.forward([tr[0], tr[1]], 5);
        final blMgrs = mgrs.Mgrs.forward([bl[0], bl[1]], 5);
        final brMgrs = mgrs.Mgrs.forward([br[0], br[1]], 5);

        expect(tlMgrs, contains('EN80000'));
        expect(trMgrs, contains('FN19999'));
        expect(blMgrs, contains('EN80000'));
        expect(brMgrs, contains('FN19999'));
      });

      test('Maria - verify rectangle bounds', () {
        final tl = mgrs.Mgrs.toPoint('55GEN8000099999');
        final tr = mgrs.Mgrs.toPoint('55GFN1999999999');
        final bl = mgrs.Mgrs.toPoint('55GEN8000070000');
        final br = mgrs.Mgrs.toPoint('55GFN1999970000');

        final tlLatLng = LatLng(tl[1], tl[0]);
        final trLatLng = LatLng(tr[1], tr[0]);
        final blLatLng = LatLng(bl[1], bl[0]);
        final brLatLng = LatLng(br[1], br[0]);

        // Verify corners form a proper quadrilateral
        expect(tlLatLng.latitude, greaterThan(blLatLng.latitude));
        expect(trLatLng.latitude, greaterThan(brLatLng.latitude));
        expect(tlLatLng.longitude, lessThan(trLatLng.longitude));
        expect(blLatLng.longitude, lessThan(brLatLng.longitude));
      });
    });
  });
}
