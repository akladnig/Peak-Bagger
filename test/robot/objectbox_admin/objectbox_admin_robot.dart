import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';

import '../../harness/test_map_notifier.dart';
import '../../harness/test_objectbox_admin_repository.dart';

class ObjectBoxAdminRobot {
  ObjectBoxAdminRobot(this.tester);

  final WidgetTester tester;

  Finder get adminMenuItem =>
      find.byKey(const Key('side-menu-objectbox-admin'));
  Finder get entityDropdown =>
      find.byKey(const Key('objectbox-admin-entity-dropdown'));
  Finder get schemaDataToggle =>
      find.byKey(const Key('objectbox-admin-schema-data-toggle'));
  Finder get table => find.byKey(const Key('objectbox-admin-table'));

  Future<void> pumpApp() async {
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
  }

  Future<void> openAdminFromMenu() async {
    await tester.tap(adminMenuItem);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  void expectAdminShellVisible() {
    expect(entityDropdown, findsOneWidget);
    expect(schemaDataToggle, findsOneWidget);
    expect(table, findsOneWidget);
  }
}
