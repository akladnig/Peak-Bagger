import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

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

class CatppuccinColors {
  static ThemeData get dark => _createDarkTheme();
  static ThemeData get light => _createLightTheme();

  static ThemeData _createDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6347EA),
        onPrimary: Color(0xFFA89FFF),
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
      ),
      scaffoldBackgroundColor: const Color(0xFF111111),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF111111),
        foregroundColor: Color(0xFFCDD6F4),
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x66000000),
      ),
      iconTheme: const IconThemeData(color: Color(0xFFFFFFFF), size: 24),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFCDD6F4)),
        bodyMedium: TextStyle(color: Color(0xFFCDD6F4)),
        bodySmall: TextStyle(color: Color(0xFFBAC2DE)),
        titleLarge: TextStyle(
          color: Color(0xFFCDD6F4),
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Color(0xFFCDD6F4),
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: Color(0xFFBAC2DE)),
      ),
      extensions: const [RowHoverTheme.dark],
    );
  }

  static ThemeData _createLightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1E66F5),
        onPrimary: Color(0xFF4C4F69),
        secondary: Color(0xFF8839EF),
        onSecondary: Color(0xFF4C4F69),
        surface: Color(0xFFEFF1F5),
        onSurface: Color(0xFF4C4F69),
        error: Color(0xFFD20F39),
        onError: Color(0xFF4C4F69),
      ),
      scaffoldBackgroundColor: const Color(0xFFEFF1F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFCCD0DA),
        foregroundColor: Color(0xFF4C4F69),
        elevation: 2,
        surfaceTintColor: Colors.transparent,
        shadowColor: Color(0x33000000),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF4C4F69), size: 24),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF4C4F69)),
        bodyMedium: TextStyle(color: Color(0xFF4C4F69)),
        bodySmall: TextStyle(color: Color(0xFF5C5F77)),
        titleLarge: TextStyle(
          color: Color(0xFF4C4F69),
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: Color(0xFF4C4F69),
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(color: Color(0xFF5C5F77)),
      ),
      extensions: const [RowHoverTheme.light],
    );
  }
}
