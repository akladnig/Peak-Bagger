import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/theme.dart';

void main() {
  testWidgets(
    'data grid keeps shared style and interaction semantics at large text scale',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const entity = ObjectBoxAdminEntityDescriptor(
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
      const rows = [
        ObjectBoxAdminRow(
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
        ObjectBoxAdminRow(
          primaryKeyValue: 2,
          values: {
            'id': 2,
            'name': 'Long ridge camp with a descriptive name',
            'type': 'shelter',
            'latitude': -41.6,
            'longitude': 146.6,
            'mgrs': '55G EN 20000 20000',
          },
        ),
      ];
      final headerController = ScrollController();
      final rowControllers = [ScrollController(), ScrollController()];
      final verticalController = ScrollController();
      addTearDown(headerController.dispose);
      addTearDown(verticalController.dispose);
      addTearDown(() {
        for (final controller in rowControllers) {
          controller.dispose();
        }
      });
      var sortCount = 0;
      var rowTapCount = 0;
      var deleteCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: MyTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: ObjectBoxAdminDataGrid(
                entity: entity,
                rows: rows,
                sortAscending: true,
                selectedRow: rows.first,
                headerHorizontalController: headerController,
                rowHorizontalControllerFor: (row) =>
                    rowControllers[(row.primaryKeyValue as int) - 1],
                verticalController: verticalController,
                canLoadMore: false,
                onSortPressed: () => sortCount++,
                onRowTap: (_) => rowTapCount++,
                onDeletePressed: (_) => deleteCount++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dataGridTheme = MyTheme.light.extension<DataGridTheme>()!;
      final rowTiles = find.byType(ObjectBoxAdminDataRowTile);
      final selectedRowContainer = find.descendant(
        of: rowTiles.first,
        matching: find.byType(Container),
      );
      final selectedDecoration =
          tester.widget<Container>(selectedRowContainer).decoration
              as BoxDecoration;
      expect(selectedDecoration.color, dataGridTheme.selectedRowColor);
      expect(
        selectedDecoration.border,
        Border.symmetric(
          horizontal: BorderSide(color: dataGridTheme.selectedRowBorderColor),
        ),
      );
      expect(find.byType(Divider), findsNWidgets(2));
      expect(tester.takeException(), isNull);

      final camp = find.text('Camp');
      final campBeforeScroll = tester.getTopLeft(camp).dx;
      rowControllers.first.jumpTo(100);
      await tester.pump();
      expect(tester.getTopLeft(camp).dx, campBeforeScroll);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: tester.getCenter(camp));
      await mouse.moveTo(tester.getCenter(camp));
      await tester.pump();
      expect(
        (tester.widget<Container>(selectedRowContainer).decoration
                as BoxDecoration)
            .color,
        dataGridTheme.selectedRowColor,
      );

      final secondRowContainer = find.descendant(
        of: rowTiles.at(1),
        matching: find.byType(Container),
      );
      final secondRowName = find.text(
        'Long ridge camp with a descriptive name',
      );
      await mouse.moveTo(tester.getCenter(secondRowName));
      await tester.pump();
      expect(
        (tester.widget<Container>(secondRowContainer).decoration
                as BoxDecoration)
            .color,
        dataGridTheme.hoverColor,
      );

      final headerSort = find.ancestor(
        of: find.text('name'),
        matching: find.byType(InkWell),
      );
      expect(
        tester.getSemantics(headerSort),
        matchesSemantics(
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(sortCount, 1);

      final selectedRowSemantics = find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      );
      expect(
        tester.getSemantics(selectedRowSemantics),
        matchesSemantics(
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
          hasFocusAction: true,
          isFocusable: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(rowTapCount, 1);

      final delete = find.byKey(
        const Key('objectbox-admin-waypoints-delete-1'),
      );
      expect(
        tester.getSemantics(delete),
        matchesSemantics(
          hasTapAction: true,
          hasFocusAction: true,
          hasEnabledState: true,
          isButton: true,
          isEnabled: true,
          isFocusable: true,
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(deleteCount, 1);
      expect(tester.takeException(), isNull);
    },
  );

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
