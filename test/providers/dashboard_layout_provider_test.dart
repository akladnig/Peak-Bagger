import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  });
}
