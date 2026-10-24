import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

const _defaultSeedColor = Color(0xFF7E47EB);

/// Compact pointer/keyboard controls for the shared Dashboard toolbar.
ButtonStyle dashboardNavigationButtonStyle(ColorScheme colors) => ButtonStyle(
  minimumSize: const WidgetStatePropertyAll(Size(32, 32)),
  padding: const WidgetStatePropertyAll(EdgeInsets.all(4)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  foregroundColor: WidgetStateProperty.resolveWith(
    (states) => colors.onSurface.withValues(
      alpha: states.contains(WidgetState.disabled) ? 0.38 : 1,
    ),
  ),
  overlayColor: WidgetStateProperty.resolveWith(
    (states) => colors.onSurface.withValues(
      alpha: states.contains(WidgetState.focused)
          ? 0.16
          : states.contains(WidgetState.pressed)
          ? 0.12
          : 0.08,
    ),
  ),
);

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

@immutable
class DataGridTheme extends ThemeExtension<DataGridTheme> {
  const DataGridTheme({
    required this.headerPadding,
    required this.rowPadding,
    required this.columnGap,
    required this.headerTextStyle,
    required this.rowTextStyle,
    required this.dividerColor,
    required this.dividerThickness,
    required this.hoverColor,
    required this.hoveredTextColor,
    required this.pressedRowColor,
    required this.selectedRowColor,
    required this.selectedRowBorderColor,
    required this.focusBorder,
  });

  final EdgeInsetsGeometry headerPadding;
  final EdgeInsetsGeometry rowPadding;
  final double columnGap;
  final TextStyle headerTextStyle;
  final TextStyle rowTextStyle;
  final Color dividerColor;
  final double dividerThickness;
  final Color hoverColor;
  final Color hoveredTextColor;
  final Color pressedRowColor;
  final Color selectedRowColor;
  final Color selectedRowBorderColor;
  final BorderSide focusBorder;

  static DataGridTheme fromColorScheme(
    ColorScheme colorScheme,
    TextTheme textTheme, {
    Color? seedColor,
  }) {
    final selectionBase = colorScheme.brightness == Brightness.dark
        ? seedColor ?? _defaultSeedColor
        : colorScheme.primaryContainer;
    final selected = darken(selectionBase, 0.30);
    return DataGridTheme(
      headerPadding: const EdgeInsets.symmetric(vertical: 4),
      rowPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      columnGap: 12,
      headerTextStyle: textTheme.labelLarge ?? const TextStyle(),
      rowTextStyle: textTheme.bodyMedium ?? const TextStyle(),
      dividerColor: colorScheme.onPrimary,
      dividerThickness: 1,
      hoverColor: Color.lerp(selected, Colors.white, 0.10)!,
      hoveredTextColor: colorScheme.onSurface,
      pressedRowColor: selectedModeFill(colorScheme),
      selectedRowColor: selected,
      selectedRowBorderColor: darken(selectionBase, 0.08),
      focusBorder: BorderSide(color: colorScheme.primary, width: 2),
    );
  }

  @override
  DataGridTheme copyWith({
    EdgeInsetsGeometry? headerPadding,
    EdgeInsetsGeometry? rowPadding,
    double? columnGap,
    TextStyle? headerTextStyle,
    TextStyle? rowTextStyle,
    Color? dividerColor,
    double? dividerThickness,
    Color? hoverColor,
    Color? hoveredTextColor,
    Color? pressedRowColor,
    Color? selectedRowColor,
    Color? selectedRowBorderColor,
    BorderSide? focusBorder,
  }) {
    return DataGridTheme(
      headerPadding: headerPadding ?? this.headerPadding,
      rowPadding: rowPadding ?? this.rowPadding,
      columnGap: columnGap ?? this.columnGap,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      rowTextStyle: rowTextStyle ?? this.rowTextStyle,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerThickness: dividerThickness ?? this.dividerThickness,
      hoverColor: hoverColor ?? this.hoverColor,
      hoveredTextColor: hoveredTextColor ?? this.hoveredTextColor,
      pressedRowColor: pressedRowColor ?? this.pressedRowColor,
      selectedRowColor: selectedRowColor ?? this.selectedRowColor,
      selectedRowBorderColor:
          selectedRowBorderColor ?? this.selectedRowBorderColor,
      focusBorder: focusBorder ?? this.focusBorder,
    );
  }

  @override
  DataGridTheme lerp(ThemeExtension<DataGridTheme>? other, double t) {
    if (other is! DataGridTheme) {
      return this;
    }

    return DataGridTheme(
      headerPadding:
          EdgeInsetsGeometry.lerp(headerPadding, other.headerPadding, t) ??
          headerPadding,
      rowPadding:
          EdgeInsetsGeometry.lerp(rowPadding, other.rowPadding, t) ??
          rowPadding,
      columnGap: lerpDouble(columnGap, other.columnGap, t) ?? columnGap,
      headerTextStyle:
          TextStyle.lerp(headerTextStyle, other.headerTextStyle, t) ??
          headerTextStyle,
      rowTextStyle:
          TextStyle.lerp(rowTextStyle, other.rowTextStyle, t) ?? rowTextStyle,
      dividerColor:
          Color.lerp(dividerColor, other.dividerColor, t) ?? dividerColor,
      dividerThickness:
          lerpDouble(dividerThickness, other.dividerThickness, t) ??
          dividerThickness,
      hoverColor: Color.lerp(hoverColor, other.hoverColor, t) ?? hoverColor,
      hoveredTextColor:
          Color.lerp(hoveredTextColor, other.hoveredTextColor, t) ??
          hoveredTextColor,
      pressedRowColor:
          Color.lerp(pressedRowColor, other.pressedRowColor, t) ??
          pressedRowColor,
      selectedRowColor:
          Color.lerp(selectedRowColor, other.selectedRowColor, t) ??
          selectedRowColor,
      selectedRowBorderColor:
          Color.lerp(selectedRowBorderColor, other.selectedRowBorderColor, t) ??
          selectedRowBorderColor,
      focusBorder: BorderSide.lerp(focusBorder, other.focusBorder, t),
    );
  }
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

const searchControlIconSize = 24.0;
const searchControlFontSize = 14.0;

/// Selection-only dropdown metrics and semantic roles, shared by every caller.
abstract final class SharedDropdownStyle {
  static const radius = 12.0;
  static const minimumTarget = 48.0;
  static const minimumRowHeight = 40.0;
  static const optionPadding = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 8,
  );
  static const checkSize = 24.0;
  static const iconSize = 24.0;
  static const gap = 12.0;
  static const viewportMargin = 8.0;
  static const elevation = 3.0;

  static TextStyle valueText(ThemeData theme) =>
      theme.textTheme.titleMedium!.copyWith(color: theme.colorScheme.onSurface);
  static TextStyle menuText(ThemeData theme) => theme.textTheme.bodySmall!
      .copyWith(fontSize: 12, color: theme.colorScheme.onSurface);
  static Color rowFill(ThemeData theme, {bool pressed = false}) =>
      Color.alphaBlend(
        theme.colorScheme.onSurface.withValues(alpha: pressed ? .12 : .08),
        theme.colorScheme.surfaceContainer,
      );
  static Color tick(
    ThemeData theme, {
    bool error = false,
    bool disabled = false,
  }) {
    final color = error ? theme.colorScheme.error : theme.seedColor;
    return disabled ? color.withValues(alpha: .38) : color;
  }
}

/// Shared Schema/Data selection and pointer-hover layers, composited once.
Color selectedModeFill(ColorScheme colors) =>
    Color.alphaBlend(colors.primary.withValues(alpha: .12), colors.surface);

Color hoveredSelectedModeFill(ColorScheme colors) => Color.alphaBlend(
  colors.primary.withValues(alpha: .08),
  selectedModeFill(colors),
);

InputDecorationThemeData _inputDecorationTheme(
  ColorScheme colors,
  Color seedColor,
) => InputDecorationThemeData(
  labelStyle: TextStyle(
    fontSize: searchControlFontSize,
    color: colors.onSurface,
  ),
  floatingLabelBehavior: FloatingLabelBehavior.always,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  border: OutlineInputBorder(borderSide: BorderSide(color: colors.onPrimary)),
  filled: true,
  // Resolve the complete fill here; InputDecorator must not add a second layer.
  hoverColor: Colors.transparent,
  fillColor: WidgetStateColor.resolveWith((states) {
    if (!states.contains(WidgetState.disabled) &&
        states.contains(WidgetState.hovered)) {
      return hoveredSelectedModeFill(colors);
    }
    return colors.surface;
  }),
  // Filled outlined fields use activeIndicatorBorder when enabledBorder is null.
  activeIndicatorBorder: WidgetStateBorderSide.resolveWith((states) {
    if (states.contains(WidgetState.disabled)) {
      return BorderSide(color: colors.onSurface.withValues(alpha: .38));
    }
    if (states.contains(WidgetState.error)) {
      return BorderSide(color: colors.error);
    }
    return BorderSide(
      color: states.contains(WidgetState.hovered) ? seedColor : colors.outline,
    );
  }),
  focusedBorder: OutlineInputBorder(
    borderSide: BorderSide(color: seedColor, width: 2),
  ),
  errorBorder: OutlineInputBorder(borderSide: BorderSide(color: colors.error)),
  focusedErrorBorder: OutlineInputBorder(
    borderSide: BorderSide(color: colors.error, width: 2),
  ),
  disabledBorder: OutlineInputBorder(
    borderSide: BorderSide(color: colors.onSurface.withValues(alpha: .38)),
  ),
);

IconButtonThemeData _iconButtonTheme(ColorScheme colors) => IconButtonThemeData(
  style: ButtonStyle(
    shape: const WidgetStatePropertyAll(CircleBorder()),
    backgroundColor: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.disabled)) return Colors.transparent;
      if (states.contains(WidgetState.pressed)) {
        return colors.onSurface.withValues(alpha: .12);
      }
      if (states.contains(WidgetState.hovered)) {
        return colors.onSurface.withValues(alpha: .08);
      }
      return Colors.transparent;
    }),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) => colors.onSurface.withValues(
        alpha: states.contains(WidgetState.disabled) ? .38 : 1,
      ),
    ),
    // Paint the circular state layer once, without an additional ink overlay.
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    side: WidgetStateProperty.resolveWith(
      (states) =>
          !states.contains(WidgetState.disabled) &&
              states.contains(WidgetState.focused)
          ? BorderSide(color: colors.primary, width: 2)
          : BorderSide.none,
    ),
    mouseCursor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled)
          ? SystemMouseCursors.basic
          : SystemMouseCursors.click,
    ),
  ),
);
const _searchButtonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const _searchButtonMinimumSize = Size(0, 30);

FilledButtonThemeData _filledButtonTheme(ColorScheme colorScheme) {
  return FilledButtonThemeData(
    style: FilledButton.styleFrom(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

SearchButtonThemeData _searchButtonTheme(
  ColorScheme colorScheme,
  Color seedColor,
) {
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
        if (!states.contains(WidgetState.disabled) &&
            states.contains(WidgetState.hovered)) {
          return hoveredSelectedModeFill(colorScheme);
        }
        return selectedModeFill(colorScheme);
      }),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.hovered)) {
          return BorderSide(color: lighten(colorScheme.primary, 0.12));
        }
        return BorderSide(color: colorScheme.primary);
      }),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
          return BorderSide(
            color: colorScheme.onSurface.withValues(alpha: 0.38),
          );
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

  static ColorScheme _darkColorScheme(ThemeConfig config) {
    return ColorScheme.fromSeed(
      seedColor: config.seedColor,
      brightness: Brightness.dark,
      dynamicSchemeVariant: config.dynamicSchemeVariant,
      contrastLevel: config.contrastLevel,
    );
  }

  static ThemeData _createDarkTheme(ThemeConfig config) {
    final colorScheme = _darkColorScheme(config);
    final textTheme = _textTheme(colorScheme);
    final resolvedTextTheme = _resolvedTextTheme(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      filledButtonTheme: _filledButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme, config.seedColor),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, config.seedColor),
      inputDecorationTheme: _inputDecorationTheme(
        colorScheme,
        config.seedColor,
      ),
      iconButtonTheme: _iconButtonTheme(colorScheme),
      toggleButtonsTheme: ToggleButtonsThemeData(
        fillColor: selectedModeFill(colorScheme),
        selectedColor: colorScheme.primary,
        hoverColor: colorScheme.primary.withValues(alpha: .08),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x66000000),
      ),
      iconTheme: IconThemeData(color: colorScheme.onPrimaryContainer, size: 24),
      textTheme: textTheme,
      extensions: [
        SeedColourTheme(config.seedColor),
        RowHoverTheme.dark,
        DataGridTheme.fromColorScheme(
          colorScheme,
          resolvedTextTheme,
          seedColor: config.seedColor,
        ),
        ChartSeriesTheme.fromColorScheme(colorScheme),
        _searchButtonTheme(colorScheme, config.seedColor),
      ],
    );
  }

  static ColorScheme _lightColorScheme(ThemeConfig config) {
    return ColorScheme.fromSeed(
      seedColor: config.seedColor,
      brightness: Brightness.light,
      dynamicSchemeVariant: config.dynamicSchemeVariant,
      contrastLevel: config.contrastLevel,
    );
  }

  static ThemeData _createLightTheme(ThemeConfig config) {
    final colorScheme = _lightColorScheme(config);
    final textTheme = _textTheme(colorScheme);
    final resolvedTextTheme = _resolvedTextTheme(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      filledButtonTheme: _filledButtonTheme(colorScheme),
      textButtonTheme: _textButtonTheme(colorScheme, config.seedColor),
      outlinedButtonTheme: _outlinedButtonTheme(colorScheme, config.seedColor),
      inputDecorationTheme: _inputDecorationTheme(
        colorScheme,
        config.seedColor,
      ),
      iconButtonTheme: _iconButtonTheme(colorScheme),
      toggleButtonsTheme: ToggleButtonsThemeData(
        fillColor: selectedModeFill(colorScheme),
        selectedColor: colorScheme.primary,
        hoverColor: colorScheme.primary.withValues(alpha: .08),
      ),
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x33000000),
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurface, size: 24),
      textTheme: textTheme,
      extensions: [
        SeedColourTheme(config.seedColor),
        RowHoverTheme.light,
        DataGridTheme.fromColorScheme(
          colorScheme,
          resolvedTextTheme,
          seedColor: config.seedColor,
        ),
        ChartSeriesTheme.fromColorScheme(colorScheme),
        _searchButtonTheme(colorScheme, config.seedColor),
      ],
    );
  }

  static TextTheme _textTheme(ColorScheme colorScheme) {
    return TextTheme(
      bodyLarge: TextStyle(color: colorScheme.onSurface),
      bodyMedium: TextStyle(color: colorScheme.onSurface),
      bodySmall: TextStyle(color: colorScheme.onSurface),
      labelLarge: TextStyle(color: colorScheme.onSurface),
      titleLarge: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(color: colorScheme.onSurface),
    );
  }

  static TextTheme _resolvedTextTheme({
    required Brightness brightness,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
    ).textTheme;
  }
}
