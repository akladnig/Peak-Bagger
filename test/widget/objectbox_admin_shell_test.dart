import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';

void main() {
  testWidgets('admin shell opens from side menu', (tester) async {
    await _pumpApp(tester);

    expect(find.byKey(const Key('shared-app-bar')), findsOneWidget);
    expect(find.byKey(const Key('app-bar-title')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('nav-objectbox-admin')), findsOneWidget);
    expect(find.byKey(const Key('side-menu-objectbox-admin')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('objectbox-admin-entity-dropdown')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('objectbox-admin-schema-data-toggle')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('objectbox-admin-export-gpx')), findsNothing);
    expect(find.byKey(const Key('objectbox-admin-table')), findsOneWidget);

    await tester.tap(find.byKey(const Key('objectbox-admin-entity-dropdown')));
    await tester.pumpAndSettle();

    expect(find.text('PeaksBagged').last, findsOneWidget);
  });

  testWidgets('admin shell reloads rows when re-entered', (tester) async {
    final repository = TestObjectBoxAdminRepository();

    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final initialEntityCalls = repository.getEntitiesCallCount;
    final initialLoadRowsCalls = repository.loadRowsCallCount;

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.getEntitiesCallCount, greaterThan(initialEntityCalls));
    expect(repository.loadRowsCallCount, greaterThan(initialLoadRowsCalls));
  });

  testWidgets(
    'compact shell uses drawer and closes on active destination tap',
    (tester) async {
      await _pumpApp(tester, size: const Size(600, 900));

      expect(find.byKey(const Key('app-bar-menu')), findsOneWidget);
      expect(find.byKey(const Key('nav-objectbox-admin')), findsNothing);

      await tester.tap(find.byKey(const Key('app-bar-menu')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav-dashboard')), findsOneWidget);
      expect(find.byKey(const Key('nav-objectbox-admin')), findsOneWidget);

      await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('app-bar-title')),
          matching: find.text('ObjectBox Admin'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('nav-dashboard')), findsNothing);

      await tester.tap(find.byKey(const Key('app-bar-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('nav-dashboard')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const Key('app-bar-title')),
          matching: find.text('ObjectBox Admin'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('home action returns to dashboard and is a no-op there', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const Key('nav-objectbox-admin')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('ObjectBox Admin'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-bar-home')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('app-bar-home')));
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.text('Dashboard'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('wide destinations render in shared order', (tester) async {
    await _pumpApp(tester);

    final dashboard = tester.getTopLeft(find.byKey(const Key('nav-dashboard')));
    final map = tester.getTopLeft(find.byKey(const Key('nav-map')));
    final peakLists = tester.getTopLeft(
      find.byKey(const Key('nav-peak-lists')),
    );
    final admin = tester.getTopLeft(
      find.byKey(const Key('nav-objectbox-admin')),
    );
    final settings = tester.getTopLeft(find.byKey(const Key('nav-settings')));

    expect(dashboard.dy, lessThan(map.dy));
    expect(map.dy, lessThan(peakLists.dy));
    expect(peakLists.dy, lessThan(admin.dy));
    expect(admin.dy, lessThan(settings.dy));
  });

  testWidgets(
    'wide home icon aligns with nav icons and title is left-aligned',
    (tester) async {
      await _pumpApp(tester);

      final homeCenter = tester.getCenter(
        find.byKey(const Key('app-bar-home')),
      );
      final dashboardCenter = tester.getCenter(
        find.byKey(const Key('nav-dashboard')),
      );
      final titleTopLeft = tester.getTopLeft(
        find.byKey(const Key('app-bar-title')),
      );

      expect(homeCenter.dx, dashboardCenter.dx);
      expect(titleTopLeft.dx, 132);
    },
  );
}

Future<void> _pumpApp(
  WidgetTester tester, {
  TestObjectBoxAdminRepository? repository,
  Size size = const Size(1000, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        objectboxAdminRepositoryProvider.overrideWithValue(
          repository ?? TestObjectBoxAdminRepository(),
        ),
      ],
      child: const App(),
    ),
  );

  await tester.pump();
}
