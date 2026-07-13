import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/theme_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/theme.dart';
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

  testWidgets('settings screen shows theme seed swatch row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await _scrollToThemeSeedSection(tester);
    await tester.pump();

    expect(find.byKey(const Key('theme-colour-palette-tile')), findsOneWidget);
    expect(
      find.byKey(const Key('theme-colour-palette-dropdown')),
      findsNothing,
    );
    expect(find.byKey(const Key('theme-seed-colour-scroll')), findsOneWidget);
    expect(find.text('Catppuccin'), findsNothing);
    expect(find.text('Theme Colours'), findsOneWidget);
    expect(find.text('My Seed Colour'), findsOneWidget);

    for (final swatch in themeSeedSwatches) {
      expect(
        find.byKey(Key('theme-seed-colour-swatch-${swatch.id}')),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(swatch.label), findsOneWidget);
    }
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

  testWidgets(
    'theme seed swatch restore shows selected state after preferences load',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({'theme_seed_color': 'teal'});

      final semanticsHandle = tester.ensureSemantics();

      await _pumpSettingsScreen(tester);

      await _scrollToThemeSeedSection(tester);
      await tester.pumpAndSettle();

      expect(find.text('Teal'), findsOneWidget);
      expect(
        find.byKey(
          const Key('theme-seed-colour-swatch-selected-indicator-teal'),
        ),
        findsOneWidget,
      );
      final semantics = tester.getSemantics(
        find.byKey(const Key('theme-seed-colour-swatch-teal')),
      );
      final semanticsData = semantics.getSemanticsData();
      expect(semanticsData.label, 'Teal');
      expect(semanticsData.flagsCollection.isButton, isTrue);
      expect(semanticsData.flagsCollection.isSelected, ui.Tristate.isTrue);

      semanticsHandle.dispose();
    },
  );

  testWidgets(
    'tapping a theme seed swatch updates selection and persists across rebuilds',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      await _pumpSettingsScreen(tester);

      await _scrollToThemeSeedSection(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('theme-seed-colour-swatch-pink')));
      await tester.pumpAndSettle();

      expect(find.text('Pink'), findsOneWidget);
      expect(
        find.byKey(
          const Key('theme-seed-colour-swatch-selected-indicator-pink'),
        ),
        findsOneWidget,
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_seed_color'), 'pink');
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(SettingsScreen)),
        ).read(themeSeedColorProvider).id,
        'pink',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      await _pumpSettingsScreen(tester);
      await tester.pumpAndSettle();

      await _scrollToThemeSeedSection(tester);
      await tester.pumpAndSettle();

      expect(find.text('Pink'), findsOneWidget);
      expect(
        find.byKey(
          const Key('theme-seed-colour-swatch-selected-indicator-pink'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'theme seed swatch row scrolls horizontally on narrow large-text layouts',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      await _pumpSettingsScreen(
        tester,
        viewportSize: const Size(320, 800),
        textScaleFactor: 2.0,
      );

      await _scrollToThemeSeedSection(tester);
      await tester.pumpAndSettle();

      final firstSwatchRect = tester.getRect(
        find.byKey(const Key('theme-seed-colour-swatch-baseColor')),
      );
      expect(firstSwatchRect.width, greaterThanOrEqualTo(48));
      expect(firstSwatchRect.height, greaterThanOrEqualTo(48));

      await tester.dragUntilVisible(
        find.byKey(const Key('theme-seed-colour-swatch-brightRed')),
        find.byKey(const Key('theme-seed-colour-scroll')),
        const Offset(-200, 0),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('theme-seed-colour-swatch-brightRed')),
        findsOneWidget,
      );
    },
  );

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

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  Size viewportSize = const Size(800, 1200),
  double textScaleFactor = 1.0,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = viewportSize;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: const SettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _scrollToThemeSeedSection(WidgetTester tester) {
  return tester.scrollUntilVisible(
    find.byKey(const Key('theme-colour-palette-tile')),
    200,
    scrollable: find
        .descendant(
          of: find.byKey(const Key('settings-scrollable')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}
