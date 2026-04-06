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

    test('dark theme uses Mocha blue as primary', () {
      final theme = CatppuccinColors.dark;
      expect(theme.colorScheme.primary, const Color(0xFF89B4FA));
    });

    test('light theme uses Latte blue as primary', () {
      final theme = CatppuccinColors.light;
      expect(theme.colorScheme.primary, const Color(0xFF1E66F5));
    });

    test('dark theme uses Mocha pink as secondary', () {
      final theme = CatppuccinColors.dark;
      expect(theme.colorScheme.secondary, const Color(0xFFCBA6F7));
    });

    test('light theme uses Latte mauve as secondary', () {
      final theme = CatppuccinColors.light;
      expect(theme.colorScheme.secondary, const Color(0xFF8839EF));
    });

    test('dark theme uses Mocha base as scaffold background', () {
      final theme = CatppuccinColors.dark;
      expect(theme.scaffoldBackgroundColor, const Color(0xFF1E1E2E));
    });

    test('light theme uses Latte base as scaffold background', () {
      final theme = CatppuccinColors.light;
      expect(theme.scaffoldBackgroundColor, const Color(0xFFEFF1F5));
    });
  });
}
