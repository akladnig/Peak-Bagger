import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('settings screen shows theme toggle row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-mode-toggle-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(find.byKey(const Key('theme-mode-toggle-tile')), findsOneWidget);
    expect(find.byKey(const Key('theme-mode-toggle-switch')), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('settings screen shows theme colour palette row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-colour-palette-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(find.byKey(const Key('theme-colour-palette-tile')), findsOneWidget);
    expect(
      find.byKey(const Key('theme-colour-palette-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Theme Colours'), findsOneWidget);
    expect(find.text('Catppuccin'), findsOneWidget);
  });

  testWidgets('settings screen shows theme scheme variant row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-scheme-variant-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(find.byKey(const Key('theme-scheme-variant-tile')), findsOneWidget);
    expect(
      find.byKey(const Key('theme-scheme-variant-dropdown')),
      findsOneWidget,
    );
    expect(find.text('Seeded Scheme Variant'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<DynamicSchemeVariant>>(
            find.byKey(const Key('theme-scheme-variant-dropdown')),
          )
          .value,
      DynamicSchemeVariant.vibrant,
    );
  });

  testWidgets('settings screen shows theme contrast slider row', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-contrast-level-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(find.byKey(const Key('theme-contrast-level-tile')), findsOneWidget);
    expect(
      find.byKey(const Key('theme-contrast-level-slider')),
      findsOneWidget,
    );
    expect(find.text('Seeded Contrast Level'), findsOneWidget);
    expect(find.text('Contrast level 0.0'), findsOneWidget);
  });

  testWidgets('theme toggle persists across rebuilds', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-mode-toggle-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      tester
          .widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch')))
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('theme-mode-toggle-tile')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch')))
          .value,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);

    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch')))
          .value,
      isTrue,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(themeModeProvider),
      ThemeMode.dark,
    );
  });

  testWidgets('theme colour palette persists across rebuilds', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-colour-palette-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Catppuccin'), findsOneWidget);

    await tester.tap(find.byKey(const Key('theme-colour-palette-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seeded').last);
    await tester.pumpAndSettle();

    expect(find.text('Seeded'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-colour-palette-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Seeded colours enabled'), findsOneWidget);
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(themeColorPaletteProvider),
      ThemeColorPalette.seeded,
    );
  });

  testWidgets('theme scheme variant persists across rebuilds', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-scheme-variant-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('theme-scheme-variant-dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expressive').last);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButton<DynamicSchemeVariant>>(
            find.byKey(const Key('theme-scheme-variant-dropdown')),
          )
          .value,
      DynamicSchemeVariant.expressive,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-scheme-variant-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownButton<DynamicSchemeVariant>>(
            find.byKey(const Key('theme-scheme-variant-dropdown')),
          )
          .value,
      DynamicSchemeVariant.expressive,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(themeSchemeVariantProvider),
      DynamicSchemeVariant.expressive,
    );
  });

  testWidgets('theme contrast level persists across rebuilds', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-contrast-level-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final sliderRect = tester.getRect(
      find.byKey(const Key('theme-contrast-level-slider')),
    );
    await tester.tapAt(sliderRect.centerRight - const Offset(4, 0));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Slider>(find.byKey(const Key('theme-contrast-level-slider')))
          .value,
      1.0,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('theme-contrast-level-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Slider>(find.byKey(const Key('theme-contrast-level-slider')))
          .value,
      1.0,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(themeContrastLevelProvider),
      1.0,
    );
  });
}

Future<void> _pumpSettingsScreen(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}
