import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with peak info off when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(peakMarkerInfoSettingsProvider), isFalse);
    await _drainAsync();
    expect(container.read(peakMarkerInfoSettingsProvider), isFalse);
  });

  test('sets peak info on in memory', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(peakMarkerInfoSettingsProvider.notifier)
        .setShowPeakInfo(true);

    expect(container.read(peakMarkerInfoSettingsProvider), isTrue);
  });

  test('keeps the in-memory toggle when hydration returns late', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({peakMarkerInfoKey: false});
    final completer = Completer<SharedPreferences>();

    final container = ProviderContainer(
      overrides: [
        peakMarkerInfoPreferencesLoaderProvider.overrideWithValue(
          () => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(peakMarkerInfoSettingsProvider.notifier);
    final pendingToggle = notifier.setShowPeakInfo(true);

    expect(container.read(peakMarkerInfoSettingsProvider), isTrue);

    completer.complete(await SharedPreferences.getInstance());
    await pendingToggle;
    await _drainAsync();

    expect(container.read(peakMarkerInfoSettingsProvider), isTrue);
  });

  test('falls back to off when prefs loading fails', () async {
    SharedPreferences.resetStatic();
    final container = ProviderContainer(
      overrides: [
        peakMarkerInfoPreferencesLoaderProvider.overrideWithValue(
          () => Future<SharedPreferences>.error(StateError('boom')),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _drainAsync();

    expect(container.read(peakMarkerInfoSettingsProvider), isFalse);
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
