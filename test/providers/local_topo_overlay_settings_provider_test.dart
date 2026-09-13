import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/local_topo_overlay_outage_provider.dart';
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  test('uses defaults then persists independent overlay values', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(localTopoOverlaySettingsProvider),
      isA<LocalTopoOverlaySettings>()
          .having((state) => state.terrainReliefShadingEnabled, 'relief', false)
          .having((state) => state.contourLinesEnabled, 'contours', false)
          .having(
            (state) => state.terrainReliefShadingOpacity,
            'relief opacity',
            35,
          )
          .having((state) => state.contourLinesOpacity, 'contour opacity', 70),
    );

    final notifier = container.read(localTopoOverlaySettingsProvider.notifier);
    await notifier.setEnabled(terrainReliefShadingOverlayKey, true);
    await notifier.setOpacity(contourLinesOverlayKey, 62);

    final state = container.read(localTopoOverlaySettingsProvider);
    expect(state.terrainReliefShadingEnabled, isTrue);
    expect(state.contourLinesEnabled, isFalse);
    expect(state.contourLinesOpacity, 62);
  });

  test(
    'restores persisted values and reverts a failed persistence update',
    () async {
      SharedPreferences.setMockInitialValues({
        'local_topo_terrain_relief_shading_enabled_v1': true,
        'local_topo_contour_lines_opacity_v1': 45,
      });
      final restored = ProviderContainer();
      addTearDown(restored.dispose);
      restored.read(localTopoOverlaySettingsProvider);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        restored
            .read(localTopoOverlaySettingsProvider)
            .terrainReliefShadingEnabled,
        isTrue,
      );
      expect(
        restored.read(localTopoOverlaySettingsProvider).contourLinesOpacity,
        45,
      );

      final failing = ProviderContainer(
        overrides: [
          localTopoOverlaySettingsPreferencesLoaderProvider.overrideWithValue(
            () => Future<SharedPreferences>.error(StateError('storage failed')),
          ),
        ],
      );
      addTearDown(failing.dispose);
      await failing
          .read(localTopoOverlaySettingsProvider.notifier)
          .setEnabled(contourLinesOverlayKey, true);
      expect(
        failing.read(localTopoOverlaySettingsProvider).contourLinesEnabled,
        isFalse,
      );
    },
  );

  test('disabling an overlay resets only its outage suppression', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final messages = <String>[];
    final subscription = container
        .read(localTopoOverlayOutageReporterProvider)
        .messages
        .listen(messages.add);
    addTearDown(subscription.cancel);
    final reporter = container.read(localTopoOverlayOutageReporterProvider);

    reporter.report(terrainReliefShadingOverlayKey);
    await container
        .read(localTopoOverlaySettingsProvider.notifier)
        .setEnabled(terrainReliefShadingOverlayKey, true);
    await container
        .read(localTopoOverlaySettingsProvider.notifier)
        .setEnabled(terrainReliefShadingOverlayKey, false);
    reporter.report(terrainReliefShadingOverlayKey);
    await Future<void>.delayed(Duration.zero);

    expect(messages, [
      'Terrain relief shading is unavailable from the local tile server',
      'Terrain relief shading is unavailable from the local tile server',
    ]);
  });
}
