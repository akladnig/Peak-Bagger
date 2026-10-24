import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../harness/controlled_preferences.dart';

void main() {
  test('starts with default ORS key when prefs are empty', () async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container.read(openRouteServiceApiKeyProvider),
      defaultOpenRouteServiceApiKey,
    );
    await _drainAsync();
    expect(
      container.read(openRouteServiceApiKeyProvider),
      defaultOpenRouteServiceApiKey,
    );
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

    expect(
      container.read(openRouteServiceApiKeyProvider),
      defaultOpenRouteServiceApiKey,
    );

    completer.complete(await SharedPreferences.getInstance());
    await pendingUpdate;
    await _drainAsync();

    expect(container.read(openRouteServiceApiKeyProvider), 'updated-key');
  });

  for (final throwsError in [false, true]) {
    test(
      'failed key write retains prior effective key; retry succeeds ($throwsError)',
      () async {
        final prefs = ControlledPreferences({
          openRouteServiceApiKeyPrefsKey: 'prior-key',
        });
        final container = ProviderContainer(
          overrides: [
            openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
              () async => prefs,
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(openRouteServiceApiKeyProvider);
        await _drainAsync();
        prefs.onWrite = (_, _) async {
          if (throwsError) throw StateError('private payload must not escape');
          return false;
        };
        final notifier = container.read(
          openRouteServiceApiKeyProvider.notifier,
        );
        await expectLater(
          notifier.setApiKey('draft-key'),
          throwsA(isA<OpenRouteServiceApiKeySaveException>()),
        );
        expect(notifier.isSaving, isFalse);
        expect(container.read(openRouteServiceApiKeyProvider), 'prior-key');
        expect(prefs.stored[openRouteServiceApiKeyPrefsKey], 'prior-key');
        prefs.onWrite = null;
        expect(await notifier.setApiKey('  draft-key  '), isTrue);
        expect(container.read(openRouteServiceApiKeyProvider), 'draft-key');
        expect(await notifier.setApiKey('   '), isTrue);
        expect(container.read(openRouteServiceApiKeyProvider), isEmpty);
      },
    );
  }

  test(
    'key save gates duplicates before preparation and ignores disposed completion',
    () async {
      final prefs = ControlledPreferences();
      final prepared = Completer<SharedPreferences>();
      final container = ProviderContainer(
        overrides: [
          openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
            () => prepared.future,
          ),
        ],
      );
      final notifier = container.read(openRouteServiceApiKeyProvider.notifier);
      final save = notifier.setApiKey('new-key');
      expect(notifier.isSaving, isTrue);
      expect(await notifier.setApiKey('other-key'), isFalse);
      container.dispose();
      prepared.complete(prefs);
      expect(await save, isFalse);
      expect(prefs.writes, isEmpty);
    },
  );

  test(
    'key remains committed while its write is pending and rejects duplicates',
    () async {
      final prefs = ControlledPreferences({
        openRouteServiceApiKeyPrefsKey: 'prior-key',
      });
      final write = Completer<bool>();
      final container = ProviderContainer(
        overrides: [
          openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
            () async => prefs,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(openRouteServiceApiKeyProvider);
      await _drainAsync();
      prefs.onWrite = (_, _) => write.future;
      final notifier = container.read(openRouteServiceApiKeyProvider.notifier);
      final attempt = notifier.setApiKey('next-key');
      await _drainAsync();
      expect(container.read(openRouteServiceApiKeyProvider), 'prior-key');
      expect(await notifier.setApiKey('stale-key'), isFalse);
      expect(prefs.writes.length, 1);
      write.complete(true);
      expect(await attempt, isTrue);
      expect(container.read(openRouteServiceApiKeyProvider), 'next-key');
    },
  );
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}
