import 'package:flutter/material.dart';

import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminDataGrid extends StatelessWidget {
  const ObjectBoxAdminDataGrid({
    required this.entity,
    required this.rows,
    required this.sortAscending,
    required this.selectedRow,
    required this.headerHorizontalController,
    required this.rowHorizontalControllerFor,
    required this.verticalController,
    required this.canLoadMore,
    required this.onSortPressed,
    required this.onRowTap,
    super.key,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final List<ObjectBoxAdminRow> rows;
  final bool sortAscending;
  final ObjectBoxAdminRow? selectedRow;
  final ScrollController headerHorizontalController;
  final ScrollController Function(ObjectBoxAdminRow row)
  rowHorizontalControllerFor;
  final ScrollController verticalController;
  final bool canLoadMore;
  final VoidCallback onSortPressed;
  final ValueChanged<ObjectBoxAdminRow> onRowTap;

  @override
  Widget build(BuildContext context) {
    final otherFields = entity.fields
        .where((field) => !field.isPrimaryName)
        .toList(growable: false);
    final primaryField = entity.fields.firstWhere(
      (field) => field.isPrimaryName,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectBoxAdminDataHeaderRow(
          key: const Key('objectbox-admin-header-row'),
          primaryField: primaryField,
          otherFields: otherFields,
          sortAscending: sortAscending,
          horizontalController: headerHorizontalController,
          onSortPressed: onSortPressed,
        ),
        const Divider(height: 1),
        Expanded(
          child: Scrollbar(
            controller: verticalController,
            child: ListView.builder(
              key: const Key('objectbox-admin-row-list'),
              controller: verticalController,
              itemCount: rows.length + (canLoadMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == rows.length && canLoadMore) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final row = rows[index];
                final isSelected =
                    selectedRow?.primaryKeyValue == row.primaryKeyValue;
                return ObjectBoxAdminDataRowTile(
                  row: row,
                  primaryField: primaryField,
                  otherFields: otherFields,
                  selected: isSelected,
                  horizontalController: rowHorizontalControllerFor(row),
                  onTap: () => onRowTap(row),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ObjectBoxAdminDataHeaderRow extends StatelessWidget {
  const ObjectBoxAdminDataHeaderRow({
    required this.primaryField,
    required this.otherFields,
    required this.sortAscending,
    required this.horizontalController,
    required this.onSortPressed,
    super.key,
  });

  final ObjectBoxAdminFieldDescriptor primaryField;
  final List<ObjectBoxAdminFieldDescriptor> otherFields;
  final bool sortAscending;
  final ScrollController horizontalController;
  final VoidCallback onSortPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ObjectBoxAdminCell(
          width: 160,
          child: GestureDetector(
            onTap: onSortPressed,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    primaryField.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Icon(
                  sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: otherFields
                  .map(
                    (field) => ObjectBoxAdminCell(
                      width: 160,
                      child: Text(
                        field.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ),
      ],
    );
  }
}

class ObjectBoxAdminDataRowTile extends StatelessWidget {
  const ObjectBoxAdminDataRowTile({
    required this.row,
    required this.primaryField,
    required this.otherFields,
    required this.selected,
    required this.horizontalController,
    required this.onTap,
    super.key,
  });

  final ObjectBoxAdminRow row;
  final ObjectBoxAdminFieldDescriptor primaryField;
  final List<ObjectBoxAdminFieldDescriptor> otherFields;
  final bool selected;
  final ScrollController horizontalController;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final highlight = selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.transparent;

    return Material(
      color: highlight,
      child: InkWell(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ObjectBoxAdminCell(
              width: 160,
              child: ColoredBox(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                child: Text(
                  objectBoxAdminPreviewValue(row.values[primaryField.name]),
                  maxLines: null,
                  softWrap: true,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: otherFields
                      .map(
                        (field) => ObjectBoxAdminCell(
                          width: 160,
                          child: Text(
                            objectBoxAdminPreviewValue(row.values[field.name]),
                            maxLines: null,
                            softWrap: true,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ObjectBoxAdminCell extends StatelessWidget {
  const ObjectBoxAdminCell({
    required this.width,
    required this.child,
    super.key,
  });

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodySmall!,
          child: child,
        ),
      ),
    );
  }
}
