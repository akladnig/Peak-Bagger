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

    expect(find.byKey(const Key('theme-mode-toggle-tile')), findsOneWidget);
    expect(find.byKey(const Key('theme-mode-toggle-switch')), findsOneWidget);
    expect(find.text('Theme'), findsOneWidget);
  });

  testWidgets('theme toggle persists across rebuilds', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    expect(
      tester.widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch'))).value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('theme-mode-toggle-tile')));
    await tester.pumpAndSettle();

    expect(
      tester.widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch'))).value,
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);

    await tester.pumpAndSettle();

    expect(
      tester.widget<Switch>(find.byKey(const Key('theme-mode-toggle-switch'))).value,
      isTrue,
    );
    expect(
      ProviderScope.containerOf(tester.element(find.byType(SettingsScreen)))
          .read(themeModeProvider),
      ThemeMode.dark,
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
