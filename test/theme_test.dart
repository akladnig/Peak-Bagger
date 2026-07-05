import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  group('CatppuccinColors', () {
    setUp(() {
      useSeedGeneratedColorScheme = false;
      seededDynamicSchemeVariant = DynamicSchemeVariant.vibrant;
      seededContrastLevel = 0.0;
    });

    tearDown(() {
      useSeedGeneratedColorScheme = false;
      seededDynamicSchemeVariant = DynamicSchemeVariant.vibrant;
      seededContrastLevel = 0.0;
    });

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
      expect(theme.colorScheme.primary, const Color(0xFFEBE8FC));
    });

    test('light theme uses configured primary color', () {
      final theme = CatppuccinColors.light;
      expect(theme.colorScheme.primary, const Color(0xFF6347EA));
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
      expect(theme.colorScheme.outlineVariant, theme.colorScheme.onPrimary);
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

      expect(theme.appBarTheme.backgroundColor, theme.scaffoldBackgroundColor);
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
      expect(darkTheme.extension<ChartSeriesTheme>(), isNotNull);
      expect(lightTheme.extension<ChartSeriesTheme>(), isNotNull);
      expect(darkTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(lightTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(darkTheme.extension<SelectedButtonThemeData>(), isNull);
      expect(lightTheme.extension<SelectedButtonThemeData>(), isNull);
    });

    test('button themes are wired from the resolved color scheme', () {
      final darkTheme = CatppuccinColors.dark;
      final lightTheme = CatppuccinColors.light;
      final darkFilledStyle = darkTheme.filledButtonTheme.style!;
      final darkTextStyle = darkTheme.textButtonTheme.style!;
      final darkOutlinedStyle = darkTheme.outlinedButtonTheme.style!;
      final lightFilledStyle = lightTheme.filledButtonTheme.style!;
      final lightTextStyle = lightTheme.textButtonTheme.style!;
      final lightOutlinedStyle = lightTheme.outlinedButtonTheme.style!;

      expect(
        darkFilledStyle.backgroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkFilledStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.onPrimary,
      );
      expect(
        darkTextStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkOutlinedStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkOutlinedStyle.side?.resolve({})?.color,
        darkTheme.colorScheme.outline,
      );

      expect(
        lightFilledStyle.backgroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightFilledStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.onPrimary,
      );
      expect(
        lightTextStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightOutlinedStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightOutlinedStyle.side?.resolve({})?.color,
        lightTheme.colorScheme.outline,
      );
    });

    test('button themes stay wired in seeded mode', () {
      useSeedGeneratedColorScheme = true;

      final darkTheme = CatppuccinColors.dark;
      final lightTheme = CatppuccinColors.light;
      final darkFilledStyle = darkTheme.filledButtonTheme.style!;
      final darkTextStyle = darkTheme.textButtonTheme.style!;
      final darkOutlinedStyle = darkTheme.outlinedButtonTheme.style!;
      final lightFilledStyle = lightTheme.filledButtonTheme.style!;
      final lightTextStyle = lightTheme.textButtonTheme.style!;
      final lightOutlinedStyle = lightTheme.outlinedButtonTheme.style!;

      expect(
        darkFilledStyle.backgroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkFilledStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.onPrimary,
      );
      expect(
        darkTextStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkOutlinedStyle.foregroundColor?.resolve({}),
        darkTheme.colorScheme.primary,
      );
      expect(
        darkOutlinedStyle.side?.resolve({})?.color,
        darkTheme.colorScheme.outline,
      );

      expect(
        lightFilledStyle.backgroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightFilledStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.onPrimary,
      );
      expect(
        lightTextStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightOutlinedStyle.foregroundColor?.resolve({}),
        lightTheme.colorScheme.primary,
      );
      expect(
        lightOutlinedStyle.side?.resolve({})?.color,
        lightTheme.colorScheme.outline,
      );
    });

    test('chart series theme mirrors the resolved color scheme', () {
      final darkTheme = CatppuccinColors.dark;
      final lightTheme = CatppuccinColors.light;

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
        darkTheme.extension<ChartSeriesTheme>()?.selectedSecondarySeriesColor,
        lighten(const Color(0xFF2E7D32), 0.12),
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
      expect(
        lightTheme.extension<ChartSeriesTheme>()?.selectedSecondarySeriesColor,
        lighten(const Color(0xFF2E7D32), 0.12),
      );
    });

    test('dark theme keeps existing guarded semantic roles', () {
      final theme = CatppuccinColors.dark;

      expect(theme.colorScheme.secondary, const Color(0xFF191919));
      expect(theme.colorScheme.onSecondary, const Color(0xFFCDD6F4));
      expect(theme.colorScheme.tertiary, const Color(0xFF2A2A2A));
      expect(theme.colorScheme.onTertiary, const Color(0xFFCDD6F4));
      expect(theme.colorScheme.primaryContainer, const Color(0xFFCDD6F4));
      expect(theme.colorScheme.onPrimaryContainer, const Color(0xFF221B52));
      expect(theme.colorScheme.surfaceContainer, const Color(0xFF191919));
      expect(theme.colorScheme.outline, const Color(0xFF7B7B7B));
      expect(theme.colorScheme.outlineVariant, theme.colorScheme.onPrimary);
      expect(theme.appBarTheme.backgroundColor, const Color(0xFF111111));
      expect(theme.appBarTheme.foregroundColor, const Color(0xFFCDD6F4));
      expect(theme.appBarTheme.elevation, 2);
      expect(theme.appBarTheme.surfaceTintColor, Colors.transparent);
      expect(theme.appBarTheme.shadowColor, const Color(0x66000000));
    });

    test('lighten increases HSL lightness and saturation', () {
      final baseColor = catppuccinSeedColor;
      final original = HSLColor.fromColor(baseColor);
      final adjusted = HSLColor.fromColor(lighten(baseColor, 0.1));

      expect(adjusted.lightness, greaterThan(original.lightness));
      expect(adjusted.saturation, greaterThan(original.saturation));
    });

    test('darken decreases HSL lightness and saturation', () {
      final baseColor = catppuccinSeedColor;
      final original = HSLColor.fromColor(baseColor);
      final adjusted = HSLColor.fromColor(darken(baseColor, 0.1));

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

    test(
      'dark selected search button hover background derives from primary',
      () {
        final theme = CatppuccinColors.dark;
        final searchButtonTheme = theme.extension<SearchButtonThemeData>()!;
        final hoveredBackground = searchButtonTheme
            .selectedStyle
            .backgroundColor
            ?.resolve({WidgetState.hovered});

        expect(hoveredBackground, darken(theme.colorScheme.primary, 0.08));
      },
    );

    test('manual color schemes remain the default branch', () {
      useSeedGeneratedColorScheme = false;

      final darkScheme = CatppuccinColors.dark.colorScheme;
      final lightScheme = CatppuccinColors.light.colorScheme;

      expect(darkScheme.primary, const Color(0xFFEBE8FC));
      expect(darkScheme.onPrimary, const Color(0xFF6347EA));
      expect(darkScheme.secondary, const Color(0xFF191919));
      expect(darkScheme.surface, const Color(0xFF111111));
      expect(darkScheme.outlineVariant, darkScheme.onPrimary);

      expect(lightScheme.primary, const Color(0xFF6347EA));
      expect(lightScheme.onPrimary, const Color(0xFF4C4F69));
      expect(lightScheme.secondary, const Color(0xFFDCE0E8));
      expect(lightScheme.surface, const Color(0xFFEFF1F5));
      expect(lightScheme.outlineVariant, lightScheme.onPrimary);
    });

    test('dark theme can opt into a seeded color scheme', () {
      useSeedGeneratedColorScheme = true;

      expect(
        CatppuccinColors.dark.colorScheme,
        ColorScheme.fromSeed(
          seedColor: mySeedColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          contrastLevel: 0.0,
        ).copyWith(
          outlineVariant: ColorScheme.fromSeed(
            seedColor: mySeedColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
            contrastLevel: 0.0,
          ).onPrimary,
        ),
      );
    });

    test('light theme can opt into a seeded color scheme', () {
      useSeedGeneratedColorScheme = true;

      expect(
        CatppuccinColors.light.colorScheme,
        ColorScheme.fromSeed(
          seedColor: catppuccinSeedColor,
          brightness: Brightness.light,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
          contrastLevel: 0.0,
        ).copyWith(
          outlineVariant: ColorScheme.fromSeed(
            seedColor: catppuccinSeedColor,
            brightness: Brightness.light,
            dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
            contrastLevel: 0.0,
          ).onPrimary,
        ),
      );
    });

    test('seeded branch uses configured scheme variant and contrast level', () {
      useSeedGeneratedColorScheme = true;
      seededDynamicSchemeVariant = DynamicSchemeVariant.expressive;
      seededContrastLevel = 0.5;

      expect(
        CatppuccinColors.dark.colorScheme,
        ColorScheme.fromSeed(
          seedColor: mySeedColor,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.expressive,
          contrastLevel: 0.5,
        ).copyWith(
          outlineVariant: ColorScheme.fromSeed(
            seedColor: mySeedColor,
            brightness: Brightness.dark,
            dynamicSchemeVariant: DynamicSchemeVariant.expressive,
            contrastLevel: 0.5,
          ).onPrimary,
        ),
      );
    });
  });
}
