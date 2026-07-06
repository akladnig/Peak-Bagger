import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  group('MyTheme', () {
    test('dark theme has dark brightness', () {
      expect(MyTheme.dark.brightness, Brightness.dark);
    });

    test('light theme has light brightness', () {
      expect(MyTheme.light.brightness, Brightness.light);
    });

    test('default dark theme derives from My Seed Colour', () {
      final theme = MyTheme.dark;

      expect(
        theme.colorScheme,
        _expectedColorScheme(
          seedColor: defaultThemeSeedSwatch.color,
          brightness: Brightness.dark,
        ),
      );
      expect(theme.seedColor, defaultThemeSeedSwatch.color);
      expect(theme.seedColour, defaultThemeSeedSwatch.color);
    });

    test('default light theme derives from My Seed Colour', () {
      final theme = MyTheme.light;

      expect(
        theme.colorScheme,
        _expectedColorScheme(
          seedColor: defaultThemeSeedSwatch.color,
          brightness: Brightness.light,
        ),
      );
      expect(theme.seedColor, defaultThemeSeedSwatch.color);
    });

    test('custom seed color drives both light and dark color schemes', () {
      const themeConfig = ThemeConfig(
        seedColor: Color(0xFF00FF00),
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
        contrastLevel: 0.5,
      );

      expect(
        MyTheme.darkWith(themeConfig).colorScheme,
        _expectedColorScheme(
          seedColor: themeConfig.seedColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: themeConfig.dynamicSchemeVariant,
          contrastLevel: themeConfig.contrastLevel,
        ),
      );
      expect(
        MyTheme.lightWith(themeConfig).colorScheme,
        _expectedColorScheme(
          seedColor: themeConfig.seedColor,
          brightness: Brightness.light,
          dynamicSchemeVariant: themeConfig.dynamicSchemeVariant,
          contrastLevel: themeConfig.contrastLevel,
        ),
      );
    });

    test('both themes expose only live theme extensions', () {
      final darkTheme = MyTheme.dark;
      final lightTheme = MyTheme.light;

      expect(darkTheme.extension<RowHoverTheme>(), isNotNull);
      expect(lightTheme.extension<RowHoverTheme>(), isNotNull);
      expect(darkTheme.extension<SeedColourTheme>(), isNotNull);
      expect(lightTheme.extension<SeedColourTheme>(), isNotNull);
      expect(darkTheme.extension<ChartSeriesTheme>(), isNotNull);
      expect(lightTheme.extension<ChartSeriesTheme>(), isNotNull);
      expect(darkTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(lightTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(darkTheme.extension<SelectedButtonThemeData>(), isNull);
      expect(lightTheme.extension<SelectedButtonThemeData>(), isNull);
    });

    test('button themes are wired from the resolved color scheme', () {
      final darkTheme = MyTheme.dark;
      final lightTheme = MyTheme.light;

      expect(
        darkTheme.filledButtonTheme.style?.backgroundColor?.resolve({}),
        darkTheme.colorScheme.primaryContainer,
      );
      expect(
        darkTheme.filledButtonTheme.style?.foregroundColor?.resolve({}),
        darkTheme.colorScheme.onPrimaryContainer,
      );
      expect(
        darkTheme.textButtonTheme.style?.foregroundColor?.resolve({}),
        lighten(darkTheme.seedColor, 0.08),
      );
      expect(
        darkTheme.outlinedButtonTheme.style?.foregroundColor?.resolve({}),
        darkTheme.seedColor,
      );

      expect(
        lightTheme.filledButtonTheme.style?.backgroundColor?.resolve({}),
        lightTheme.colorScheme.primaryContainer,
      );
      expect(
        lightTheme.filledButtonTheme.style?.foregroundColor?.resolve({}),
        lightTheme.colorScheme.onPrimaryContainer,
      );
      expect(
        lightTheme.textButtonTheme.style?.foregroundColor?.resolve({}),
        lighten(lightTheme.seedColor, 0.08),
      );
      expect(
        lightTheme.outlinedButtonTheme.style?.foregroundColor?.resolve({}),
        lightTheme.seedColor,
      );
    });

    test('chart series theme mirrors the resolved color scheme', () {
      final darkTheme = MyTheme.dark;
      final lightTheme = MyTheme.light;

      expect(
        darkTheme.extension<ChartSeriesTheme>()?.primarySeriesColor,
        darkTheme.colorScheme.primaryContainer,
      );
      expect(
        darkTheme.extension<ChartSeriesTheme>()?.selectedPrimarySeriesColor,
        lighten(darkTheme.colorScheme.primaryContainer, 0.12),
      );
      expect(
        darkTheme.extension<ChartSeriesTheme>()?.secondarySeriesColor,
        const Color(0xFF2E7D32),
      );

      expect(
        lightTheme.extension<ChartSeriesTheme>()?.primarySeriesColor,
        lightTheme.colorScheme.primaryContainer,
      );
      expect(
        lightTheme.extension<ChartSeriesTheme>()?.selectedPrimarySeriesColor,
        lighten(lightTheme.colorScheme.primaryContainer, 0.12),
      );
      expect(
        lightTheme.extension<ChartSeriesTheme>()?.secondarySeriesColor,
        const Color(0xFF2E7D32),
      );
    });

    test('lighten increases HSL lightness and saturation', () {
      final original = HSLColor.fromColor(defaultThemeSeedSwatch.color);
      final adjusted = HSLColor.fromColor(
        lighten(defaultThemeSeedSwatch.color, 0.1),
      );

      expect(adjusted.lightness, greaterThan(original.lightness));
      expect(adjusted.saturation, greaterThan(original.saturation));
    });

    test('darken decreases HSL lightness and saturation', () {
      final original = HSLColor.fromColor(defaultThemeSeedSwatch.color);
      final adjusted = HSLColor.fromColor(
        darken(defaultThemeSeedSwatch.color, 0.1),
      );

      expect(adjusted.lightness, lessThan(original.lightness));
      expect(adjusted.saturation, lessThan(original.saturation));
    });

    test('lighten and darken clamp adjusted HSL channels', () {
      final lightened = HSLColor.fromColor(lighten(Colors.white, 1.0));
      final darkened = HSLColor.fromColor(darken(Colors.black, 1.0));

      expect(lightened.lightness, 1.0);
      expect(lightened.saturation, inInclusiveRange(0.0, 1.0));
      expect(darkened.lightness, 0.0);
      expect(darkened.saturation, inInclusiveRange(0.0, 1.0));
    });
  });
}

ColorScheme _expectedColorScheme({
  required Color seedColor,
  required Brightness brightness,
  DynamicSchemeVariant dynamicSchemeVariant = DynamicSchemeVariant.vibrant,
  double contrastLevel = 0.0,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: seedColor,
    brightness: brightness,
    dynamicSchemeVariant: dynamicSchemeVariant,
    contrastLevel: contrastLevel,
  );

  return scheme.copyWith(outlineVariant: scheme.onPrimary);
}
