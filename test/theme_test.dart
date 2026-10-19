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

    test('data grid theme derives every token from each resolved scheme', () {
      const customConfig = ThemeConfig(
        seedColor: Color(0xFF00FF00),
        dynamicSchemeVariant: DynamicSchemeVariant.expressive,
        contrastLevel: 0.5,
      );

      for (final theme in [
        MyTheme.light,
        MyTheme.dark,
        MyTheme.lightWith(customConfig),
        MyTheme.darkWith(customConfig),
      ]) {
        final dataGridTheme = theme.extension<DataGridTheme>();

        expect(dataGridTheme, isNotNull);
        expect(
          dataGridTheme!.headerPadding,
          const EdgeInsets.symmetric(vertical: 4),
        );
        expect(
          dataGridTheme.rowPadding,
          const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        );
        expect(dataGridTheme.columnGap, 12);
        expect(dataGridTheme.headerTextStyle, theme.textTheme.labelLarge);
        expect(dataGridTheme.rowTextStyle, theme.textTheme.bodyMedium);
        expect(dataGridTheme.dividerColor, theme.colorScheme.onPrimary);
        expect(dataGridTheme.dividerThickness, 1);
        expect(
          dataGridTheme.focusBorder,
          BorderSide(color: theme.colorScheme.primary, width: 2),
        );
        expect(
          dataGridTheme.hoverColor,
          Color.lerp(dataGridTheme.selectedRowColor, Colors.white, .10),
        );
        expect(dataGridTheme.hoveredTextColor, theme.colorScheme.onSurface);
        expect(
          dataGridTheme.pressedRowColor,
          Color.alphaBlend(
            theme.colorScheme.primary.withValues(alpha: .12),
            theme.colorScheme.surface,
          ),
        );
        expect(
          dataGridTheme.selectedRowColor,
          _shade(
            theme.brightness == Brightness.dark
                ? theme.seedColor
                : theme.colorScheme.primaryContainer,
            .30,
          ),
        );
        expect(
          dataGridTheme.selectedRowBorderColor,
          _shade(
            theme.brightness == Brightness.dark
                ? theme.seedColor
                : theme.colorScheme.primaryContainer,
            .08,
          ),
        );
      }
    });

    test('data grid theme copies and interpolates its tokens', () {
      final light = MyTheme.light.extension<DataGridTheme>()!;
      final dark = MyTheme.dark.extension<DataGridTheme>()!;

      final copied = light.copyWith(columnGap: 16);
      final interpolated = light.lerp(dark, 0.5);

      expect(copied.columnGap, 16);
      expect(copied.rowPadding, light.rowPadding);
      expect(
        interpolated.selectedRowColor,
        Color.lerp(light.selectedRowColor, dark.selectedRowColor, 0.5),
      );
      expect(interpolated.headerPadding, isA<EdgeInsetsGeometry>());
      expect(interpolated.headerTextStyle, isA<TextStyle>());
    });

    test(
      'central fields, mode layers and circular actions resolve all states',
      () {
        expect(searchControlFontSize, 14.0);
        expect(searchControlIconSize, 24.0);
        const custom = ThemeConfig(
          seedColor: Colors.teal,
          dynamicSchemeVariant: DynamicSchemeVariant.expressive,
          contrastLevel: .5,
        );
        for (final theme in [
          MyTheme.light,
          MyTheme.dark,
          MyTheme.lightWith(custom),
          MyTheme.darkWith(custom),
        ]) {
          final colors = theme.colorScheme;
          final fields = theme.inputDecorationTheme;
          expect(
            fields.labelStyle,
            TextStyle(fontSize: 14, color: colors.onSurface),
          );
          expect(fields.floatingLabelBehavior, FloatingLabelBehavior.always);
          expect(fields.isDense, isTrue);
          expect(
            fields.border,
            OutlineInputBorder(borderSide: BorderSide(color: colors.onPrimary)),
          );
          expect(fields.enabledBorder, isNull);
          final active = fields.activeIndicatorBorder! as WidgetStateBorderSide;
          expect(active.resolve({}), BorderSide(color: colors.outline));
          expect(
            active.resolve({WidgetState.hovered}),
            BorderSide(color: theme.seedColor),
          );
          expect(
            fields.focusedBorder!.borderSide,
            BorderSide(color: theme.seedColor, width: 2),
          );
          expect(
            fields.errorBorder!.borderSide,
            BorderSide(color: colors.error),
          );
          expect(
            fields.focusedErrorBorder!.borderSide,
            BorderSide(color: colors.error, width: 2),
          );
          expect(
            active.resolve({
              WidgetState.disabled,
              WidgetState.hovered,
              WidgetState.error,
            }),
            BorderSide(color: colors.onSurface.withValues(alpha: .38)),
          );
          final fill = fields.fillColor! as WidgetStateProperty<Color>;
          final hovered = Color.alphaBlend(
            colors.primary.withValues(alpha: .08),
            Color.alphaBlend(
              colors.primary.withValues(alpha: .12),
              colors.surface,
            ),
          );
          expect(fill.resolve({}), colors.surface);
          expect(fill.resolve({WidgetState.focused}), colors.surface);
          expect(fill.resolve({WidgetState.hovered}), hovered);
          expect(
            fill.resolve({WidgetState.hovered, WidgetState.focused}),
            hovered,
          );
          expect(
            fill.resolve({WidgetState.hovered, WidgetState.disabled}),
            colors.surface,
          );
          expect(fields.hoverColor, Colors.transparent);
          final mode = theme.extension<SearchButtonThemeData>()!.selectedStyle;
          expect(mode.backgroundColor!.resolve({WidgetState.hovered}), hovered);
          expect(
            mode.overlayColor!.resolve({WidgetState.hovered}),
            Colors.transparent,
          );
          final icons = theme.iconButtonTheme.style!;
          expect(icons.shape!.resolve({}), const CircleBorder());
          expect(icons.backgroundColor!.resolve({}), Colors.transparent);
          expect(
            icons.overlayColor!.resolve({WidgetState.focused}),
            Colors.transparent,
          );
          expect(
            icons.backgroundColor!.resolve({WidgetState.hovered}),
            colors.onSurface.withValues(alpha: .08),
          );
          expect(
            icons.backgroundColor!.resolve({WidgetState.pressed}),
            colors.onSurface.withValues(alpha: .12),
          );
          expect(
            icons.overlayColor!.resolve({
              WidgetState.disabled,
              WidgetState.hovered,
            }),
            Colors.transparent,
          );
          expect(
            icons.side!.resolve({WidgetState.focused}),
            BorderSide(color: colors.primary, width: 2),
          );
          expect(
            icons.side!.resolve({WidgetState.disabled, WidgetState.focused}),
            BorderSide.none,
          );
          expect(
            icons.mouseCursor!.resolve({WidgetState.disabled}),
            SystemMouseCursors.basic,
          );
        }
      },
    );

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

  return scheme;
}

Color _shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation - amount).clamp(0, 1))
      .withLightness((hsl.lightness - amount).clamp(0, 1))
      .toColor();
}
