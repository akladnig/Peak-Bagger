import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  group('MyTheme', () {
    test('default dark theme derives from My Seed Colour', () {
      final theme = MyTheme.dark;

      expect(theme.brightness, Brightness.dark);
      expect(
        theme.colorScheme,
        ColorScheme.fromSeed(
          seedColor: defaultThemeSeedSwatch.color,
          brightness: Brightness.dark,
          dynamicSchemeVariant: DynamicSchemeVariant.vibrant,
        ),
      );
      expect(theme.seedColor, defaultThemeSeedSwatch.color);
      expect(theme.seedColour, defaultThemeSeedSwatch.color);
    });

    test('data grid theme derives every token from the dark scheme', () {
      final theme = MyTheme.dark;
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
      expect(dataGridTheme.selectedRowColor, _shade(theme.seedColor, .30));
      expect(
        dataGridTheme.selectedRowBorderColor,
        _shade(theme.seedColor, .08),
      );
    });

    test('data grid theme copies and interpolates its tokens', () {
      final dark = MyTheme.dark.extension<DataGridTheme>()!;

      final copied = dark.copyWith(columnGap: 16);
      final interpolated = dark.lerp(copied, 0.5);

      expect(copied.columnGap, 16);
      expect(copied.rowPadding, dark.rowPadding);
      expect(interpolated.columnGap, 14);
      expect(interpolated.selectedRowColor, dark.selectedRowColor);
      expect(interpolated.headerPadding, isA<EdgeInsetsGeometry>());
      expect(interpolated.headerTextStyle, isA<TextStyle>());
    });

    test(
      'central fields, mode layers and circular actions resolve all states',
      () {
        expect(searchControlFontSize, 14.0);
        expect(searchControlIconSize, 24.0);
        final theme = MyTheme.dark;
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
        expect(fields.errorBorder!.borderSide, BorderSide(color: colors.error));
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
      },
    );

    test('dark theme exposes only live theme extensions', () {
      final darkTheme = MyTheme.dark;

      expect(darkTheme.extension<RowHoverTheme>(), isNotNull);
      expect(darkTheme.extension<SeedColourTheme>(), isNotNull);
      expect(darkTheme.extension<ChartSeriesTheme>(), isNotNull);
      expect(darkTheme.extension<SearchButtonThemeData>(), isNotNull);
      expect(darkTheme.extension<SelectedButtonThemeData>(), isNull);
    });

    test('button themes are wired from the resolved color scheme', () {
      final darkTheme = MyTheme.dark;

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
    });

    test('chart series theme mirrors the resolved color scheme', () {
      final darkTheme = MyTheme.dark;

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
      final lightened = HSLColor.fromColor(
        lighten(defaultThemeSeedSwatch.color, 1.0),
      );
      final darkened = HSLColor.fromColor(
        darken(defaultThemeSeedSwatch.color, 1.0),
      );

      expect(lightened.lightness, 1.0);
      expect(lightened.saturation, inInclusiveRange(0.0, 1.0));
      expect(darkened.lightness, 0.0);
      expect(darkened.saturation, inInclusiveRange(0.0, 1.0));
    });
  });
}

Color _shade(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation((hsl.saturation - amount).clamp(0, 1))
      .withLightness((hsl.lightness - amount).clamp(0, 1))
      .toColor();
}
