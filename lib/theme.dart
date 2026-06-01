import 'package:flutter/material.dart';
import 'package:peak_bagger/core/constants.dart';

const thinDivider = Divider(height: 0, color: Color(0xff7b7b7b));
const mapGridColour = Colors.blue;

TextStyle mapRulerTextStyle(BuildContext context) {
  return TextStyle(
    fontSize: 12,
    color: Theme.of(context).colorScheme.onSurface,
  );
}

class TrailDisplayTheme {
  static const Color baseColor = Color(0xFF52C66F);
  static const Color overlayColor = Color(0xFF000000);
  static const double baseStrokeWidth = 4;
  static const double overlayStrokeWidth = 1;
  static const List<double> overlayDashSegments = [8, 6];
}

class OutlinedText extends StatelessWidget {
  const OutlinedText({
    required this.text,
    super.key,
    this.style,
    this.textAlign = TextAlign.center,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = true,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = style ?? theme.textTheme.bodySmall ?? const TextStyle();
    final fillStyle = baseStyle.copyWith(color: theme.colorScheme.surface);
    final outlineStyle = baseStyle.copyWith(
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = theme.colorScheme.onSurface,
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
    );
  }
}
