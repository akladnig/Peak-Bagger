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
            TestObjectBoxAdminRepository(),
          ),
        ],
        child: const App(),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('side-menu-objectbox-admin')), findsOneWidget);

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

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
  });

  testWidgets('admin shell reloads rows when re-entered', (tester) async {
    final repository = TestObjectBoxAdminRepository();

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
          objectboxAdminRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );

    await tester.pump();

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final initialEntityCalls = repository.getEntitiesCallCount;
    final initialLoadRowsCalls = repository.loadRowsCallCount;

    await tester.tap(find.byIcon(Icons.settings));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(repository.getEntitiesCallCount, greaterThan(initialEntityCalls));
    expect(repository.loadRowsCallCount, greaterThan(initialLoadRowsCalls));
  });
}
