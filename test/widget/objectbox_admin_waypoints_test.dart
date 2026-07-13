import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

void main() {
  testWidgets(
    'waypoints rows render delete affordance and callback removes row',
    (tester) async {
      final entity = const ObjectBoxAdminEntityDescriptor(
        name: 'Waypoints',
        displayName: 'Waypoints',
        primaryKeyField: 'id',
        primaryNameField: 'name',
        fields: [
          ObjectBoxAdminFieldDescriptor(
            name: 'id',
            typeLabel: 'int',
            nullable: false,
            isPrimaryKey: true,
            isPrimaryName: false,
          ),
          ObjectBoxAdminFieldDescriptor(
            name: 'name',
            typeLabel: 'String',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: true,
          ),
          ObjectBoxAdminFieldDescriptor(
            name: 'type',
            typeLabel: 'String',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: false,
          ),
          ObjectBoxAdminFieldDescriptor(
            name: 'latitude',
            typeLabel: 'double',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: false,
          ),
          ObjectBoxAdminFieldDescriptor(
            name: 'longitude',
            typeLabel: 'double',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: false,
          ),
          ObjectBoxAdminFieldDescriptor(
            name: 'mgrs',
            typeLabel: 'String',
            nullable: false,
            isPrimaryKey: false,
            isPrimaryName: false,
          ),
        ],
      );

      final rows = ValueNotifier<List<ObjectBoxAdminRow>>([
        const ObjectBoxAdminRow(
          primaryKeyValue: 1,
          values: {
            'id': 1,
            'name': 'Camp',
            'type': 'favourite',
            'latitude': -41.5,
            'longitude': 146.5,
            'mgrs': '55G EN 10000 10000',
          },
        ),
      ]);
      addTearDown(rows.dispose);

      final headerController = ScrollController();
      final rowController = ScrollController();
      final verticalController = ScrollController();
      addTearDown(headerController.dispose);
      addTearDown(rowController.dispose);
      addTearDown(verticalController.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<List<ObjectBoxAdminRow>>(
              valueListenable: rows,
              builder: (context, currentRows, child) {
                return ObjectBoxAdminDataGrid(
                  entity: entity,
                  rows: currentRows,
                  sortAscending: true,
                  selectedRow: null,
                  headerHorizontalController: headerController,
                  rowHorizontalControllerFor: (_) => rowController,
                  verticalController: verticalController,
                  canLoadMore: false,
                  onSortPressed: () {},
                  onRowTap: (_) {},
                  onDeletePressed: (row) {
                    rows.value = currentRows
                        .where(
                          (current) =>
                              current.primaryKeyValue != row.primaryKeyValue,
                        )
                        .toList(growable: false);
                  },
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('objectbox-admin-waypoints-delete-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const Key('objectbox-admin-waypoints-delete-1')),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('objectbox-admin-waypoints-delete-1')),
        findsNothing,
      );
    },
  );
}
