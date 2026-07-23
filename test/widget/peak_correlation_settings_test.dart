import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('shows peak correlation settings section', (tester) async {
    _setTallSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
      300,
      scrollable: _settingsScrollable(),
    );

    expect(
      find.byKey(const Key('peak-correlation-settings-section')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
    );

    expect(
      find.byKey(const Key('peak-correlation-distance-meters')),
      findsOneWidget,
    );
  });

  testWidgets('persists peak correlation threshold changes', (tester) async {
    _setTallSurface(tester);
    SharedPreferences.setMockInitialValues({});
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(() => notifier),
        tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
        tasmapRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const App()),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
      300,
      scrollable: _settingsScrollable(),
    );

    await tester.ensureVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
    );
    expect(
      find.byKey(const Key('peak-correlation-distance-meters')),
      findsOneWidget,
    );

    await container
        .read(peakCorrelationSettingsProvider.notifier)
        .setDistanceMeters(70);
    await tester.pumpAndSettle();

    final value = await container.read(peakCorrelationSettingsProvider.future);
    expect(value, 70);
  });
}

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
