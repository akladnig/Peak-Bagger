import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';

void main() {
  testWidgets('admin browser filters rows and closes details pane', (
    tester,
  ) async {
    await _pumpApp(tester, TestObjectBoxAdminRepository());

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('Mt Ossa'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('objectbox-admin-details-close')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('objectbox-admin-details-close')));
    await tester.pumpAndSettle();

    expect(find.text('Select a row to inspect full values.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'cradle');
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('No matches'), findsOneWidget);
  });

  testWidgets('admin browser loads rows in chunks of 50', (tester) async {
    final rows = List<ObjectBoxAdminRow>.generate(
      60,
      (index) => ObjectBoxAdminRow(
        primaryKeyValue: index + 1,
        values: {'id': index + 1, 'name': 'Peak $index'},
      ),
    );

    await _pumpApp(
      tester,
      TestObjectBoxAdminRepository(
        rowsByEntity: {
          'Peak': rows,
          'Tasmap50k': const [],
          'GpxTrack': const [],
        },
      ),
    );

    await tester.tap(find.byKey(const Key('side-menu-objectbox-admin')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Peak 59'), findsNothing);

    final rowList = find.byKey(const Key('objectbox-admin-row-list'));
    await tester.drag(rowList, const Offset(0, -3000));
    await tester.pumpAndSettle();

    if (find.text('Peak 59').evaluate().isEmpty) {
      await tester.drag(rowList, const Offset(0, -3000));
      await tester.pumpAndSettle();
    }

    expect(find.text('Peak 59'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester,
  TestObjectBoxAdminRepository repository,
) async {
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
}
