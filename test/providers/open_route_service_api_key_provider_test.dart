import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('starts with default ORS key when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(openRouteServiceApiKeyProvider), defaultOpenRouteServiceApiKey);
    await _drainAsync();
    expect(container.read(openRouteServiceApiKeyProvider), defaultOpenRouteServiceApiKey);
  });

  test('persists updated ORS key in memory', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    await container
        .read(openRouteServiceApiKeyProvider.notifier)
        .setApiKey('updated-key');

    expect(container.read(openRouteServiceApiKeyProvider), 'updated-key');
  });

  test('keeps in-memory ORS key when hydration returns late', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({
      openRouteServiceApiKeyPrefsKey: 'stored-key',
    });
    final completer = Completer<SharedPreferences>();

    final container = ProviderContainer(
      overrides: [
        openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
          () => completer.future,
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(openRouteServiceApiKeyProvider.notifier);
    final pendingUpdate = notifier.setApiKey('updated-key');

    expect(container.read(openRouteServiceApiKeyProvider), 'updated-key');

    completer.complete(await SharedPreferences.getInstance());
    await pendingUpdate;
    await _drainAsync();

    expect(container.read(openRouteServiceApiKeyProvider), 'updated-key');
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
