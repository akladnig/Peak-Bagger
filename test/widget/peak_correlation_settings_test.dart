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

    expect(
      find.byKey(const Key('peak-correlation-settings-section')),
      findsOneWidget,
    );

    await tester.ensureVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
    );
    await tester.tap(
      find.byKey(const Key('peak-correlation-settings-section')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('peak-correlation-distance-meters')),
      findsOneWidget,
    );
  });

  testWidgets('persists peak correlation threshold changes', (tester) async {
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

    await tester.ensureVisible(
      find.byKey(const Key('peak-correlation-settings-section')),
    );
    await tester.tap(
      find.byKey(const Key('peak-correlation-settings-section')),
    );
    await tester.pumpAndSettle();
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
