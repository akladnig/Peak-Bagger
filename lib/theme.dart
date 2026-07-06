import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

const _defaultSeedColor = Color(0xFF7E47EB);

@immutable
class ThemeSeedSwatch {
  const ThemeSeedSwatch(this.id, this.label, this.color);

  final String id;
  final String label;
  final Color color;
}

const defaultThemeSeedSwatch = ThemeSeedSwatch(
  'baseColor',
  'My Seed Colour',
  Color(0xFF7E47EB),
);

const themeSeedSwatches = [
  defaultThemeSeedSwatch,
  ThemeSeedSwatch('indigo', 'Indigo', Colors.indigo),
  ThemeSeedSwatch('blue', 'Blue', Colors.blue),
  ThemeSeedSwatch('teal', 'Teal', Colors.teal),
  ThemeSeedSwatch('green', 'Green', Colors.green),
  ThemeSeedSwatch('yellow', 'Yellow', Colors.yellow),
  ThemeSeedSwatch('orange', 'Orange', Colors.orange),
  ThemeSeedSwatch('deepOrange', 'Deep Orange', Colors.deepOrange),
  ThemeSeedSwatch('pink', 'Pink', Colors.pink),
  ThemeSeedSwatch('brightBlue', 'Bright Blue', Color(0xFF0000FF)),
  ThemeSeedSwatch('brightGreen', 'Bright Green', Color(0xFF00FF00)),
  ThemeSeedSwatch('brightRed', 'Bright Red', Color(0xFFFF0000)),
];

ThemeSeedSwatch? themeSeedSwatchById(String? id) {
  if (id == null) {
    return null;
  }

  for (final swatch in themeSeedSwatches) {
    if (swatch.id == id) {
      return swatch;
    }
  }

  return null;
}

@immutable
class ThemeConfig {
  const ThemeConfig({
    required this.seedColor,
    required this.dynamicSchemeVariant,
    required this.contrastLevel,
  });

  final Color seedColor;
  final DynamicSchemeVariant dynamicSchemeVariant;
  final double contrastLevel;
}

const _defaultThemeConfig = ThemeConfig(
  seedColor: _defaultSeedColor,
  dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
  contrastLevel: 0.0,
);

Color lighten(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation + amount).clamp(0.0, 1.0))
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

Color darken(Color color, [double amount = 0.1]) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation - amount).clamp(0.0, 1.0))
      .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
      .toColor();
}

const _secondarySeriesColor = Color(0xFF2E7D32);

@immutable
class ChartSeriesTheme extends ThemeExtension<ChartSeriesTheme> {
  const ChartSeriesTheme({
    required this.primarySeriesColor,
    required this.secondarySeriesColor,
    required this.selectedPrimarySeriesColor,
    required this.selectedSecondarySeriesColor,
  });

  final Color primarySeriesColor;
  final Color secondarySeriesColor;
  final Color selectedPrimarySeriesColor;
  final Color selectedSecondarySeriesColor;

  static ChartSeriesTheme fromColorScheme(ColorScheme colorScheme) {
    return ChartSeriesTheme(
      primarySeriesColor: colorScheme.primaryContainer,
      secondarySeriesColor: _secondarySeriesColor,
      selectedPrimarySeriesColor: lighten(colorScheme.primaryContainer, 0.12),
      selectedSecondarySeriesColor: lighten(_secondarySeriesColor, 0.12),
    );
  }

  @override
  ChartSeriesTheme copyWith({
    Color? primarySeriesColor,
    Color? secondarySeriesColor,
    Color? selectedPrimarySeriesColor,
    Color? selectedSecondarySeriesColor,
  }) {
    return ChartSeriesTheme(
      primarySeriesColor: primarySeriesColor ?? this.primarySeriesColor,
      secondarySeriesColor: secondarySeriesColor ?? this.secondarySeriesColor,
      selectedPrimarySeriesColor:
          selectedPrimarySeriesColor ?? this.selectedPrimarySeriesColor,
      selectedSecondarySeriesColor:
          selectedSecondarySeriesColor ?? this.selectedSecondarySeriesColor,
    );
  }

  @override
  ChartSeriesTheme lerp(
    covariant ThemeExtension<ChartSeriesTheme>? other,
    double t,
  ) {
    if (other is! ChartSeriesTheme) return this;
    return ChartSeriesTheme(
      primarySeriesColor:
          Color.lerp(primarySeriesColor, other.primarySeriesColor, t) ??
          primarySeriesColor,
      secondarySeriesColor:
          Color.lerp(secondarySeriesColor, other.secondarySeriesColor, t) ??
          secondarySeriesColor,
      selectedPrimarySeriesColor:
          Color.lerp(
            selectedPrimarySeriesColor,
            other.selectedPrimarySeriesColor,
            t,
          ) ??
          selectedPrimarySeriesColor,
      selectedSecondarySeriesColor:
          Color.lerp(
            selectedSecondarySeriesColor,
            other.selectedSecondarySeriesColor,
            t,
          ) ??
          selectedSecondarySeriesColor,
    );
  }
}

@immutable
class SeedColourTheme extends ThemeExtension<SeedColourTheme> {
  const SeedColourTheme(this.seedColor);

  final Color seedColor;

  @override
  SeedColourTheme copyWith({Color? seedColor}) {
    return SeedColourTheme(seedColor ?? this.seedColor);
  }

  @override
  SeedColourTheme lerp(ThemeExtension<SeedColourTheme>? other, double t) {
    if (other is! SeedColourTheme) {
      return this;
    }

    return SeedColourTheme(
      Color.lerp(seedColor, other.seedColor, t) ?? seedColor,
    );
  }
}

extension SeedColourThemeDataX on ThemeData {
  Color get seedColor =>
      extension<SeedColourTheme>()?.seedColor ?? _defaultSeedColor;

  Color get seedColour => seedColor;
}

const thinDivider = Divider(height: 0, color: Color(0xff7b7b7b));
const mapGridColour = Colors.blue;
const polygonColour = Colors.blue;
const tickedColour = Color(0xFF3DD700);
const untickedColour = Color(0xFFD66A6D);
const clusterFillColourPrimary = Colors.white;
const clusterFillColourSecondary = Color(0xFFFFF3B0);

// Font Colours

const clusterCountTextColour = Color(0xFF1E2A44);

class MapChartHoverDotTheme {
  static const Color color = Color(0xFF12B886);
  static const double size = 14;
}

TextStyle mapRulerTextStyle(BuildContext context) {
  return TextStyle(
    fontSize: 12,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

TextStyle clusterCountTextStyle() {
  return TextStyle(
    color: clusterCountTextColour,
    fontSize: 11,
    fontWeight: FontWeight.w700,
  );
}

class TrailDisplayTheme {
  static const Color baseColor = Color(0xFF52C66F);
  static const Color overlayColor = Color(0xFF000000);
  static const double baseStrokeWidth = 4;
  static const double overlayStrokeWidth = 1;
  static const List<double> overlayDashSegments = [8, 6];
}

const defaultMarkerColour = Colors.pinkAccent;
const favouriteMarkerColour = Colors.pinkAccent;
const homeMarkerColour = Color(0xFF3DD700);

@immutable
class RowHoverTheme extends ThemeExtension<RowHoverTheme> {
  const RowHoverTheme({
    required this.hoverColor,
    required this.hoveredTextColor,
  });

  final Color hoverColor;
  final Color hoveredTextColor;

  static const light = RowHoverTheme(
    hoverColor: Color(0xFFE8ECFF),
    hoveredTextColor: Color(0xFF4C4F69),
  );

  static const dark = RowHoverTheme(
    hoverColor: Color(0xFF2A214B),
    hoveredTextColor: Color(0xFFA89FFF),
  );

  @override
  RowHoverTheme copyWith({Color? hoverColor, Color? hoveredTextColor}) {
    return RowHoverTheme(
      hoverColor: hoverColor ?? this.hoverColor,
      hoveredTextColor: hoveredTextColor ?? this.hoveredTextColor,
    );
  }

  @override
  RowHoverTheme lerp(ThemeExtension<RowHoverTheme>? other, double t) {
    if (other is! RowHoverTheme) {
      return this;
    }

    return RowHoverTheme(
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t) ?? hoverColor,
      hoveredTextColor:
          Color.lerp(hoveredTextColor, other.hoveredTextColor, t) ??
          hoveredTextColor,
    );
  }
}

class MapMarkerTheme {
  const MapMarkerTheme({
    this.fillColor = defaultMarkerColour,
    this.iconColor = Colors.white,
    this.markerSize = 28.0,
    this.iconSize = 16.0,
    this.borderWidth = 3.0,
    this.borderColor = Colors.white,
    this.boxShadow = const [
      BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2)),
    ],
  });

  final Color fillColor;
  final Color iconColor;
  final double markerSize;
  final double iconSize;
  final double borderWidth;
  final Color borderColor;
  final List<BoxShadow> boxShadow;
}

final class FavouriteMapMarkerTheme extends MapMarkerTheme {
  const FavouriteMapMarkerTheme() : super(fillColor: favouriteMarkerColour);

  static const value = FavouriteMapMarkerTheme();
}

final class HomeMapMarkerTheme extends MapMarkerTheme {
  const HomeMapMarkerTheme() : super(fillColor: homeMarkerColour);

  static const value = HomeMapMarkerTheme();
}

abstract final class TrackRouteLineTheme {
  static const double strokeWidth = 3.0;
  static const double inactiveOpacity = 0.6;
  static const double selectedStrokeWidth = 4.0;
  static const double selectedBorderStrokeWidth = 2.0;
  static const Color selectedBorderColor = Color(0x66000000);
  static const Color selectedOverlayColor = Colors.white;
  static const double selectedOverlayStrokeWidth = 0.6;
}

const outlineColour = Color(0xFFF7F8FD);
const outlineTextColour = Color(0xFF111111);

class OutlinedText extends StatelessWidget {
  const OutlinedText({
    required this.text,
    super.key,
    this.style,
    this.textColor,
    this.outlineColor,
    this.textAlign = TextAlign.center,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
    this.softWrap = true,
  });

  final String text;
  final TextStyle? style;
  final Color? textColor;
  final Color? outlineColor;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodySmall ?? const TextStyle();
    final fillStyle = baseStyle.copyWith(color: textColor ?? outlineTextColour);
    final outlineStyle = baseStyle.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = outlineColor ?? outlineColour,
    );

    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          style: outlineStyle,
        ),
        Text(
          text,
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: overflow,
          softWrap: softWrap,
          style: fillStyle,
        ),
      ],
    );
  }
}

double peakMarkerLabelMaxWidth(BuildContext context) {
  final theme = Theme.of(context);
  final style = theme.textTheme.bodySmall ?? const TextStyle();
  final text = 'M' * MapConstants.peakInfoLabelMaxCharacters;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
  )..layout();
  return painter.width.ceilToDouble();
}

TextStyle peakMarkerLabelTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 10,
        fontStyle: FontStyle.italic,
      ) ??
      const TextStyle(fontSize: 10, fontStyle: FontStyle.italic);
}

TextStyle favouriteMarkerLabelTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 12,
        fontStyle: FontStyle.italic,
      ) ??
      const TextStyle(fontSize: 12, fontStyle: FontStyle.italic);
}

@immutable
class SelectedButtonThemeData extends ThemeExtension<SelectedButtonThemeData> {
  const SelectedButtonThemeData({required this.style});

  final ButtonStyle style;

  @override
  SelectedButtonThemeData copyWith({ButtonStyle? style}) {
    return SelectedButtonThemeData(style: style ?? this.style);
  }

  @override
  SelectedButtonThemeData lerp(
    covariant ThemeExtension<SelectedButtonThemeData>? other,
    double t,
  ) {
    if (other is! SelectedButtonThemeData) return this;
    return SelectedButtonThemeData(
      style: ButtonStyle.lerp(style, other.style, t)!,
    );
  }
}

@immutable
class SearchButtonThemeData extends ThemeExtension<SearchButtonThemeData> {
  const SearchButtonThemeData({
    required this.selectedStyle,
    required this.unselectedStyle,
  });

  final ButtonStyle selectedStyle;
  final ButtonStyle unselectedStyle;

  ButtonStyle styleFor(bool isSelected) {
    return isSelected ? selectedStyle : unselectedStyle;
  }

  @override
  SearchButtonThemeData copyWith({
    ButtonStyle? selectedStyle,
    ButtonStyle? unselectedStyle,
  }) {
    return SearchButtonThemeData(
      selectedStyle: selectedStyle ?? this.selectedStyle,
      unselectedStyle: unselectedStyle ?? this.unselectedStyle,
    );
  }

  @override
  SearchButtonThemeData lerp(
    covariant ThemeExtension<SearchButtonThemeData>? other,
    double t,
  ) {
    if (other is! SearchButtonThemeData) return this;
    return SearchButtonThemeData(
      selectedStyle: ButtonStyle.lerp(selectedStyle, other.selectedStyle, t)!,
      unselectedStyle: ButtonStyle.lerp(
        unselectedStyle,
        other.unselectedStyle,
        t,
      )!,
    );
  }
}

const searchControlIconSize = PopupUIConstants.searchIconSize;
const searchControlFontSize = 12.0;
const _searchButtonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const _searchButtonMinimumSize = Size(0, 30);

FilledButtonThemeData _filledButtonTheme(ColorScheme colorScheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
    ),
  );
}

TextButtonThemeData _textButtonTheme(ColorScheme colorScheme, Color seedColor) {
  return TextButtonThemeData(
    style: TextButton.styleFrom(foregroundColor: lighten(seedColor, 0.08)),
  );
}

OutlinedButtonThemeData _outlinedButtonTheme(
  ColorScheme colorScheme,
  Color seedColor,
) {
  return OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: seedColor,
      side: BorderSide(color: colorScheme.outline),
    ),
  );
}

SearchButtonThemeData _searchButtonTheme(ColorScheme colorScheme, Color seedColor) {
  return SearchButtonThemeData(
    selectedStyle: ButtonStyle(
      padding: const WidgetStatePropertyAll(_searchButtonPadding),
      minimumSize: const WidgetStatePropertyAll(_searchButtonMinimumSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        return colorScheme.primary;
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return lighten(colorScheme.primaryContainer, 0.08);
        }
        return colorScheme.primaryContainer;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: lighten(colorScheme.primary, 0.12));
        }
        return BorderSide(color: colorScheme.primary);
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.primary.withValues(alpha: 0.08);
        }
        return null;
      }),
    ),
    unselectedStyle: ButtonStyle(
      padding: const WidgetStatePropertyAll(_searchButtonPadding),
      minimumSize: const WidgetStatePropertyAll(_searchButtonMinimumSize),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.primary;
        }
        return lighten(seedColor, 0.12);
      }),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return colorScheme.primaryContainer.withValues(alpha: 0.5);
        }
        return colorScheme.surface;
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return BorderSide(color: colorScheme.onSurface.withValues(alpha: 0.38));
        }
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: colorScheme.primary);
        }
        return BorderSide(color: lighten(seedColor, 0.12));
      }),
      overlayColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return seedColor.withValues(alpha: 0.08);
        }
        return null;
      }),
    ),
  );
}

class MyTheme {
  static ThemeData get dark => darkWith(_defaultThemeConfig);
  static ThemeData get light => lightWith(_defaultThemeConfig);

  static ThemeData darkWith(ThemeConfig config) => _createDarkTheme(config);

  static ThemeData lightWith(ThemeConfig config) => _createLightTheme(config);

  static ColorScheme _withOutlineVariantMatchingPrimary(ColorScheme scheme) {
    return scheme.copyWith(outlineVariant: scheme.onPrimary);
  }

  static ColorScheme _darkColorScheme(ThemeConfig config) {
    return _withOutlineVariantMatchingPrimary(
      ColorScheme.fromSeed(
        seedColor: config.seedColor,
        brightness: Brightness.dark,
        dynamicSchemeVariant: config.dynamicSchemeVariant,
        contrastLevel: config.contrastLevel,
      ),
    );
  }

  static ThemeData _createDarkTheme(ThemeConfig config) {
    final colorScheme = _darkColorScheme(config);
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      filledButtonTheme: _filledButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme, config.seedColor),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, config.seedColor),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x66000000),
      ),
      iconTheme: IconThemeData(color: colorScheme.onPrimaryContainer, size: 24),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: colorScheme.onSurface),
      ),
      extensions: [
        SeedColourTheme(config.seedColor),
        RowHoverTheme.dark,
        ChartSeriesTheme.fromColorScheme(colorScheme),
        _searchButtonTheme(colorScheme, config.seedColor),
      ],
    );
  }

  static ColorScheme _lightColorScheme(ThemeConfig config) {
    return _withOutlineVariantMatchingPrimary(
      ColorScheme.fromSeed(
        seedColor: config.seedColor,
        brightness: Brightness.light,
        dynamicSchemeVariant: config.dynamicSchemeVariant,
        contrastLevel: config.contrastLevel,
      ),
    );
  }

  static ThemeData _createLightTheme(ThemeConfig config) {
    final colorScheme = _lightColorScheme(config);
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      filledButtonTheme: _filledButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme, config.seedColor),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, config.seedColor),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x33000000),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      textTheme: TextTheme(
        bodyLarge: TextStyle(color: colorScheme.onSurface),
        bodyMedium: TextStyle(color: colorScheme.onSurface),
        bodySmall: TextStyle(color: colorScheme.onSurface),
        titleLarge: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: colorScheme.onSurface,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: colorScheme.onSurface),
      ),
      extensions: [
        SeedColourTheme(config.seedColor),
        RowHoverTheme.light,
        ChartSeriesTheme.fromColorScheme(colorScheme),
        _searchButtonTheme(colorScheme, config.seedColor),
      ],
    );
  }
}
