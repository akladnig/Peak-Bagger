import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with peak ownership rings off when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(peakOwnershipRingSettingsProvider), isFalse);
    await _drainAsync();
    expect(container.read(peakOwnershipRingSettingsProvider), isFalse);
  });

  test('sets peak ownership rings on in memory', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(peakOwnershipRingSettingsProvider.notifier)
        .setShowPeakOwnershipRings(true);

    expect(container.read(peakOwnershipRingSettingsProvider), isTrue);
  });

  test('keeps the in-memory toggle when hydration returns late', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({peakOwnershipRingKey: false});
    final completer = Completer<SharedPreferences>();

    final container = ProviderContainer(
      overrides: [
        peakOwnershipRingPreferencesLoaderProvider.overrideWithValue(
          () => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(peakOwnershipRingSettingsProvider.notifier);
    final pendingToggle = notifier.setShowPeakOwnershipRings(true);

    expect(container.read(peakOwnershipRingSettingsProvider), isTrue);

    completer.complete(await SharedPreferences.getInstance());
    await pendingToggle;
    await _drainAsync();

    expect(container.read(peakOwnershipRingSettingsProvider), isTrue);
  });

  test('falls back to off when prefs loading fails', () async {
    SharedPreferences.resetStatic();
    final container = ProviderContainer(
      overrides: [
        peakOwnershipRingPreferencesLoaderProvider.overrideWithValue(
          () => Future<SharedPreferences>.error(StateError('boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _drainAsync();

    expect(container.read(peakOwnershipRingSettingsProvider), isFalse);
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
