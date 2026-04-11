class GridReferenceParser {
  static String interpretDigit(String digit, int digitCount) {
    final value = int.tryParse(digit) ?? 0;
    final multiplier = switch (digitCount) {
      1 => 10000,
      2 => 1000,
      3 => 100,
      4 => 10,
      5 => 1,
      _ => 1,
    };
    return (value * multiplier).toString().padLeft(5, '0');
  }

  static String? validateEvenDigitCount(String coords) {
    if (coords.length % 2 != 0) {
      return 'Coordinate digits must be even count';
    }
    return null;
  }

  static String? validateSpaceSeparatedDigits(String easting, String northing) {
    if (easting.length != northing.length) {
      return 'Easting and northing must have same digit count when space-separated';
    }
    return null;
  }

  static ({String easting, String northing})? parseCoordinates(String coords) {
    if (validateEvenDigitCount(coords) != null) {
      return null;
    }

    final halfLength = coords.length ~/ 2;
    final eastingPart = coords.substring(0, halfLength);
    final northingPart = coords.substring(halfLength);

    final easting = interpretDigit(eastingPart, eastingPart.length);
    final northing = interpretDigit(northingPart, northingPart.length);

    return (easting: easting, northing: northing);
  }
}
