import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'mixed scan summary reports unsupported files only in unsupportedCount',
    (tester) async {
      _setTallSurface(tester);
      final initialState = MapState(
        center: _center,
        zoom: 10,
        basemap: Basemap.tracestrack,
        trackOperationStatus:
            'Imported 1,234, replaced 0, unchanged 0, unsupported 2,345, errors 0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(() => TestMapNotifier(initialState)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(
        find.textContaining('Imported 1,234'),
        300,
        scrollable: _settingsScrollable(),
      );

      expect(find.textContaining('Imported 1,234'), findsOneWidget);
      expect(find.textContaining('replaced 0'), findsOneWidget);
      expect(find.textContaining('unchanged 0'), findsOneWidget);
      expect(find.textContaining('unsupported 2,345'), findsOneWidget);
      expect(find.textContaining('errors 0'), findsOneWidget);
    },
  );

  testWidgets('recalc summary reports updated and skipped counts', (
    tester,
  ) async {
    _setTallSurface(tester);
    final initialState = MapState(
      center: _center,
      zoom: 10,
      basemap: Basemap.tracestrack,
      trackOperationStatus:
          'Updated 1,234 tracks, refreshed peak correlation, skipped 2,345 tracks',
      trackOperationWarning:
          'Some tracks could not be recalculated, so their previous statistics and peak correlation were kept.',
    );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(() => TestMapNotifier(initialState)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      await tester.scrollUntilVisible(
        find.textContaining('Updated 1,234 tracks'),
        300,
        scrollable: _settingsScrollable(),
      );

      expect(find.textContaining('Updated 1,234 tracks'), findsOneWidget);
    expect(find.textContaining('refreshed peak correlation'), findsOneWidget);
    expect(find.textContaining('skipped 2,345 tracks'), findsOneWidget);
    expect(
      find.textContaining(
        'Some tracks could not be recalculated, so their previous statistics and peak correlation were kept.',
      ),
      findsOneWidget,
    );
  });
}

const _center = LatLng(-41.5, 146.5);

Finder _settingsScrollable() {
  return find
      .descendant(
        of: find.byKey(const Key('settings-scrollable')),
        matching: find.byType(Scrollable),
      )
      .first;
}

void _setTallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1024, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
