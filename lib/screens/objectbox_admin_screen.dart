import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

class ObjectBoxAdminScreen extends ConsumerStatefulWidget {
  const ObjectBoxAdminScreen({super.key});

  @override
  ConsumerState<ObjectBoxAdminScreen> createState() =>
      _ObjectBoxAdminScreenState();
}

class _ObjectBoxAdminScreenState extends ConsumerState<ObjectBoxAdminScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_maybeLoadMore);
  }

  @override
  void dispose() {
    _verticalController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _horizontalController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _maybeLoadMore() {
    if (!_verticalController.hasClients) {
      return;
    }

    final position = _verticalController.position;
    if (position.extentAfter < 400) {
      ref.read(objectboxAdminProvider.notifier).loadMoreRows();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(objectboxAdminProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);

    if (_searchController.text != state.searchQuery) {
      _searchController.text = state.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('ObjectBox Admin')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AdminControls(
              state: state,
              searchController: _searchController,
              onEntityChanged: (entity) {
                if (entity == null) {
                  return;
                }
                _searchController.clear();
                notifier.selectEntity(entity);
              },
              onModeChanged: notifier.setMode,
              onSearchChanged: notifier.updateSearchQuery,
              onSearchSubmitted: notifier.runSearch,
              onSearchPressed: notifier.runSearch,
              onSortPressed: notifier.toggleSort,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: _buildBody(context, state, notifier),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ObjectBoxAdminState state,
    ObjectBoxAdminNotifier notifier,
  ) {
    if (state.entities.isEmpty) {
      return const _EmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No selectable entities',
        message: 'The store has no ObjectBox entities to inspect.',
      );
    }

    if (state.error != null) {
      return _ErrorState(
        key: const Key('objectbox-admin-error-state'),
        message: state.error!,
      );
    }

    if (state.isLoading) {
      return const _LoadingState();
    }

    final entity = state.selectedEntity;
    if (entity == null) {
      return const _EmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No entity selected',
        message: 'Choose an entity to inspect its schema or rows.',
      );
    }

    if (state.mode == ObjectBoxAdminViewMode.schema) {
      return _SchemaView(entity: entity);
    }

    if (state.noMatches) {
      return const _EmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No matches',
        message: 'The current search returned no rows.',
      );
    }

    if (state.rows.isEmpty) {
      return _EmptyState(
        key: const Key('objectbox-admin-empty-state'),
        title: 'No rows',
        message: 'This entity has no stored rows yet.',
      );
    }

    return Row(
      children: [
        Expanded(
          child: _DataGrid(
            key: const Key('objectbox-admin-table'),
            entity: entity,
            rows: state.visibleRows,
            sortAscending: state.sortAscending,
            selectedRow: state.selectedRow,
            horizontalController: _horizontalController,
            verticalController: _verticalController,
            canLoadMore: state.visibleRowCount < state.rows.length,
            onLoadMore: notifier.loadMoreRows,
            onSortPressed: notifier.toggleSort,
            onRowTap: notifier.selectRow,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: _DetailsPane(
            row: state.selectedRow,
            entity: entity,
            onClose: notifier.clearSelection,
          ),
        ),
      ],
    );
  }
}

class _AdminControls extends StatelessWidget {
  const _AdminControls({
    required this.state,
    required this.searchController,
    required this.onEntityChanged,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchPressed,
    required this.onSortPressed,
  });

  final ObjectBoxAdminState state;
  final TextEditingController searchController;
  final ValueChanged<ObjectBoxAdminEntityDescriptor?> onEntityChanged;
  final ValueChanged<ObjectBoxAdminViewMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchSubmitted;
  final VoidCallback onSearchPressed;
  final VoidCallback onSortPressed;

  @override
  Widget build(BuildContext context) {
    final entity = state.selectedEntity;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 260,
          child: DropdownButtonFormField<ObjectBoxAdminEntityDescriptor>(
            key: const Key('objectbox-admin-entity-dropdown'),
            initialValue: entity,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Entity',
              border: OutlineInputBorder(),
            ),
            items: state.entities
                .map(
                  (descriptor) => DropdownMenuItem(
                    value: descriptor,
                    child: Text(descriptor.displayName),
                  ),
                )
                .toList(growable: false),
            onChanged: onEntityChanged,
          ),
        ),
        ToggleButtons(
          key: const Key('objectbox-admin-schema-data-toggle'),
          isSelected: [
            state.mode == ObjectBoxAdminViewMode.schema,
            state.mode == ObjectBoxAdminViewMode.data,
          ],
          onPressed: (index) {
            onModeChanged(
              index == 0
                  ? ObjectBoxAdminViewMode.schema
                  : ObjectBoxAdminViewMode.data,
            );
          },
          children: const [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Schema'),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('Data'),
            ),
          ],
        ),
        if (state.mode == ObjectBoxAdminViewMode.data)
          SizedBox(
            width: 360,
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: onSearchPressed,
                  icon: const Icon(Icons.search),
                ),
              ),
              onChanged: onSearchChanged,
              onSubmitted: (_) => onSearchSubmitted(),
            ),
          ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(padding: const EdgeInsets.all(16), child: Text(message)),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message, super.key});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchemaView extends StatelessWidget {
  const _SchemaView({required this.entity});

  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entity.fields.length + 1,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          return _SchemaHeader(entity: entity);
        }

        final field = entity.fields[index - 1];
        return ListTile(
          dense: true,
          title: Text(field.name),
          subtitle: Text(field.typeLabel),
          trailing: Text(
            [
              if (field.isPrimaryKey) 'PK',
              if (field.isPrimaryName) 'Name',
              if (field.nullable) 'Nullable',
            ].join(' · '),
          ),
        );
      },
    );
  }
}

class _SchemaHeader extends StatelessWidget {
  const _SchemaHeader({required this.entity});

  final ObjectBoxAdminEntityDescriptor entity;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${entity.displayName} schema',
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _DataGrid extends StatelessWidget {
  const _DataGrid({
    super.key,
    required this.entity,
    required this.rows,
    required this.sortAscending,
    required this.selectedRow,
    required this.horizontalController,
    required this.verticalController,
    required this.canLoadMore,
    required this.onLoadMore,
    required this.onSortPressed,
    required this.onRowTap,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final List<ObjectBoxAdminRow> rows;
  final bool sortAscending;
  final ObjectBoxAdminRow? selectedRow;
  final ScrollController horizontalController;
  final ScrollController verticalController;
  final bool canLoadMore;
  final VoidCallback onLoadMore;
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
        _DataHeaderRow(
          entity: entity,
          primaryField: primaryField,
          otherFields: otherFields,
          sortAscending: sortAscending,
          horizontalController: horizontalController,
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
                  onLoadMore();
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final row = rows[index];
                final isSelected =
                    selectedRow?.primaryKeyValue == row.primaryKeyValue;
                return _DataRowTile(
                  entity: entity,
                  row: row,
                  primaryField: primaryField,
                  otherFields: otherFields,
                  selected: isSelected,
                  horizontalController: horizontalController,
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

class _DataHeaderRow extends StatelessWidget {
  const _DataHeaderRow({
    required this.entity,
    required this.primaryField,
    required this.otherFields,
    required this.sortAscending,
    required this.horizontalController,
    required this.onSortPressed,
  });

  final ObjectBoxAdminEntityDescriptor entity;
  final ObjectBoxAdminFieldDescriptor primaryField;
  final List<ObjectBoxAdminFieldDescriptor> otherFields;
  final bool sortAscending;
  final ScrollController horizontalController;
  final VoidCallback onSortPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Cell(
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
                    (field) => _Cell(
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

class _DataRowTile extends StatelessWidget {
  const _DataRowTile({
    required this.entity,
    required this.row,
    required this.primaryField,
    required this.otherFields,
    required this.selected,
    required this.horizontalController,
    required this.onTap,
  });

  final ObjectBoxAdminEntityDescriptor entity;
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
            _Cell(
              width: 160,
              child: Text(
                objectBoxAdminPreviewValue(row.values[primaryField.name]),
                maxLines: null,
                softWrap: true,
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
                        (field) => _Cell(
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

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});

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

class _DetailsPane extends StatelessWidget {
  const _DetailsPane({
    required this.row,
    required this.entity,
    required this.onClose,
  });

  final ObjectBoxAdminRow? row;
  final ObjectBoxAdminEntityDescriptor entity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    row == null
                        ? 'Details'
                        : '${entity.displayName} #${objectBoxAdminFormatValue(row!.primaryKeyValue)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  key: const Key('objectbox-admin-details-close'),
                  onPressed: row == null ? null : onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(),
            if (row == null)
              const Expanded(
                child: Center(
                  child: Text('Select a row to inspect full values.'),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: entity.fields.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final field = entity.fields[index];
                    final selectedRow = row!;
                    return ListTile(
                      dense: true,
                      title: Text(field.name),
                      subtitle: SelectableText(
                        objectBoxAdminFormatValue(
                          selectedRow.values[field.name],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
