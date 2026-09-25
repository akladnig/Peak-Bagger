import 'package:flutter/material.dart';
import 'package:peak_bagger/theme.dart';

import '../core/constants.dart';
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
    this.deleteEnabled = true,
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
  final bool deleteEnabled;

  @override
  Widget build(BuildContext context) {
    const primaryColumnWidth = UiConstants.primaryColumnWidth;
    const actionsColumnWidth = UiConstants.actionsColumnWidth;

    final tableFields = entity.name == 'Peak'
        ? peakAdminTableFields(entity)
        : entity.fields;
    if (tableFields.isEmpty) {
      return const SizedBox.shrink();
    }
    final otherFields = tableFields
        .where((field) => !field.isPrimaryName)
        .toList(growable: false);
    final primaryField = tableFields.firstWhere(
      (field) => field.isPrimaryName,
      orElse: () => tableFields.firstWhere(
        (field) => field.isPrimaryKey,
        orElse: () => tableFields.first,
      ),
    );
    final showActionsColumn =
        (entity.name == 'Peak' ||
            entity.name == 'NaturalFeature' ||
            entity.name == 'Contact' ||
            entity.name == 'GpxTrack' ||
            entity.name == 'Route' ||
            entity.name == 'Waypoints') &&
        onDeletePressed != null;
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
        const _ObjectBoxAdminDataGridDivider(),
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
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ObjectBoxAdminDataRowTile(
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
                          : deleteEnabled
                          ? () => onDeletePressed!(row)
                          : null,
                    ),
                    if (index < rows.length - 1)
                      const _ObjectBoxAdminDataGridDivider(),
                  ],
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
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    return Padding(
      padding: dataGridTheme.headerPadding,
      child: DefaultTextStyle.merge(
        style: dataGridTheme.headerTextStyle,
        child: Row(
          children: [
            ObjectBoxAdminCell(
              width: primaryColumnWidth,
              child: InkWell(
                onTap: onSortPressed,
                child: Row(
                  children: [
                    Expanded(child: Text(primaryField.name)),
                    Icon(
                      sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: dataGridTheme.columnGap),
            Expanded(
              child: SingleChildScrollView(
                controller: horizontalController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _withColumnGaps(
                    otherFields.map(
                      (field) => ObjectBoxAdminCell(
                        width: 160,
                        child: Text(field.name),
                      ),
                    ),
                    dataGridTheme.columnGap,
                  ),
                ),
              ),
            ),
            if (showActionsColumn) ...[
              SizedBox(width: dataGridTheme.columnGap),
              ObjectBoxAdminCell(
                width: actionsColumnWidth,
                child: const Center(child: Text('Delete')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

List<Widget> _withColumnGaps(Iterable<Widget> children, double gap) {
  final columns = children.toList(growable: false);
  return [
    for (var index = 0; index < columns.length; index++) ...[
      if (index > 0) SizedBox(width: gap),
      columns[index],
    ],
  ];
}

class _ObjectBoxAdminDataGridDivider extends StatelessWidget {
  const _ObjectBoxAdminDataGridDivider();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    return Divider(
      height: dataGridTheme.dividerThickness,
      thickness: dataGridTheme.dividerThickness,
      color: dataGridTheme.dividerColor,
    );
  }
}

class ObjectBoxAdminDataRowTile extends StatefulWidget {
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
  State<ObjectBoxAdminDataRowTile> createState() =>
      _ObjectBoxAdminDataRowTileState();
}

class _ObjectBoxAdminDataRowTileState extends State<ObjectBoxAdminDataRowTile> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataGridTheme =
        theme.extension<DataGridTheme>() ??
        DataGridTheme.fromColorScheme(theme.colorScheme, theme.textTheme);
    return Container(
      decoration: _rowDecoration(dataGridTheme),
      child: Listener(
        onPointerDown: (_) => _setPressed(true),
        onPointerUp: (_) => _setPressed(false),
        onPointerCancel: (_) => _setPressed(false),
        child: Semantics(
          container: true,
          selected: widget.selected,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              onHover: _setHovered,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              focusColor: Colors.transparent,
              child: Padding(
                padding: dataGridTheme.rowPadding,
                child: DefaultTextStyle.merge(
                  style: dataGridTheme.rowTextStyle,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ObjectBoxAdminCell(
                        width: widget.primaryColumnWidth,
                        child: Text(
                          objectBoxAdminPreviewFieldValue(
                            entityName: widget.entityName,
                            fieldName: widget.primaryField.name,
                            value: widget.row.values[widget.primaryField.name],
                          ),
                          maxLines: null,
                          softWrap: true,
                        ),
                      ),
                      SizedBox(width: dataGridTheme.columnGap),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: widget.horizontalController,
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _withColumnGaps(
                              widget.otherFields.map(
                                (field) => ObjectBoxAdminCell(
                                  width: 160,
                                  child: Text(
                                    objectBoxAdminPreviewFieldValue(
                                      entityName: widget.entityName,
                                      fieldName: field.name,
                                      value: widget.row.values[field.name],
                                    ),
                                    maxLines: null,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                              dataGridTheme.columnGap,
                            ),
                          ),
                        ),
                      ),
                      if (widget.showActionsColumn) ...[
                        SizedBox(width: dataGridTheme.columnGap),
                        ObjectBoxAdminCell(
                          width: widget.actionsColumnWidth,
                          child: Center(
                            child: IconButton(
                              key: Key(
                                _deleteKey(widget.entityName, widget.row),
                              ),
                              tooltip: 'Delete',
                              onPressed: widget.onDeletePressed,
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration? _rowDecoration(DataGridTheme dataGridTheme) {
    if (widget.selected) {
      return BoxDecoration(
        color: dataGridTheme.selectedRowColor,
        border: Border.symmetric(
          horizontal: BorderSide(color: dataGridTheme.selectedRowBorderColor),
        ),
      );
    }
    if (_isPressed) {
      return BoxDecoration(color: dataGridTheme.pressedRowColor);
    }
    if (_isHovered) {
      return BoxDecoration(color: dataGridTheme.hoverColor);
    }
    return null;
  }

  void _setHovered(bool value) {
    if (_isHovered != value) {
      setState(() => _isHovered = value);
    }
  }

  void _setPressed(bool value) {
    if (_isPressed != value) {
      setState(() => _isPressed = value);
    }
  }
}

String _deleteKey(String entityName, ObjectBoxAdminRow row) {
  return switch (entityName) {
    'NaturalFeature' =>
      'objectbox-admin-natural-feature-delete-${row.primaryKeyValue}',
    'Contact' => 'objectbox-admin-contact-delete-${row.primaryKeyValue}',
    'GpxTrack' => 'objectbox-admin-gpx-track-delete-${row.primaryKeyValue}',
    'Route' => 'objectbox-admin-route-delete-${row.primaryKeyValue}',
    'Waypoints' => 'objectbox-admin-waypoints-delete-${row.primaryKeyValue}',
    _ => 'objectbox-admin-peak-delete-${row.primaryKeyValue}',
  };
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
    return SizedBox(width: width, child: child);
  }
}
