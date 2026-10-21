import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/objectbox_admin_delete_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_save_provider.dart';

void main() {
  for (final entity in [
    'Peak',
    'NaturalFeature',
    'Contact',
    'GpxTrack',
    'Route',
    'Waypoints',
  ]) {
    test(
      '$entity gates confirmation, removal and refresh; Cancel/failure releases',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final notifier = container.read(objectboxAdminDeleteProvider.notifier);
        final confirm = Completer<bool>();
        final remove = Completer<void>();
        final refresh = Completer<void>();
        var confirmations = 0;
        var removals = 0;
        var invalidations = 0;
        var errors = 0;
        Future<void> attempt() => notifier.run(
          label: entity,
          confirm: () {
            confirmations++;
            return confirm.future;
          },
          remove: () {
            removals++;
            return remove.future;
          },
          didRemove: () => invalidations++,
          refresh: () => refresh.future,
          onFailure: (_, _) async {
            errors++;
          },
        );
        final pending = attempt();
        expect(container.read(objectboxAdminSaveProvider), isTrue);
        await attempt();
        expect(confirmations, 1);
        expect(
          await container
              .read(objectboxAdminSaveProvider.notifier)
              .run(() async => null),
          isNotNull,
        );
        confirm.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(removals, 1);
        expect(container.read(objectboxAdminSaveProvider), isTrue);
        remove.complete();
        await Future<void>.delayed(Duration.zero);
        expect(invalidations, 1);
        expect(container.read(objectboxAdminSaveProvider), isTrue);
        refresh.complete();
        await pending;
        expect(container.read(objectboxAdminSaveProvider), isFalse);
        expect(errors, 0);
        for (final outcome in ['cancel', 'blocked', 'failure']) {
          await notifier.run(
            label: entity,
            confirm: () async => outcome != 'cancel' && outcome != 'blocked',
            remove: () async => throw StateError('failure'),
            didRemove: () => fail('No confirmed removal'),
            refresh: () async => fail('No refresh'),
            onFailure: (_, _) async {
              errors++;
            },
          );
          expect(container.read(objectboxAdminSaveProvider), isFalse);
        }
        expect(errors, 1);
      },
    );
  }

  test(
    'confirmed removal is never retried; only unfinished sync and refresh survive repeated failures',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(objectboxAdminDeleteProvider.notifier);
      var removals = 0;
      var confirmations = 0;
      var syncs = 0;
      var refreshes = 0;
      var failSync = true;
      var failRefresh = true;
      Completer<void>? retryGate;
      await notifier.run(
        label: 'Track',
        confirm: () async {
          confirmations++;
          return true;
        },
        remove: () async {
          removals++;
        },
        didRemove: () {},
        followUp: () async {
          syncs++;
          await retryGate?.future;
          if (failSync) throw StateError('sync');
        },
        refresh: () async {
          refreshes++;
          if (failRefresh) throw StateError('read');
        },
        onFailure: (_, _) async =>
            fail('Confirmed removal is not a failed deletion'),
      );
      final recovery = container.read(objectboxAdminDeleteProvider).single;
      retryGate = Completer<void>();
      final retry = notifier.retry(recovery);
      expect(container.read(objectboxAdminSaveProvider), isTrue);
      await notifier.retry(recovery);
      retryGate.complete();
      await retry;
      expect(container.read(objectboxAdminSaveProvider), isFalse);
      expect(container.read(objectboxAdminDeleteProvider), [recovery]);
      failSync = false;
      await notifier.retry(recovery);
      expect(recovery.followUp, isNull);
      expect(refreshes, 1);
      failRefresh = false;
      await notifier.retry(recovery);
      await notifier.retry(
        recovery,
      ); // captured callback after successful recovery
      expect([removals, confirmations, syncs, refreshes], [1, 1, 3, 2]);
      expect(container.read(objectboxAdminDeleteProvider), isEmpty);
    },
  );
}
