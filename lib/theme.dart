import 'package:flutter/material.dart';

const thinDivider = Divider(height: 0, color: Color(0xff7b7b7b));

class CatppuccinColors {
  static ThemeData get dark => _createDarkTheme();
  static ThemeData get light => _createLightTheme();

  static ThemeData _createDarkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        // onPrimary: Color(0xFFCDD6F4),
        // primary: Color(0xFF89B4FA),
        primary: Color(0xFF6347EA),
        onPrimary: Color(0xFFA89FFF),
        secondary: Color(0xFF2A2A2A),
        onSecondary: Color(0xFFCDD6F4),
        primaryContainer: Color(0xFF221B52),
        onPrimaryContainer: Colors.white,
        // surface: Color(0xFF1E1E2E),
        surface: Color(0xFF111111),
        onSurface: Color(0xFFCDD6F4),
        error: Color(0xFFF38BA8),
        onError: Color(0xFFCDD6F4),
      ),
      // scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      scaffoldBackgroundColor: const Color(0xFF111111),
      appBarTheme: const AppBarTheme(
        // backgroundColor: Color(0xFF313244),
        backgroundColor: Color(0xFF111111),
        // backgroundColor: Color(0xFF221B52),
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
