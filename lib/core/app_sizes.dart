import 'package:flutter/material.dart';

/// | NAME           | SIZE |  HEIGHT |  WEIGHT |  SPACING |             |
/// |----------------|------|---------|---------|----------|-------------|
/// | displayLarge   | 57.0 |   64.0  | regular | -0.25    |             |
/// | displayMedium  | 45.0 |   52.0  | regular |  0.0     |             |
/// | displaySmall   | 36.0 |   44.0  | regular |  0.0     |             |
/// | headlineLarge  | 32.0 |   40.0  | regular |  0.0     |             |
/// | headlineMedium | 28.0 |   36.0  | regular |  0.0     |             |
/// | headlineSmall  | 24.0 |   32.0  | regular |  0.0     |             |
/// | titleLarge     | 22.0 |   28.0  | regular |  0.0     |             |
/// | titleMedium    | 16.0 |   24.0  | medium  |  0.15    |             |
/// | titleSmall     | 14.0 |   20.0  | medium  |  0.1     |             |
/// | bodyLarge      | 16.0 |   24.0  | regular |  0.5     |             |
/// | bodyMedium     | 14.0 |   20.0  | regular |  0.25    |             |
/// | bodySmall      | 12.0 |   16.0  | regular |  0.4     |             |
/// | labelLarge     | 14.0 |   20.0  | medium  |  0.1     |             |
/// | labelMedium    | 12.0 |   16.0  | medium  |  0.5     |             |
/// | labelSmall     | 11.0 |   16.0  | medium  |  0.5     |             |
///
/// Constant sizes to be used in the app (paddings, gaps, rounded corners etc.)
/// Based on a consistent Ratio of 1.25
/// `baseSize    12      14      16      20`
/// xxsmall     6.1     7.2     8.2     10.2
/// xsmall      7.7     9.0     10.2    12.8
/// small       9.6    11.2    12.8    16.0
/// medium      12.0    14.0    16.0    20.0
/// large       15      17.5    20.0    25.0
/// xLarge      18.75    21.9    25.0    31.3
/// x2Large     27.3    27.3    31.3    39.1
/// x3Large     34.2    34.2    39.1    48.8
/// x4Large     36.6    42.7    48.8    61.0
class Sizes {
  static const baseFontSize = 14.0;
  static const sizeRatio = 1.25;

  /// `strokeWidth `= `baseFontSize `/ 10
  static const double strokeWidth = x2Large / 10;

  // TODO work out difference in sizing between material icons and fontAwesome
  static const double iconFA = x3Large;
  static const double icon = x4Large;
  static const double iconLge = 2 * x4Large;

  static const double padding = medium / 2;
  static const double margin = medium / 4;
  static const borderWidth = 1.0;

  static const none = 0.0;
  static const double xxSmall = xSmall / sizeRatio;
  static const double xSmall = small / sizeRatio;
  static const double small = medium / sizeRatio;

  /// `medium` is the baseFontSize (16)
  static const double medium = baseFontSize;
  static const double large = medium * sizeRatio;
  static const double xLarge = large * sizeRatio;
  static const double x2Large = xLarge * sizeRatio;
  static const double x3Large = x2Large * sizeRatio;
  static const double x4Large = x3Large * sizeRatio;
}

/// Constant gap widths
const gapWXS = SizedBox(width: Sizes.xSmall);
const gapWSML = SizedBox(width: Sizes.small);
const gapWMED = SizedBox(width: Sizes.medium);
const gapWLGE = SizedBox(width: Sizes.large);
const gapWXLG = SizedBox(width: Sizes.xLarge);

/// Constant gap heights
const gapHXXS = SizedBox(height: Sizes.xxSmall);
const gapHXS = SizedBox(height: Sizes.xSmall);
const gapHSML = SizedBox(height: Sizes.small);
const gapHMED = SizedBox(height: Sizes.medium);
const gapHLGE = SizedBox(height: Sizes.large);
const gapHXLG = SizedBox(height: Sizes.xLarge);
