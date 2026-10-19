import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/dashboard_order_writer.dart';

void main() {
  group('DashboardLayoutNotifier', () {
    test('layout read stays pending until stored order is applied', () async {
      SharedPreferences.setMockInitialValues({
        dashboardCardOrderStorageKey: ['my-ascents'],
      });
      final gate = Completer<SharedPreferences>();
      final container = ProviderContainer(
        overrides: [
          dashboardPreferencesLoaderProvider.overrideWithValue(
            () => gate.future,
          ),
        ],
      );
      addTearDown(container.dispose);
      final loading = container.read(dashboardLayoutProvider.notifier).load();
      expect(container.read(dashboardLayoutReadProvider).isLoading, isTrue);
      expect(
        container.read(dashboardLayoutProvider),
        dashboardDefaultCardOrder,
      );
      gate.complete(await SharedPreferences.getInstance());
      await loading;
      expect(container.read(dashboardLayoutReadProvider).hasValue, isTrue);
      expect(container.read(dashboardLayoutProvider).first, 'my-ascents');
    });
    test('starts with the default order', () {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(dashboardLayoutProvider),
        dashboardDefaultCardOrder,
      );
      expect(
        dashboardDefaultCardOrder.where((id) => id == 'time'),
        hasLength(1),
      );
      expect(
        dashboardDefaultCardOrder[dashboardDefaultCardOrder.indexOf(
              'distance',
            ) +
            1],
        'time',
      );
    });

    test(
      'an existing complete order appends Time without moving old cards',
      () async {
        final previous = dashboardDefaultCardOrder
            .where((id) => id != 'time')
            .toList()
            .reversed
            .toList();
        SharedPreferences.setMockInitialValues({
          dashboardCardOrderStorageKey: previous,
        });
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(dashboardLayoutProvider.notifier).load();
        expect(container.read(dashboardLayoutProvider), [...previous, 'time']);
      },
    );

    test(
      'failed layout read keeps defaults but is not loaded evidence',
      () async {
        final container = ProviderContainer(
          overrides: [
            dashboardPreferencesLoaderProvider.overrideWithValue(
              () async => throw StateError('preferences unavailable'),
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(dashboardLayoutProvider.notifier).load();
        expect(
          container.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
        expect(container.read(dashboardLayoutReadProvider).hasError, isTrue);
      },
    );

    test(
      'absent saved layout qualifies only after a successful read',
      () async {
        SharedPreferences.setMockInitialValues({});
        final container = ProviderContainer();
        addTearDown(container.dispose);
        await container.read(dashboardLayoutProvider.notifier).load();
        expect(container.read(dashboardLayoutReadProvider).hasValue, isTrue);
        expect(container.read(dashboardLayoutReadProvider).value, isNull);
        expect(
          container.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
      },
    );

    test('loads and sanitizes stored order data', () async {
      SharedPreferences.setMockInitialValues({
        dashboardCardOrderStorageKey: <String>[
          'bogus',
          'distance',
          'top-5-highest',
          'elevation',
          'top-5-walks',
        ],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(dashboardLayoutProvider.notifier).load();

      expect(container.read(dashboardLayoutProvider), <String>[
        'distance',
        'my-lists',
        'elevation',
        'my-ascents',
        'time',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
      ]);
    });

    test('saves and reloads the reordered layout', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reordered = <String>[
        'distance',
        'time',
        'elevation',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'my-lists',
        'my-ascents',
      ];

      await container
          .read(dashboardLayoutProvider.notifier)
          .setOrder(reordered);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(dashboardCardOrderStorageKey), reordered);

      final secondContainer = ProviderContainer();
      addTearDown(secondContainer.dispose);

      await secondContainer.read(dashboardLayoutProvider.notifier).load();

      expect(secondContainer.read(dashboardLayoutProvider), reordered);
    });

    test('keeps in-memory order when persistence fails', () async {
      final container = ProviderContainer(
        overrides: [
          dashboardPreferencesLoaderProvider.overrideWithValue(
            () async => throw StateError('boom'),
          ),
        ],
      );
      addTearDown(container.dispose);

      final nextOrder = <String>[
        'my-lists',
        'distance',
        'time',
        'elevation',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'my-ascents',
      ];

      await container
          .read(dashboardLayoutProvider.notifier)
          .setOrder(nextOrder);

      expect(container.read(dashboardLayoutProvider), nextOrder);
    });

    test('moveCard reorders and persists the next order', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(dashboardLayoutProvider.notifier)
          .moveCard('distance', 'peaks-bagged');

      const expected = <String>[
        'elevation',
        'time',
        'latest-walk',
        'distance',
        'peaks-bagged',
        'year-to-date',
        'my-lists',
        'my-ascents',
      ];

      expect(container.read(dashboardLayoutProvider), expected);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(dashboardCardOrderStorageKey), expected);
    });

    test(
      'one-position movement bounds and unchanged orders never write',
      () async {
        SharedPreferences.setMockInitialValues({});
        final writer = ControlledDashboardOrderWriter();
        final container = ProviderContainer(
          overrides: [
            dashboardOrderWriterProvider.overrideWithValue(writer.call),
          ],
        );
        addTearDown(container.dispose);
        final layout = container.read(dashboardLayoutProvider.notifier);
        await layout.moveCardOnePosition('elevation', forward: false);
        await layout.moveCardOnePosition('my-ascents', forward: true);
        await layout.moveCardOnePosition('unknown', forward: true);
        await layout.setOrder([...dashboardDefaultCardOrder, 'bogus', 'time']);
        await layout.moveCard('distance', 'distance');
        expect(writer.writes, isEmpty);
        expect(container.read(dashboardOrderSaveProvider), isNull);
        await layout.moveCardOnePosition('distance', forward: true);
        expect(container.read(dashboardLayoutProvider).take(3), [
          'elevation',
          'time',
          'distance',
        ]);
        await layout.moveCardOnePosition('distance', forward: false);
        expect(
          container.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
        expect(writer.writes, hasLength(2));
      },
    );

    for (final throws in [false, true]) {
      test(
        'retains failed order, logs, retries latest and reloads ($throws)',
        () async {
          final previous = dashboardDefaultCardOrder.reversed.toList();
          SharedPreferences.setMockInitialValues({
            dashboardCardOrderStorageKey: previous,
          });
          final writer = ControlledDashboardOrderWriter();
          Future<bool> fail() async {
            if (throws) throw StateError('controlled write error');
            return false;
          }

          writer.steps.addAll([fail, fail]);
          final diagnostics = <(List<String>, Object, StackTrace)>[];
          final container = ProviderContainer(
            overrides: [
              dashboardOrderWriterProvider.overrideWithValue(writer.call),
              dashboardOrderDiagnosticsProvider.overrideWithValue(
                (order, error, stack) => diagnostics.add((order, error, stack)),
              ),
            ],
          );
          addTearDown(container.dispose);
          final layout = container.read(dashboardLayoutProvider.notifier);
          await layout.load();
          await layout.moveCardOnePosition('time', forward: true);
          final failed = container.read(dashboardLayoutProvider);
          expect(failed, isNot(dashboardDefaultCardOrder));
          expect(container.read(dashboardOrderSaveProvider)?.hasError, isTrue);
          final beforeRetry = ProviderContainer();
          addTearDown(beforeRetry.dispose);
          await beforeRetry.read(dashboardLayoutProvider.notifier).load();
          expect(beforeRetry.read(dashboardLayoutProvider), previous);
          await layout.moveCardOnePosition('time', forward: true);
          final latest = container.read(dashboardLayoutProvider);
          expect(latest, isNot(failed));
          expect(diagnostics, hasLength(2));
          expect(diagnostics.last.$1, latest);
          expect(
            diagnostics.last.$2.toString(),
            contains(throws ? 'controlled' : 'false'),
          );
          expect(diagnostics.last.$3.toString(), isNotEmpty);
          await container.read(dashboardOrderSaveProvider.notifier).retry();
          expect(writer.writes, [failed, latest, latest]);
          expect(container.read(dashboardOrderSaveProvider)?.hasValue, isTrue);
          final afterRetry = ProviderContainer();
          addTearDown(afterRetry.dispose);
          await afterRetry.read(dashboardLayoutProvider.notifier).load();
          expect(afterRetry.read(dashboardLayoutProvider), latest);
        },
      );
    }

    test(
      'serializes writes, coalesces moves and deduplicates pending Retry',
      () async {
        SharedPreferences.setMockInitialValues({});
        final first = Completer<bool>();
        final last = Completer<bool>();
        final writer = ControlledDashboardOrderWriter()
          ..steps.addAll([() => first.future, () => last.future]);
        final container = ProviderContainer(
          overrides: [
            dashboardOrderWriterProvider.overrideWithValue(writer.call),
          ],
        );
        addTearDown(container.dispose);
        final layout = container.read(dashboardLayoutProvider.notifier);
        final saving = layout.moveCardOnePosition('time', forward: true);
        final original = container.read(dashboardLayoutProvider);
        expect(container.read(dashboardOrderSaveProvider)?.isLoading, isTrue);
        final more = layout.moveCardOnePosition('time', forward: true);
        final finalMove = layout.moveCardOnePosition(
          'distance',
          forward: false,
        );
        await Future<void>.delayed(Duration.zero);
        final latest = container.read(dashboardLayoutProvider);
        final saver = container.read(dashboardOrderSaveProvider.notifier);
        expect(saver.retry(), same(saver.retry()));
        expect(writer.writes, [original]);
        first.complete(true);
        await Future<void>.delayed(Duration.zero);
        expect(writer.writes, [original, latest]);
        expect(container.read(dashboardOrderSaveProvider)?.isLoading, isTrue);
        expect(container.read(dashboardLayoutProvider), latest);
        last.complete(true);
        await Future.wait([saving, more, finalMove]);
        expect(container.read(dashboardOrderSaveProvider)?.hasValue, isTrue);
        final reloaded = ProviderContainer();
        addTearDown(reloaded.dispose);
        await reloaded.read(dashboardLayoutProvider.notifier).load();
        expect(reloaded.read(dashboardLayoutProvider), latest);
      },
    );

    test(
      'superseded failure is diagnostic only; latest save owns outcome',
      () async {
        SharedPreferences.setMockInitialValues({});
        final gate = Completer<bool>();
        final writer = ControlledDashboardOrderWriter()
          ..steps.add(() => gate.future);
        var failures = 0;
        final container = ProviderContainer(
          overrides: [
            dashboardOrderWriterProvider.overrideWithValue(writer.call),
            dashboardOrderDiagnosticsProvider.overrideWithValue(
              (_, _, _) => failures++,
            ),
          ],
        );
        addTearDown(container.dispose);
        final outcomes = <AsyncValue<void>?>[];
        container.listen(
          dashboardOrderSaveProvider,
          (_, next) => outcomes.add(next),
        );
        final layout = container.read(dashboardLayoutProvider.notifier);
        final first = layout.moveCardOnePosition('time', forward: true);
        final latest = layout.moveCardOnePosition('distance', forward: false);
        gate.completeError(StateError('old failure'));
        await Future.wait([first, latest]);
        expect(failures, 1);
        expect(writer.writes, hasLength(2));
        expect(outcomes.any((s) => s?.hasError == true), isFalse);
        expect(outcomes.last?.hasValue, isTrue);
      },
    );

    test(
      'late load cannot overwrite moves even after returning to defaults',
      () async {
        SharedPreferences.setMockInitialValues({
          dashboardCardOrderStorageKey: ['my-ascents'],
        });
        final gate = Completer<List<String>?>();
        final container = ProviderContainer(
          overrides: [
            dashboardLayoutReadProvider.overrideWith((ref) => gate.future),
            dashboardOrderWriterProvider.overrideWithValue((_) async => true),
          ],
        );
        addTearDown(container.dispose);
        final layout = container.read(dashboardLayoutProvider.notifier);
        final loading = layout.load();
        await layout.moveCardOnePosition('time', forward: true);
        await layout.moveCardOnePosition('time', forward: false);
        gate.complete(['my-ascents']);
        await loading;
        expect(
          container.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
      },
    );

    test(
      'new layout reads durable preferences rather than optimistic cached order',
      () async {
        SharedPreferences.setMockInitialValues({});
        final cached = await SharedPreferences.getInstance();
        final failedOrder = dashboardDefaultCardOrder.reversed.toList();
        await cached.setStringList(dashboardCardOrderStorageKey, failedOrder);
        // Simulate an optimistic cache whose failed write did not reach storage.
        SharedPreferences.setMockInitialValues({
          dashboardCardOrderStorageKey: dashboardDefaultCardOrder,
        });
        expect(cached.getStringList(dashboardCardOrderStorageKey), failedOrder);
        final container = ProviderContainer(
          overrides: [
            dashboardPreferencesLoaderProvider.overrideWithValue(
              () async => cached,
            ),
          ],
        );
        addTearDown(container.dispose);
        await container.read(dashboardLayoutProvider.notifier).load();
        expect(
          container.read(dashboardLayoutProvider),
          dashboardDefaultCardOrder,
        );
      },
    );

    test(
      'disposal ends queued work without stale provider publication',
      () async {
        SharedPreferences.setMockInitialValues({});
        final gate = Completer<bool>();
        final writer = ControlledDashboardOrderWriter()
          ..steps.add(() => gate.future);
        final container = ProviderContainer(
          overrides: [
            dashboardOrderWriterProvider.overrideWithValue(writer.call),
          ],
        );
        final layout = container.read(dashboardLayoutProvider.notifier);
        final first = layout.moveCardOnePosition('time', forward: true);
        final second = layout.moveCardOnePosition('time', forward: true);
        container.dispose();
        gate.complete(true);
        await Future.wait([first, second]);
        expect(writer.writes, hasLength(1));
      },
    );
  });
}
