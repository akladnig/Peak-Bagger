import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_correlation_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults both peak correlation thresholds independently', () async {
    SharedPreferences.setMockInitialValues({});
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final settings = await container.read(
      peakCorrelationSettingsProvider.future,
    );

    expect(settings.distanceMeters, peakCorrelationDefaultDistanceMeters);
    expect(settings.elevationMeters, peakCorrelationDefaultElevationMeters);
  });

  test(
    'normalizes an invalid elevation without changing the distance',
    () async {
      SharedPreferences.setMockInitialValues({
        peakCorrelationDistanceKey: 70,
        peakCorrelationElevationKey: 15,
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final settings = await container.read(
        peakCorrelationSettingsProvider.future,
      );

      expect(settings.distanceMeters, 70);
      expect(settings.elevationMeters, peakCorrelationDefaultElevationMeters);
    },
  );

  test('persists every supported elevation value independently', () async {
    SharedPreferences.setMockInitialValues({peakCorrelationDistanceKey: 60});
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(peakCorrelationSettingsProvider.future);
    final notifier = container.read(peakCorrelationSettingsProvider.notifier);
    final prefs = await SharedPreferences.getInstance();

    for (final elevation in peakCorrelationElevationOptions) {
      await notifier.setElevationMeters(elevation);

      final settings = await container.read(
        peakCorrelationSettingsProvider.future,
      );
      expect(settings.distanceMeters, 60);
      expect(settings.elevationMeters, elevation);
      expect(prefs.getInt(peakCorrelationElevationKey), elevation);
      expect(prefs.getInt(peakCorrelationDistanceKey), 60);
    }

    await notifier.setDistanceMeters(80);

    final updatedSettings = await container.read(
      peakCorrelationSettingsProvider.future,
    );
    expect(updatedSettings.distanceMeters, 80);
    expect(updatedSettings.elevationMeters, 100);
    expect(prefs.getInt(peakCorrelationDistanceKey), 80);
    expect(prefs.getInt(peakCorrelationElevationKey), 100);
  });
}
