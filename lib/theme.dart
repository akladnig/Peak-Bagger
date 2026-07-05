import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

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

const searchControlIconSize = PopupUIConstants.closeIconSize;
const searchControlFontSize = 11.0;
const _searchButtonPadding = EdgeInsets.symmetric(horizontal: 10, vertical: 8);
const _searchButtonMinimumSize = Size(0, 30);

class CatppuccinColors {
  static ThemeData get dark => _createDarkTheme();
  static ThemeData get light => _createLightTheme();

  static ThemeData _createDarkTheme() {
    const colorScheme = ColorScheme.dark(
      primary: Color(0xFF6347EA),
      onPrimary: Color(0xFFEBE8FC),
      secondary: Color(0xFF191919),
      onSecondary: Color(0xFFCDD6F4),
      tertiary: Color(0xFF2A2A2A),
      onTertiary: Color(0xFFCDD6F4),
      primaryContainer: Color(0xFF221B52),
      onPrimaryContainer: Colors.white,
      surface: Color(0xFF111111),
      onSurface: Color(0xFFCDD6F4),
      surfaceContainer: Color(0xFF191919),
      outline: Color(0xFF7B7B7B),
      outlineVariant: Color(0xFF6347EA),
      error: Color(0xFFF38BA8),
      onError: Color(0xFFCDD6F4),
    );
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
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
        RowHoverTheme.dark,
        SearchButtonThemeData(
          selectedStyle: ButtonStyle(
            padding: const WidgetStatePropertyAll(_searchButtonPadding),
            minimumSize: const WidgetStatePropertyAll(_searchButtonMinimumSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return colorScheme.onSurface.withValues(alpha: 0.38);
              }
              if (states.contains(WidgetState.hovered)) {
                return colorScheme.onPrimaryContainer;
              }
              return colorScheme.onPrimary;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return darken(colorScheme.primary, 0.08);
              }
              return darken(colorScheme.primary, 0.24);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return BorderSide(color: lighten(colorScheme.primary, 0.12));
              }
              return BorderSide(color: colorScheme.primary);
            }),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x1AFFFFFF);
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
                return colorScheme.onPrimary;
              }
              return colorScheme.onSurface;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return darken(colorScheme.primary, 0.4);
              }
              return colorScheme.surface;
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return BorderSide(color: colorScheme.primary);
              }
              return BorderSide(color: colorScheme.outline);
            }),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x146347EA);
              }
              return null;
            }),
          ),
        ),
      ],
    );
  }

  static ThemeData _createLightTheme() {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF6347EA),
      onPrimary: Color(0xFF4C4F69),
      secondary: Color(0xFFDCE0E8),
      onSecondary: Color(0xFF4C4F69),
      tertiary: Color(0xFFBCC0CC),
      onTertiary: Color(0xFF4C4F69),
      primaryContainer: Color(0xFFCCD0DA),
      onPrimaryContainer: Color(0xFF4C4F69),
      surface: Color(0xFFEFF1F5),
      onSurface: Color(0xFF4C4F69),
      surfaceContainer: Color(0xFFDCE0E8),
      outline: Color(0xFF9CA0B0),
      outlineVariant: Color(0xFF6347EA),
      error: Color(0xFFD20F39),
      onError: Color(0xFF4C4F69),
    );
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
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
        RowHoverTheme.light,
        SearchButtonThemeData(
          selectedStyle: ButtonStyle(
            padding: const WidgetStatePropertyAll(_searchButtonPadding),
            minimumSize: const WidgetStatePropertyAll(_searchButtonMinimumSize),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
            foregroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.disabled)) {
                return colorScheme.onSurface.withValues(alpha: 0.38);
              }
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFFFFFFF);
              }
              return const Color(0xFF1E66F5);
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFF184FC6);
              }
              return const Color(0xFFDCE7FF);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const BorderSide(color: Color(0xFF3B82F6));
              }
              return const BorderSide(color: Color(0xFF1E66F5));
            }),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x14000000);
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
                return const Color(0xFF1E66F5);
              }
              return colorScheme.onSurface;
            }),
            backgroundColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0xFFDCE7FF);
              }
              return const Color(0x00000000);
            }),
            side: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const BorderSide(color: Color(0xFF1E66F5));
              }
              return BorderSide(color: colorScheme.outline);
            }),
            overlayColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.hovered)) {
                return const Color(0x12000000);
              }
              return null;
            }),
          ),
        ),
      ],
    );
  }
}
