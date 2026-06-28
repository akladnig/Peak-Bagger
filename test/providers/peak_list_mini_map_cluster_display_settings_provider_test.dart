import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_list_mini_map_cluster_display_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with peak list mini-map clusters on when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isTrue);
    await _drainAsync();
    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isTrue);
  });

  test('sets peak list mini-map clusters off in memory', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(peakListMiniMapClusterDisplaySettingsProvider.notifier)
        .setShowPeakClusters(false);

    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isFalse);
  });

  test('keeps in-memory toggle when hydration returns late', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({peakListMiniMapClusterDisplayKey: true});
    final completer = Completer<SharedPreferences>();

    final container = ProviderContainer(
      overrides: [
        peakListMiniMapClusterDisplayPreferencesLoaderProvider.overrideWithValue(
          () => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(
      peakListMiniMapClusterDisplaySettingsProvider.notifier,
    );
    final pendingToggle = notifier.setShowPeakClusters(false);

    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isFalse);

    completer.complete(await SharedPreferences.getInstance());
    await pendingToggle;
    await _drainAsync();

    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isFalse);
  });

  test('falls back to on when prefs loading fails', () async {
    SharedPreferences.resetStatic();
    final container = ProviderContainer(
      overrides: [
        peakListMiniMapClusterDisplayPreferencesLoaderProvider.overrideWithValue(
          () => Future<SharedPreferences>.error(StateError('boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _drainAsync();

    expect(container.read(peakListMiniMapClusterDisplaySettingsProvider), isTrue);
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
