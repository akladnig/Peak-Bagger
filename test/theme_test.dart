import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  group('CatppuccinColors', () {
    test('dark theme has dark brightness', () {
      final theme = CatppuccinColors.dark;
      expect(theme.brightness, Brightness.dark);
    });

    test('light theme has light brightness', () {
      final theme = CatppuccinColors.light;
      expect(theme.brightness, Brightness.light);
    });

    test('dark theme uses configured primary color', () {
      final theme = CatppuccinColors.dark;
      expect(theme.colorScheme.primary, const Color(0xFF6347EA));
    });

    test('light theme uses Latte blue as primary', () {
      final theme = CatppuccinColors.light;
      expect(theme.colorScheme.primary, const Color(0xFF1E66F5));
    });

    test('dark theme uses configured secondary color', () {
      final theme = CatppuccinColors.dark;
      expect(theme.colorScheme.secondary, const Color(0xFF191919));
    });

    test('light theme defines explicit mirrored semantic roles', () {
      final theme = CatppuccinColors.light;

      expect(theme.colorScheme.secondary, const Color(0xFFDCE0E8));
      expect(theme.colorScheme.onSecondary, const Color(0xFF4C4F69));
      expect(theme.colorScheme.tertiary, const Color(0xFFBCC0CC));
      expect(theme.colorScheme.onTertiary, const Color(0xFF4C4F69));
      expect(theme.colorScheme.primaryContainer, const Color(0xFFCCD0DA));
      expect(theme.colorScheme.onPrimaryContainer, const Color(0xFF4C4F69));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFFDCE0E8));
      expect(theme.colorScheme.outline, const Color(0xFF9CA0B0));
      expect(theme.colorScheme.outlineVariant, const Color(0xFF1E66F5));
    });

    test('dark theme uses configured scaffold background', () {
      final theme = CatppuccinColors.dark;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF111111));
    });

    test('light theme uses Latte base as scaffold background', () {
      final theme = CatppuccinColors.light;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFEFF1F5));
    });

    test('light app bar mirrors dark theme structure with light values', () {
      final theme = CatppuccinColors.light;

      expect(
        theme.appBarTheme.backgroundColor,
        theme.scaffoldBackgroundColor,
      );
      expect(theme.appBarTheme.foregroundColor, const Color(0xFF4C4F69));
      expect(theme.appBarTheme.elevation, 2);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.shadowColor, const Color(0x33000000));
    });

    test('both themes keep icon defaults aligned with onPrimaryContainer', () {
      final darkTheme = CatppuccinColors.dark;
      final lightTheme = CatppuccinColors.light;

      expect(
        darkTheme.iconTheme.color,
        darkTheme.colorScheme.onPrimaryContainer,
      );
      expect(
        lightTheme.iconTheme.color,
        lightTheme.colorScheme.onPrimaryContainer,
      );
    });

    test('both themes expose only live theme extensions', () {
      final darkTheme = CatppuccinColors.dark;
      final lightTheme = CatppuccinColors.light;

      expect(darkTheme.extension<RowHoverTheme>(), isNotNull);
      expect(lightTheme.extension<RowHoverTheme>(), isNotNull);
      expect(darkTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(lightTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(darkTheme.extension<SelectedButtonThemeData>(), isNull);
      expect(lightTheme.extension<SelectedButtonThemeData>(), isNull);
    });

    test('dark theme keeps existing guarded semantic roles', () {
      final theme = CatppuccinColors.dark;

      expect(theme.colorScheme.secondary, const Color(0xFF191919));
      expect(theme.colorScheme.onSecondary, const Color(0xFFCDD6F4));
      expect(theme.colorScheme.tertiary, const Color(0xFF2A2A2A));
      expect(theme.colorScheme.onTertiary, const Color(0xFFCDD6F4));
      expect(theme.colorScheme.primaryContainer, const Color(0xFF221B52));
      expect(theme.colorScheme.onPrimaryContainer, Colors.white);
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF191919));
      expect(theme.colorScheme.outline, const Color(0xFF7B7B7B));
      expect(theme.colorScheme.outlineVariant, const Color(0xFF6347EA));
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF111111));
      expect(theme.appBarTheme.foregroundColor, const Color(0xFFCDD6F4));
      expect(theme.appBarTheme.elevation, 2);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.shadowColor, const Color(0x66000000));
    });
  });
}
