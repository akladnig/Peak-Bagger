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

    test('light theme uses Latte mauve as secondary', () {
      final theme = CatppuccinColors.light;
      expect(theme.colorScheme.secondary, const Color(0xFF8839EF));
    });

    test('dark theme uses configured scaffold background', () {
      final theme = CatppuccinColors.dark;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF111111));
    });

    test('light theme uses Latte base as scaffold background', () {
      final theme = CatppuccinColors.light;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFEFF1F5));
    });
  });
}
