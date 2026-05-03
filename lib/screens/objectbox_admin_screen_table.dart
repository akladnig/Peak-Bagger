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
    required this.onDeletePressed,
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
  final ValueChanged<ObjectBoxAdminRow>? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    const primaryColumnWidth = 144.0;
    const actionsColumnWidth = 72.0;

    final tableFields = entity.name == 'Peak'
        ? peakAdminTableFields(entity)
        : entity.fields;
    final otherFields = tableFields
        .where((field) => !field.isPrimaryName)
        .toList(growable: false);
    final primaryField = tableFields.firstWhere((field) => field.isPrimaryName);
    final showActionsColumn = entity.name == 'Peak' && onDeletePressed != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ObjectBoxAdminDataHeaderRow(
          key: const Key('objectbox-admin-header-row'),
          primaryField: primaryField,
          otherFields: otherFields,
          primaryColumnWidth: primaryColumnWidth,
          actionsColumnWidth: actionsColumnWidth,
          sortAscending: sortAscending,
          horizontalController: headerHorizontalController,
          onSortPressed: onSortPressed,
          showActionsColumn: showActionsColumn,
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
                  entityName: entity.name,
                  row: row,
                  primaryField: primaryField,
                  otherFields: otherFields,
                  primaryColumnWidth: primaryColumnWidth,
                  actionsColumnWidth: actionsColumnWidth,
                  selected: isSelected,
                  horizontalController: rowHorizontalControllerFor(row),
                  onTap: () => onRowTap(row),
                  showActionsColumn: showActionsColumn,
                  onDeletePressed: onDeletePressed == null
                      ? null
                      : () => onDeletePressed!(row),
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
    required this.primaryColumnWidth,
    required this.actionsColumnWidth,
    required this.sortAscending,
    required this.horizontalController,
    required this.onSortPressed,
    required this.showActionsColumn,
    super.key,
  });

  final ObjectBoxAdminFieldDescriptor primaryField;
  final List<ObjectBoxAdminFieldDescriptor> otherFields;
  final double primaryColumnWidth;
  final double actionsColumnWidth;
  final bool sortAscending;
  final ScrollController horizontalController;
  final VoidCallback onSortPressed;
  final bool showActionsColumn;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        ObjectBoxAdminCell(
          width: primaryColumnWidth,
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
        if (showActionsColumn)
          ObjectBoxAdminCell(
            width: actionsColumnWidth,
            child: Center(
              child: Text(
                'Delete',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}

class ObjectBoxAdminDataRowTile extends StatelessWidget {
  const ObjectBoxAdminDataRowTile({
    required this.entityName,
    required this.row,
    required this.primaryField,
    required this.otherFields,
    required this.primaryColumnWidth,
    required this.actionsColumnWidth,
    required this.selected,
    required this.horizontalController,
    required this.onTap,
    required this.showActionsColumn,
    required this.onDeletePressed,
    super.key,
  });

  final String entityName;
  final ObjectBoxAdminRow row;
  final ObjectBoxAdminFieldDescriptor primaryField;
  final List<ObjectBoxAdminFieldDescriptor> otherFields;
  final double primaryColumnWidth;
  final double actionsColumnWidth;
  final bool selected;
  final ScrollController horizontalController;
  final VoidCallback onTap;
  final bool showActionsColumn;
  final VoidCallback? onDeletePressed;

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
              width: primaryColumnWidth,
              child: ColoredBox(
                color: selected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surface,
                child: Text(
                  objectBoxAdminPreviewFieldValue(
                    entityName: entityName,
                    fieldName: primaryField.name,
                    value: row.values[primaryField.name],
                  ),
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
                            objectBoxAdminPreviewFieldValue(
                              entityName: entityName,
                              fieldName: field.name,
                              value: row.values[field.name],
                            ),
                            maxLines: null,
                            softWrap: true,
                          ),
                        ),
                      )
                      .toList(growable: false),
                ),
              ),
            ),
            if (showActionsColumn)
              ObjectBoxAdminCell(
                width: actionsColumnWidth,
                child: Center(
                  child: IconButton(
                    key: Key(
                      'objectbox-admin-peak-delete-${row.primaryKeyValue}',
                    ),
                    tooltip: 'Delete',
                    onPressed: onDeletePressed,
                    icon: const Icon(Icons.delete_outline),
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
