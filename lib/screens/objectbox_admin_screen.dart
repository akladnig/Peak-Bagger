import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/search_shortcuts.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_save_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_delete_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/providers/contact_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_controls.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_details.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_states.dart';
import 'package:peak_bagger/screens/objectbox_admin_screen_table.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_list_admin_editor.dart';
import 'package:peak_bagger/services/route_admin_editor.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/models/contact.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/widgets/dialog_helpers.dart';
import 'package:peak_bagger/widgets/objectbox_admin_save_scope.dart';

class ObjectBoxAdminScreen extends ConsumerStatefulWidget {
  const ObjectBoxAdminScreen({super.key});

  @override
  ConsumerState<ObjectBoxAdminScreen> createState() =>
      _ObjectBoxAdminScreenState();
}

class _ObjectBoxAdminScreenState extends ConsumerState<ObjectBoxAdminScreen>
    implements PopEntry<Object?> {
  // Unlike a build-time PopScope flag, this entry changes synchronously when a
  // Save starts, so an immediate system back cannot pop a parent shell page.
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
  ModalRoute<Object?>? _popRoute;
  late final ProviderSubscription<bool> _saveSubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode(debugLabel: 'Admin Search');
  final ScrollController _verticalController = ScrollController();
  final ScrollController _headerHorizontalController = ScrollController();
  final Map<String, ScrollController> _rowHorizontalControllers = {};
  double _horizontalOffset = 0;
  bool _syncingHorizontal = false;
  bool _isCreatingPeak = false;
  bool _isCreatingContact = false;
  late final VoidCallback _routerListener;
  String? _lastRoutePath;

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleSearchShortcut);
    _saveSubscription = ref.listenManual(objectboxAdminSaveProvider, (
      _,
      saving,
    ) {
      canPopNotifier.value = !saving;
    }, fireImmediately: true);
    _verticalController.addListener(_maybeLoadMore);
    _headerHorizontalController.addListener(
      () => _syncHorizontalScroll(_headerHorizontalController),
    );
    _lastRoutePath = peekObjectBoxAdminPendingPeakId() == null
        ? _currentPath()
        : '/objectbox-admin';
    _routerListener = _handleRouteChange;
    router.routerDelegate.addListener(_routerListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_popRoute == route) return;
    _popRoute?.unregisterPopEntry(this);
    _popRoute = route;
    _popRoute?.registerPopEntry(this);
  }

  @override
  void onPopInvoked(bool didPop) {}

  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleSearchShortcut);
    _searchFocus.dispose();
    _saveSubscription.close();
    _popRoute?.unregisterPopEntry(this);
    canPopNotifier.dispose();
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

  bool _handleSearchShortcut(KeyEvent event) {
    if (!isFindShortcut(event)) return false;
    if (!mounted || _savePending) return false;
    final state = ref.read(objectboxAdminProvider);
    if (state.mode != ObjectBoxAdminViewMode.data ||
        state.selectedEntity == null ||
        state.schemaError != null ||
        !_searchFocus.canRequestFocus ||
        !isSearchSurfaceActive(context)) {
      return false;
    }
    final localRouter = GoRouter.maybeOf(context);
    if (localRouter != null &&
        localRouter.state.uri.path != '/objectbox-admin') {
      return false;
    }
    _searchFocus.requestFocus();
    _searchController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _searchController.text.length,
    );
    return true;
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
    if (currentPath != '/objectbox-admin') {
      // The shell retains this screen. Departure still abandons its draft now,
      // rather than merely hiding it until the next entry refresh.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _currentPath() == '/objectbox-admin') return;
        setState(() {
          _isCreatingPeak = false;
          _isCreatingContact = false;
        });
        ref.read(objectboxAdminProvider.notifier).clearSelection();
      });
    }
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
      return router.state.uri.path;
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
    if (_savePending) return;
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

  Future<String?> _savePeak(Peak peak) =>
      _runSave(() => _performSavePeak(peak));

  Future<String?> _saveNaturalFeature(NaturalFeature feature) =>
      _runSave(() => _performSaveNaturalFeature(feature));

  Future<String?> _saveContact(Contact contact) =>
      _runSave(() => _performSaveContact(contact));

  Future<String?> _saveRoute(RouteAdminFormState form) =>
      _runSave(() => _performSaveRoute(form));

  Future<String?> _savePeakList(PeakListAdminFormState form) =>
      _runSave(() => _performSavePeakList(form));

  Future<String?> _performSavePeak(Peak peak) async {
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
      ref.read(peakRevisionProvider.notifier).increment();
      if (!mounted) {
        return null;
      }

      await notifier.refreshAfterSave(
        keepSelectedRowPrimaryKey: result.peak.id,
      );
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

  bool get _naturalFeatureMutationsLocked {
    return ref.read(backgroundJobsProvider).runningJob?.kind ==
        BackgroundJobKind.refreshNaturalFeatures;
  }

  Future<String?> _performSaveNaturalFeature(NaturalFeature feature) async {
    if (_naturalFeatureMutationsLocked) {
      return 'Natural features cannot be changed while refresh is running.';
    }
    try {
      final saved = ref.read(naturalFeatureRepositoryProvider).save(feature);
      await ref
          .read(objectboxAdminProvider.notifier)
          .refreshAfterSave(keepSelectedRowPrimaryKey: saved.id);
      if (!mounted) {
        return null;
      }
      await showSingleActionDialog(
        context: context,
        title: 'Update Successful',
        content: Text('${saved.name} updated.'),
        closeKey: 'objectbox-admin-natural-feature-update-success-close',
      );
      return null;
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'Natural Feature save failed for ${feature.name}',
      );
      if (!mounted) {
        return 'Failed to save Natural Feature: $error';
      }
      await showSingleActionDialog(
        context: context,
        title: 'Save Failed',
        content: Text('Failed to save Natural Feature: $error'),
        closeKey: 'objectbox-admin-natural-feature-save-error-close',
      );
      return 'Failed to save Natural Feature: $error';
    }
  }

  Future<String?> _performSaveContact(Contact contact) async {
    try {
      final saved = ref.read(contactRepositoryProvider).save(contact);
      await ref
          .read(objectboxAdminProvider.notifier)
          .refreshAfterSave(keepSelectedRowPrimaryKey: saved.id);
      if (!mounted) {
        return null;
      }
      setState(() => _isCreatingContact = false);
      return null;
    } catch (error, stackTrace) {
      logObjectBoxAdminError(error, stackTrace, 'Contact save failed');
      return 'Failed to save Contact: $error';
    }
  }

  Future<void> _deleteContact(ObjectBoxAdminRow row) async {
    await _coordinateDelete(
      row,
      'Contact',
      () async {
        final repository = ref.read(contactRepositoryProvider);
        final contact = repository.findById(row.primaryKeyValue as int);
        if (contact == null) {
          return false;
        }
        final displayName = contactDisplayName(contact);
        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Delete Contact?',
          message:
              'This will permanently delete the ${displayName.isEmpty ? 'Contact' : displayName}. Do you want to proceed?',
          cancelKey: 'cancel-delete',
          cancelLabel: 'Cancel',
          confirmKey: 'confirm-delete',
          confirmLabel: 'Delete',
        );
        return confirmed == true;
      },
      () async {
        if (!ref
            .read(contactRepositoryProvider)
            .delete(row.primaryKeyValue as int)) {
          throw StateError('Contact was not removed');
        }
      },
    );
  }

  Future<void> _deleteNaturalFeature(ObjectBoxAdminRow row) async {
    if (_naturalFeatureMutationsLocked) return;
    await _coordinateDelete(
      row,
      'Natural Feature',
      () async {
        final repository = ref.read(naturalFeatureRepositoryProvider);
        final feature = repository.findById(row.primaryKeyValue as int);
        if (feature == null) {
          return false;
        }
        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Delete Natural Feature?',
          message:
              'This will permanently delete the ${feature.name}. Do you want to proceed?',
          cancelKey: 'cancel-delete',
          cancelLabel: 'Cancel',
          confirmKey: 'confirm-delete',
          confirmLabel: 'Delete',
        );
        return confirmed == true && !_naturalFeatureMutationsLocked;
      },
      () async {
        if (!ref
            .read(naturalFeatureRepositoryProvider)
            .delete(row.primaryKeyValue as int)) {
          throw StateError('Natural Feature was not removed');
        }
      },
    );
  }

  void _viewGpxTrackOnMainMap(ObjectBoxAdminRow row) {
    if (_savePending) return;
    final trackId = row.primaryKeyValue as int;
    final repository = ref.read(gpxTrackRepositoryProvider);
    final track = repository.findById(trackId);
    if (track == null) {
      return;
    }

    ref.read(mapProvider.notifier).showTrack(trackId);
    router.go('/map');
  }

  void _viewRouteOnMainMap(app_route.Route route) {
    if (_savePending) return;
    final repository = ref.read(routeRepositoryProvider);
    if (repository.findById(route.id) == null) {
      return;
    }

    ref.read(mapProvider.notifier).showRoute(route.id);
    router.go('/map');
  }

  void _viewPeakOnMainMap(Peak peak) {
    if (_savePending) return;
    final location = LatLng(peak.latitude, peak.longitude);
    final mapNotifier = ref.read(mapProvider.notifier);
    mapNotifier.requestCameraMove(
      center: location,
      zoom: MapConstants.defaultZoom,
    );
    router.go('/map');
  }

  void _viewNaturalFeatureOnMainMap(NaturalFeature naturalFeature) {
    if (_savePending) return;
    final location = LatLng(naturalFeature.latitude, naturalFeature.longitude);
    final mapNotifier = ref.read(mapProvider.notifier);
    mapNotifier.requestCameraMove(
      center: location,
      zoom: MapConstants.defaultZoom,
    );
    router.go('/map');
  }

  Future<void> _deletePeak(ObjectBoxAdminRow row) async {
    await _coordinateDelete(
      row,
      'Peak',
      () async {
        final repository = ref.read(peakRepositoryProvider);
        final guard = ref.read(peakDeleteGuardProvider);
        final peak =
            repository.findById(row.primaryKeyValue as int) ??
            peakFromAdminRow(row);
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

        if (confirmed != true || !mounted) {
          return false;
        }

        final blockers = guard.check(peak);
        if (!blockers.canDelete) {
          if (!mounted) {
            return false;
          }

          await showSingleActionDialog(
            context: context,
            title: 'Delete Blocked',
            content: Text(_describeDeleteBlockers(blockers.blockers)),
            closeKey: 'objectbox-admin-peak-delete-blocked-close',
          );
          return false;
        }

        return true;
      },
      () async {
        await ref
            .read(peakRepositoryProvider)
            .delete(row.primaryKeyValue as int);
        ref.read(peakRevisionProvider.notifier).increment();
      },
    );
  }

  Future<void> _deleteGpxTrack(ObjectBoxAdminRow row) async {
    if (!mounted || _savePending) return;
    final mapNotifier = ref.read(mapProvider.notifier);
    await _coordinateDelete(
      row,
      'Track',
      () async {
        final repository = ref.read(gpxTrackRepositoryProvider);
        final trackId = row.primaryKeyValue as int;
        final trackName =
            repository.findById(trackId)?.trackName ??
            (row.values['trackName']?.toString().trim().isNotEmpty == true
                ? row.values['trackName']!.toString().trim()
                : 'Track');

        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Delete Track?',
          message:
              'This will permanently delete the $trackName. Do you want to proceed?',
          cancelKey: 'cancel-delete',
          cancelLabel: 'Cancel',
          confirmKey: 'confirm-delete',
          confirmLabel: 'Delete',
        );

        return confirmed == true;
      },
      () async {
        if (!ref
            .read(gpxTrackRepositoryProvider)
            .deleteTrack(row.primaryKeyValue as int)) {
          throw StateError('Track was not removed');
        }
      },
      followUp: () => mapNotifier.deleteTrack(row.primaryKeyValue as int),
    );
  }

  Future<String?> _performSaveRoute(RouteAdminFormState form) async {
    final repository = ref.read(routeRepositoryProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);
    final currentState = ref.read(objectboxAdminProvider);
    final selectedRow = currentState.selectedRow;
    if (selectedRow == null) {
      return 'Failed to save Route: no selected row';
    }

    final routeId = selectedRow.primaryKeyValue as int;
    final existing = repository.findById(routeId);
    if (existing == null) {
      return 'Failed to save Route: route not found';
    }

    final validation = RouteAdminEditor.validateAndBuild(
      source: existing,
      form: form,
    );
    if (!validation.isValid || validation.route == null) {
      return 'Failed to save Route: invalid form';
    }

    try {
      final savedRoute = repository.saveRoute(validation.route!);
      ref.read(routeRevisionProvider.notifier).increment();
      if (!mounted) {
        return null;
      }

      await notifier.refreshAfterSave(keepSelectedRowPrimaryKey: savedRoute.id);
      if (!mounted) {
        return null;
      }

      await showSingleActionDialog(
        context: context,
        title: 'Update Successful',
        content: Text('${savedRoute.name} updated.'),
        closeKey: 'objectbox-admin-route-update-success-close',
      );
      return null;
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'Route save failed for ${existing.name}',
      );
      if (!mounted) {
        return 'Failed to save Route: $error';
      }

      await showSingleActionDialog(
        context: context,
        title: 'Save Failed',
        content: Text('Failed to save Route: $error'),
        closeKey: 'objectbox-admin-route-save-error-close',
      );
      return 'Failed to save Route: $error';
    }
  }

  Future<String?> _performSavePeakList(PeakListAdminFormState form) async {
    final repository = ref.read(peakListRepositoryProvider);
    final notifier = ref.read(objectboxAdminProvider.notifier);
    final currentState = ref.read(objectboxAdminProvider);
    final selectedRow = currentState.selectedRow;
    if (selectedRow == null) {
      return 'Failed to save PeakList: no selected row';
    }

    final peakListId = selectedRow.primaryKeyValue as int;
    final existing = repository.findById(peakListId);
    if (existing == null) {
      return 'Failed to save PeakList: peak list not found';
    }

    final validation = PeakListAdminEditor.validateAndBuild(
      source: existing,
      form: form,
    );
    if (!validation.isValid || validation.peakList == null) {
      return 'Failed to save PeakList: invalid form';
    }

    try {
      final savedPeakList = await repository.save(
        validation.peakList!,
        recomputeDerivedFields: true,
      );
      ref.read(peakListRevisionProvider.notifier).increment();
      await ref.read(mapProvider.notifier).reloadPeakMarkers();
      if (!mounted) {
        return null;
      }

      await notifier.refreshAfterSave(
        keepSelectedRowPrimaryKey: savedPeakList.peakListId,
      );
      if (!mounted) {
        return null;
      }

      await showSingleActionDialog(
        context: context,
        title: 'Update Successful',
        content: Text('${savedPeakList.name} updated.'),
        closeKey: 'objectbox-admin-peak-list-update-success-close',
      );
      return null;
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'PeakList save failed for ${existing.name}',
      );
      if (!mounted) {
        return 'Failed to save PeakList: $error';
      }

      await showSingleActionDialog(
        context: context,
        title: 'Save Failed',
        content: Text('Failed to save PeakList: $error'),
        closeKey: 'objectbox-admin-peak-list-save-error-close',
      );
      return 'Failed to save PeakList: $error';
    }
  }

  Future<void> _deleteRoute(ObjectBoxAdminRow row) async {
    await _coordinateDelete(
      row,
      'Route',
      () async {
        final repository = ref.read(routeRepositoryProvider);
        final routeId = row.primaryKeyValue as int;
        final routeName =
            repository.findById(routeId)?.name ??
            (row.values['name']?.toString().trim().isNotEmpty == true
                ? row.values['name']!.toString().trim()
                : 'Route');

        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Delete Route?',
          message:
              'This will permanently delete the $routeName. Do you want to proceed?',
          cancelKey: 'cancel-delete',
          cancelLabel: 'Cancel',
          confirmKey: 'confirm-delete',
          confirmLabel: 'Delete',
        );

        return confirmed == true;
      },
      () async {
        if (!ref
            .read(routeRepositoryProvider)
            .deleteRoute(row.primaryKeyValue as int)) {
          throw StateError('Route was not removed');
        }
        ref.read(routeRevisionProvider.notifier).increment();
      },
    );
  }

  Future<void> _deleteWaypoint(ObjectBoxAdminRow row) async {
    await _coordinateDelete(
      row,
      'Waypoint',
      () async {
        final waypointName =
            row.values['name']?.toString().trim().isNotEmpty == true
            ? row.values['name']!.toString().trim()
            : 'Waypoint';
        final confirmed = await showDangerConfirmDialog(
          context: context,
          title: 'Delete Waypoint?',
          message:
              'This will permanently delete the $waypointName. Do you want to proceed?',
          cancelKey: 'cancel-delete',
          cancelLabel: 'Cancel',
          confirmKey: 'confirm-delete',
          confirmLabel: 'Delete',
        );

        return confirmed == true;
      },
      () async {
        if (!await ref
            .read(objectboxAdminRepositoryProvider)
            .deleteWaypoint(row.primaryKeyValue as int)) {
          throw StateError('Waypoint was not removed');
        }
      },
    );
  }

  Future<void> _coordinateDelete(
    ObjectBoxAdminRow row,
    String label,
    Future<bool> Function() confirm,
    Future<void> Function() remove, {
    Future<void> Function()? followUp,
  }) async {
    if (!mounted || _savePending) return;
    final notifier = ref.read(objectboxAdminProvider.notifier);
    await ref
        .read(objectboxAdminDeleteProvider.notifier)
        .run(
          label: label,
          confirm: confirm,
          remove: remove,
          didRemove: () => notifier.didDeleteRecord(row.primaryKeyValue!),
          followUp: followUp,
          refresh: notifier.refreshAfterDelete,
          onFailure: (_, _) async {
            if (!mounted) return;
            await showSingleActionDialog(
              context: context,
              title: 'Delete Failed',
              content: Text(
                'Unable to delete $label. Your input has been retained. Close this message and try again.',
              ),
              closeKey: 'objectbox-admin-delete-error-close',
            );
          },
        );
  }

  void _startCreatingPeak() {
    if (_savePending) return;
    final notifier = ref.read(objectboxAdminProvider.notifier);
    setState(() {
      _isCreatingPeak = true;
    });
    notifier.clearSelection();
  }

  void _startCreatingContact() {
    if (_savePending) return;
    setState(() => _isCreatingContact = true);
    ref.read(objectboxAdminProvider.notifier).clearSelection();
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
    final naturalFeatureMutationsLocked =
        ref.watch(backgroundJobsProvider).runningJob?.kind ==
        BackgroundJobKind.refreshNaturalFeatures;
    final notifier = ref.read(objectboxAdminProvider.notifier);
    final savePending = ref.watch(objectboxAdminSaveProvider);
    final recoveries = ref.watch(objectboxAdminDeleteProvider);

    if (_searchController.text != state.searchQuery) {
      _searchController.text = state.searchQuery;
      _searchController.selection = TextSelection.collapsed(
        offset: _searchController.text.length,
      );
    }

    return ObjectBoxAdminSaveScope(
      pending: savePending,
      isPending: () => _savePending,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ObjectBoxAdminControls(
                state: state,
                searchController: _searchController,
                searchFocusNode: _searchFocus,
                onEntityChanged: (entity) {
                  if (_savePending || entity == null) {
                    return;
                  }
                  _searchController.clear();
                  if (_isCreatingPeak) {
                    setState(() {
                      _isCreatingPeak = false;
                    });
                  }
                  if (_isCreatingContact) {
                    setState(() => _isCreatingContact = false);
                  }
                  notifier.selectEntity(entity);
                },
                onModeChanged: (mode) {
                  if (_savePending) return;
                  if (_isCreatingPeak) {
                    setState(() {
                      _isCreatingPeak = false;
                    });
                  }
                  if (_isCreatingContact) {
                    setState(() => _isCreatingContact = false);
                  }
                  notifier.setMode(mode);
                },
                onSearchChanged: (query) {
                  if (_savePending) {
                    _searchController.text = ref
                        .read(objectboxAdminProvider)
                        .searchQuery;
                    return;
                  }
                  notifier.updateSearchQuery(query);
                },
                onSearchSubmitted: notifier.runSearch,
                onAddPeakPressed: _startCreatingPeak,
                onAddContactPressed: _startCreatingContact,
                onSortPressed: notifier.toggleSort,
                onExportPressed: state.selectedRow == null
                    ? null
                    : () => _exportSelectedGpxFile(state.selectedRow!),
                locked: savePending,
              ),
              const SizedBox(height: 16),
              if (savePending)
                const Text(
                  'Admin operation in progress…',
                  key: Key('objectbox-admin-operation-progress'),
                ),
              if (recoveries.isNotEmpty)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height / 4,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final recovery in recoveries)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${recovery.label} deleted. ${recovery.followUp != null ? 'Synchronisation' : 'Refresh'} is incomplete. Retry to finish; the record will not be deleted again.',
                                ),
                              ),
                              const SizedBox(width: 12),
                              FilledButton(
                                key: const Key('objectbox-admin-delete-retry'),
                                onPressed: savePending
                                    ? null
                                    : () => ref
                                          .read(
                                            objectboxAdminDeleteProvider
                                                .notifier,
                                          )
                                          .retry(recovery),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 160),
                  child: _buildBody(
                    context,
                    state,
                    notifier,
                    naturalFeatureMutationsLocked,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _savePending => ref.read(objectboxAdminSaveProvider);

  Future<String?> _runSave(Future<String?> Function() action) =>
      ref.read(objectboxAdminSaveProvider.notifier).run(action);

  Widget _buildBody(
    BuildContext context,
    ObjectBoxAdminState state,
    ObjectBoxAdminNotifier notifier,
    bool naturalFeatureMutationsLocked,
  ) {
    if (state.schemaError != null && state.selectedRow == null) {
      return ObjectBoxAdminErrorState(
        key: const Key('objectbox-admin-schema-error-state'),
        message: state.schemaError!,
        onRetry: notifier.refresh,
      );
    }
    if (state.entities.isEmpty && state.selectedRow == null) {
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No selectable entities',
        message: 'The store has no ObjectBox entities to inspect.',
      );
    }

    final entity = state.selectedEntity;
    if (state.mode == ObjectBoxAdminViewMode.schema && entity != null) {
      return ObjectBoxAdminSchemaView(entity: entity);
    }

    if (state.error != null &&
        state.selectedRow == null &&
        !_isCreatingPeak &&
        !_isCreatingContact) {
      return ObjectBoxAdminErrorState(
        key: const Key('objectbox-admin-error-state'),
        message: state.error!,
        onRetry: notifier.refresh,
      );
    }

    if (state.isLoading &&
        state.selectedRow == null &&
        !_isCreatingPeak &&
        !_isCreatingContact) {
      return const ObjectBoxAdminLoadingState();
    }

    if (entity == null) {
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No entity selected',
        message: 'Choose an entity to inspect its schema or rows.',
      );
    }

    final isPeakCreateMode =
        entity.name == 'Peak' &&
        state.mode == ObjectBoxAdminViewMode.data &&
        _isCreatingPeak;

    final isContactCreateMode =
        entity.name == 'Contact' &&
        state.mode == ObjectBoxAdminViewMode.data &&
        _isCreatingContact;

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
              enabled: !_savePending,
              onSortPressed: notifier.toggleSort,
              onRowTap: (row) {
                if (_savePending) return;
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
              peakList: null,
              route: null,
              createOsmId: createOsmId,
              onClose: () {
                if (_savePending) return;
                setState(() {
                  _isCreatingPeak = false;
                });
                notifier.clearSelection();
              },
              onViewPeakOnMap: _viewPeakOnMainMap,
              onViewNaturalFeatureOnMap: _viewNaturalFeatureOnMainMap,
              onViewGpxTrackOnMap: _viewGpxTrackOnMainMap,
              onViewRouteOnMap: _viewRouteOnMainMap,
              onPeakSubmit: _savePeak,
              onPeakListSubmit: _savePeakList,
              onRouteSubmit: _saveRoute,
              naturalFeature: null,
              isNaturalFeatureMutationLocked: naturalFeatureMutationsLocked,
              onNaturalFeatureSubmit: _saveNaturalFeature,
              contact: null,
              isCreatingContact: false,
              onContactSubmit: _saveContact,
            ),
          ),
        ],
      );
    }

    if (isContactCreateMode) {
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
              enabled: !_savePending,
              onSortPressed: notifier.toggleSort,
              onRowTap: (row) {
                if (_savePending) return;
                setState(() => _isCreatingContact = false);
                notifier.selectRow(row);
              },
              onDeletePressed: _deleteContact,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 320,
            child: ObjectBoxAdminDetailsPane(
              row: null,
              entity: entity,
              peakList: null,
              route: null,
              naturalFeature: null,
              contact: null,
              isCreatingPeak: false,
              isCreatingContact: true,
              isNaturalFeatureMutationLocked: false,
              createOsmId: 0,
              onClose: () {
                if (_savePending) return;
                setState(() => _isCreatingContact = false);
                notifier.clearSelection();
              },
              onViewPeakOnMap: _viewPeakOnMainMap,
              onViewNaturalFeatureOnMap: _viewNaturalFeatureOnMainMap,
              onViewGpxTrackOnMap: _viewGpxTrackOnMainMap,
              onViewRouteOnMap: _viewRouteOnMainMap,
              onPeakSubmit: _savePeak,
              onPeakListSubmit: _savePeakList,
              onRouteSubmit: _saveRoute,
              onNaturalFeatureSubmit: _saveNaturalFeature,
              onContactSubmit: _saveContact,
            ),
          ),
        ],
      );
    }

    if (state.noMatches && state.selectedRow == null) {
      return const ObjectBoxAdminEmptyState(
        key: Key('objectbox-admin-empty-state'),
        title: 'No matches',
        message: 'The current search returned no rows.',
      );
    }

    if (state.rows.isEmpty && state.selectedRow == null) {
      return ObjectBoxAdminEmptyState(
        key: const Key('objectbox-admin-empty-state'),
        title: 'No rows',
        message: 'This entity has no stored rows yet.',
      );
    }

    return Row(
      children: [
        Expanded(
          child: state.error != null || state.schemaError != null
              ? ObjectBoxAdminErrorState(
                  message: state.schemaError ?? state.error!,
                  onRetry: notifier.refresh,
                )
              : state.noMatches
              ? const ObjectBoxAdminEmptyState(
                  title: 'No matches',
                  message: 'The current search returned no rows.',
                )
              : state.rows.isEmpty
              ? const ObjectBoxAdminEmptyState(
                  title: 'No rows',
                  message: 'This entity has no stored rows yet.',
                )
              : ObjectBoxAdminDataGrid(
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
                  enabled: !_savePending,
                  onSortPressed: notifier.toggleSort,
                  onRowTap: notifier.selectRow,
                  onDeletePressed: switch (entity.name) {
                    'Peak' => _deletePeak,
                    'NaturalFeature' => _deleteNaturalFeature,
                    'Contact' => _deleteContact,
                    'GpxTrack' => _deleteGpxTrack,
                    'Route' => _deleteRoute,
                    'Waypoints' => _deleteWaypoint,
                    _ => null,
                  },
                  deleteEnabled:
                      !_savePending &&
                      (!naturalFeatureMutationsLocked ||
                          entity.name != 'NaturalFeature'),
                ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 320,
          child: ObjectBoxAdminDetailsPane(
            row: state.selectedRow,
            entity: entity,
            peakList: entity.name == 'PeakList' && state.selectedRow != null
                ? ref
                      .read(peakListRepositoryProvider)
                      .findById(state.selectedRow!.primaryKeyValue as int)
                : null,
            route: entity.name == 'Route' && state.selectedRow != null
                ? ref
                      .read(routeRepositoryProvider)
                      .findById(state.selectedRow!.primaryKeyValue as int)
                : null,
            naturalFeature:
                entity.name == 'NaturalFeature' && state.selectedRow != null
                ? ref
                      .read(naturalFeatureRepositoryProvider)
                      .findById(state.selectedRow!.primaryKeyValue as int)
                : null,
            contact: entity.name == 'Contact' && state.selectedRow != null
                ? ref
                      .read(contactRepositoryProvider)
                      .findById(state.selectedRow!.primaryKeyValue as int)
                : null,
            isCreatingPeak: false,
            isCreatingContact: false,
            isNaturalFeatureMutationLocked: naturalFeatureMutationsLocked,
            createOsmId: 0,
            onClose: notifier.clearSelection,
            onViewPeakOnMap: _viewPeakOnMainMap,
            onViewNaturalFeatureOnMap: _viewNaturalFeatureOnMainMap,
            onViewGpxTrackOnMap: _viewGpxTrackOnMainMap,
            onViewRouteOnMap: _viewRouteOnMainMap,
            onPeakSubmit: _savePeak,
            onPeakListSubmit: _savePeakList,
            onRouteSubmit: _saveRoute,
            onNaturalFeatureSubmit: _saveNaturalFeature,
            onContactSubmit: _saveContact,
          ),
        ),
      ],
    );
  }
}
