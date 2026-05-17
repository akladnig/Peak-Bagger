import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DashboardLayoutNotifier', () {
    test('starts with the default order', () {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(dashboardLayoutProvider),
        dashboardDefaultCardOrder,
      );
    });

    test('loads and sanitizes stored order data', () async {
      SharedPreferences.setMockInitialValues({
        dashboardCardOrderStorageKey: <String>[
          'bogus',
          'distance',
          'top-5-highest',
          'elevation',
        ],
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(dashboardLayoutProvider.notifier).load();

      expect(container.read(dashboardLayoutProvider), <String>[
        'distance',
        'my-lists',
        'elevation',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'top-5-walks',
      ]);
    });

    test('saves and reloads the reordered layout', () async {
      SharedPreferences.setMockInitialValues({});

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final reordered = <String>[
        'distance',
        'elevation',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'my-lists',
        'top-5-walks',
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
        'elevation',
        'latest-walk',
        'peaks-bagged',
        'year-to-date',
        'top-5-walks',
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
        'latest-walk',
        'distance',
        'peaks-bagged',
        'year-to-date',
        'my-lists',
        'top-5-walks',
      ];

      expect(container.read(dashboardLayoutProvider), expected);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList(dashboardCardOrderStorageKey), expected);
    });
  });
}
