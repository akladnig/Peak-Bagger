import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_map_cluster_display_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with peak map clusters on when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(peakMapClusterDisplaySettingsProvider), isTrue);
    await _drainAsync();
    expect(container.read(peakMapClusterDisplaySettingsProvider), isTrue);
  });

  test('sets peak map clusters off in memory', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(peakMapClusterDisplaySettingsProvider.notifier)
        .setShowPeakClusters(false);

    expect(container.read(peakMapClusterDisplaySettingsProvider), isFalse);
  });

  test('keeps in-memory toggle when hydration returns late', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({peakMapClusterDisplayKey: true});
    final completer = Completer<SharedPreferences>();

    final container = ProviderContainer(
      overrides: [
        peakMapClusterDisplayPreferencesLoaderProvider.overrideWithValue(
          () => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      peakMapClusterDisplaySettingsProvider.notifier,
    );
    final pendingToggle = notifier.setShowPeakClusters(false);

    expect(container.read(peakMapClusterDisplaySettingsProvider), isFalse);

    completer.complete(await SharedPreferences.getInstance());
    await pendingToggle;
    await _drainAsync();

    expect(container.read(peakMapClusterDisplaySettingsProvider), isFalse);
  });

  test('falls back to on when prefs loading fails', () async {
    SharedPreferences.resetStatic();
    final container = ProviderContainer(
      overrides: [
        peakMapClusterDisplayPreferencesLoaderProvider.overrideWithValue(
          () => Future<SharedPreferences>.error(StateError('boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _drainAsync();

    expect(container.read(peakMapClusterDisplaySettingsProvider), isTrue);
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
