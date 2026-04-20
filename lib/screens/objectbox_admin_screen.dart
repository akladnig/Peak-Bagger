import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_controls.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_states.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
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
  final ScrollController _headerHorizontalController = ScrollController();
  final Map<String, ScrollController> _rowHorizontalControllers = {};
  double _horizontalOffset = 0;
  bool _syncingHorizontal = false;
  late final VoidCallback _routerListener;
  String? _lastRoutePath;

  @override
  void initState() {
    super.initState();
    _verticalController.addListener(_maybeLoadMore);
    _headerHorizontalController.addListener(
      () => _syncHorizontalScroll(_headerHorizontalController),
    );
    _lastRoutePath = _currentPath();
    _routerListener = _handleRouteChange;
    router.routerDelegate.addListener(_routerListener);
  }

  @override
  void dispose() {
    router.routerDelegate.removeListener(_routerListener);
    _verticalController
      ..removeListener(_maybeLoadMore)
      ..dispose();
    _headerHorizontalController.dispose();
    for (final controller in _rowHorizontalControllers.values) {
      controller.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _handleRouteChange() {
    _maybeRefreshOnVisibleEntry();
  }

  void _maybeRefreshOnVisibleEntry() {
    final currentPath = _currentPath();
    if (currentPath == null || currentPath == _lastRoutePath) {
      return;
    }

    _lastRoutePath = currentPath;
    if (currentPath == '/objectbox-admin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentPath() != '/objectbox-admin') {
          return;
        }
        ref.read(objectboxAdminProvider.notifier).refresh();
      });
    }
  }

  String? _currentPath() {
    try {
      return router.routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return null;
    }
  }

  ScrollController _rowHorizontalControllerFor(
    ObjectBoxAdminEntityDescriptor entity,
    ObjectBoxAdminRow row,
  ) {
    final key = '${entity.name}:${row.primaryKeyValue}';
    return _rowHorizontalControllers.putIfAbsent(key, () {
      final controller = ScrollController(
        initialScrollOffset: _horizontalOffset,
      );
      controller.addListener(() => _syncHorizontalScroll(controller));
      return controller;
    });
  }

  void _syncHorizontalScroll(ScrollController source) {
    if (_syncingHorizontal || !source.hasClients) {
      return;
    }

    final offset = source.offset;
    if ((offset - _horizontalOffset).abs() < 0.1) {
      return;
    }

    _horizontalOffset = offset;
    _syncingHorizontal = true;
    try {
      void syncController(ScrollController controller) {
        if (!controller.hasClients || identical(controller, source)) {
          return;
        }

        final targetOffset = offset.clamp(
          0.0,
          controller.position.maxScrollExtent,
        );
        if ((controller.offset - targetOffset).abs() > 0.1) {
          controller.jumpTo(targetOffset);
        }
      }

      syncController(_headerHorizontalController);
      for (final controller in _rowHorizontalControllers.values) {
        syncController(controller);
      }
    } finally {
      _syncingHorizontal = false;
    }
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

  Future<void> _exportSelectedGpxFile(ObjectBoxAdminRow row) async {
    try {
      final path = await ref
          .read(objectboxAdminRepositoryProvider)
          .exportGpxFile(row);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exported to $path')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    _maybeRefreshOnVisibleEntry();

    final state = ref.watch(objectboxAdminProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);

    if (_searchController.text != state.searchQuery) {
      _searchController.text = state.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ObjectBoxAdminControls(
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
              onExportPressed: state.selectedRow == null
                  ? null
                  : () => _exportSelectedGpxFile(state.selectedRow!),
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
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No selectable entities',
        message: 'The store has no ObjectBox entities to inspect.',
      );
    }

    if (state.error != null) {
      return ObjectBoxAdminErrorState(
        key: const Key('objectbox-admin-error-state'),
        message: state.error!,
      );
    }

    if (state.isLoading) {
      return const ObjectBoxAdminLoadingState();
    }

    final entity = state.selectedEntity;
    if (entity == null) {
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No entity selected',
        message: 'Choose an entity to inspect its schema or rows.',
      );
    }

    if (state.mode == ObjectBoxAdminViewMode.schema) {
      return ObjectBoxAdminSchemaView(entity: entity);
    }

    if (state.noMatches) {
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No matches',
        message: 'The current search returned no rows.',
      );
    }

    if (state.rows.isEmpty) {
      return ObjectBoxAdminEmptyState(
        key: const Key('objectbox-admin-empty-state'),
        title: 'No rows',
        message: 'This entity has no stored rows yet.',
      );
    }

    return Row(
      children: [
        Expanded(
          child: ObjectBoxAdminDataGrid(
            key: const Key('objectbox-admin-table'),
            entity: entity,
            rows: state.visibleRows,
            sortAscending: state.sortAscending,
            selectedRow: state.selectedRow,
            headerHorizontalController: _headerHorizontalController,
            rowHorizontalControllerFor: (row) =>
                _rowHorizontalControllerFor(entity, row),
            verticalController: _verticalController,
            canLoadMore: state.visibleRowCount < state.rows.length,
            onSortPressed: notifier.toggleSort,
            onRowTap: notifier.selectRow,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: ObjectBoxAdminDetailsPane(
            row: state.selectedRow,
            entity: entity,
            onClose: notifier.clearSelection,
          ),
        ),
      ],
    );
  }
}
