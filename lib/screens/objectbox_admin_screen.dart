import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_controls.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_states.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/widgets/dialog_helpers.dart';

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
  bool _isCreatingPeak = false;
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

  Future<String?> _savePeak(Peak peak) async {
    final repository = ref.read(peakRepositoryProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);

    final conflict = repository.findByOsmId(peak.osmId);
    if (conflict != null && conflict.id != peak.id) {
      if (!mounted) {
        return 'This osmId is already tied to ${conflict.name}, so cannot be over written.';
      }

      await showSingleActionDialog(
        context: context,
        title: 'Error: cannot change osmId',
        content: Text(
          'This osmId is already tied to ${conflict.name}, so cannot be over written.',
        ),
        closeKey: 'objectbox-admin-peak-osm-id-conflict-close',
      );
      return 'This osmId is already tied to ${conflict.name}, so cannot be over written.';
    }

    try {
      final result = await repository.saveDetailed(peak);
      if (!mounted) {
        return null;
      }

      await notifier.refresh(keepSelectedRowPrimaryKey: result.peak.id);
      if (!mounted) {
        return null;
      }

      await ref.read(mapProvider.notifier).reloadPeakMarkers();
      if (!mounted) {
        return null;
      }

      if (_isCreatingPeak) {
        setState(() {
          _isCreatingPeak = false;
        });
      }

      await showSingleActionDialog(
        context: context,
        title: 'Update Successful',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${result.peak.name} updated.'),
            if (result.warningMessage != null) ...[
              const SizedBox(height: 8),
              Text(result.warningMessage!),
            ],
          ],
        ),
        closeKey: 'objectbox-admin-peak-update-success-close',
      );
      return null;
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'Peak save failed for ${peak.name}',
      );
      if (!mounted) {
        return 'Failed to save Peak: $error';
      }

      await showSingleActionDialog(
        context: context,
        title: 'Save Failed',
        content: Text('Failed to save Peak: $error'),
        closeKey: 'objectbox-admin-peak-save-error-close',
      );
      return 'Failed to save Peak: $error';
    }
  }

  void _viewPeakOnMainMap(Peak peak) {
    final location = LatLng(peak.latitude, peak.longitude);
    final mapNotifier = ref.read(mapProvider.notifier);
    mapNotifier.centerOnLocation(location);
    mapNotifier.updatePosition(location, MapConstants.defaultZoom);
    router.go('/map');
  }

  Future<void> _deletePeak(ObjectBoxAdminRow row) async {
    final repository = ref.read(peakRepositoryProvider);
    final guard = ref.read(peakDeleteGuardProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);
    final peak =
        repository.findById(row.primaryKeyValue as int) ?? peakFromAdminRow(row);
    final confirmed = await showDangerConfirmDialog(
      context: context,
      title: 'Delete Peak?',
      message:
          'This will permanently delete the ${peak.name}. Do you want to proceed?',
      cancelKey: 'cancel-delete',
      cancelLabel: 'Cancel',
      confirmKey: 'confirm-delete',
      confirmLabel: 'Delete',
    );

    if (confirmed != true) {
      return;
    }

    final blockers = guard.check(peak);
    if (!blockers.canDelete) {
      if (!mounted) {
        return;
      }

      await showSingleActionDialog(
        context: context,
        title: 'Delete Blocked',
        content: Text(_describeDeleteBlockers(blockers.blockers)),
        closeKey: 'objectbox-admin-peak-delete-blocked-close',
      );
      return;
    }

    final currentState = ref.read(objectboxAdminProvider);
    final keepSelectedRowPrimaryKey =
        currentState.selectedRow?.primaryKeyValue == row.primaryKeyValue
        ? null
        : currentState.selectedRow?.primaryKeyValue;

    await repository.delete(peak.id);
    if (!mounted) {
      return;
    }

    await notifier.refresh(
      keepSelectedRowPrimaryKey: keepSelectedRowPrimaryKey,
    );
  }

  void _startCreatingPeak() {
    final notifier = ref.read(objectboxAdminProvider.notifier);
    setState(() {
      _isCreatingPeak = true;
    });
    notifier.clearSelection();
  }

  String _describeDeleteBlockers(List<PeakDeleteBlocker> blockers) {
    final fragments = blockers
        .map((blocker) {
          final dependency = switch (blocker.dependencyType) {
            PeakDeleteDependencyType.gpxTrack => 'GpxTrack',
            PeakDeleteDependencyType.peakList => 'PeakList',
            PeakDeleteDependencyType.peaksBagged => 'PeaksBagged',
          };
          return '$dependency ${blocker.displayName}';
        })
        .toList(growable: false);

    if (fragments.length == 1) {
      return 'Delete blocked because it is still referenced by ${fragments.single}.';
    }

    final body = fragments.length == 2
        ? '${fragments[0]} and ${fragments[1]}'
        : '${fragments.take(fragments.length - 1).join(', ')}, and ${fragments.last}';
    return 'Delete blocked because it is still referenced by $body.';
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
                if (_isCreatingPeak) {
                  setState(() {
                    _isCreatingPeak = false;
                  });
                }
                notifier.selectEntity(entity);
              },
              onModeChanged: (mode) {
                if (_isCreatingPeak) {
                  setState(() {
                    _isCreatingPeak = false;
                  });
                }
                notifier.setMode(mode);
              },
              onSearchChanged: notifier.updateSearchQuery,
              onSearchSubmitted: notifier.runSearch,
              onSearchPressed: notifier.runSearch,
              onAddPeakPressed: _startCreatingPeak,
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

    final isPeakCreateMode =
        entity.name == 'Peak' &&
        state.mode == ObjectBoxAdminViewMode.data &&
        _isCreatingPeak;

    if (isPeakCreateMode) {
      final createOsmId = ref.read(peakRepositoryProvider).nextSyntheticOsmId();

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
              onRowTap: (row) {
                setState(() {
                  _isCreatingPeak = false;
                });
                notifier.selectRow(row);
              },
              onDeletePressed: null,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: ObjectBoxAdminDetailsPane(
              row: null,
              entity: entity,
              isCreatingPeak: true,
              createOsmId: createOsmId,
              onClose: () {
                setState(() {
                  _isCreatingPeak = false;
                });
                notifier.clearSelection();
              },
              onViewPeakOnMap: _viewPeakOnMainMap,
              onPeakSubmit: _savePeak,
            ),
          ),
        ],
      );
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
            onDeletePressed: entity.name == 'Peak' ? _deletePeak : null,
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: ObjectBoxAdminDetailsPane(
            row: state.selectedRow,
            entity: entity,
            isCreatingPeak: false,
            createOsmId: 0,
            onClose: notifier.clearSelection,
            onViewPeakOnMap: _viewPeakOnMainMap,
            onPeakSubmit: _savePeak,
          ),
        ),
      ],
    );
  }
}
