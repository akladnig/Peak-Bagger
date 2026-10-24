import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/objectbox_admin_save_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

final objectboxAdminRepositoryProvider = Provider<ObjectBoxAdminRepository>((
  ref,
) {
  throw UnimplementedError(
    'objectboxAdminRepositoryProvider must be overridden',
  );
});

int? _objectBoxAdminPendingPeakId;
String _objectBoxAdminPendingPeakSearchQuery = '';

class ObjectBoxAdminPendingPeakSelection {
  const ObjectBoxAdminPendingPeakSelection({
    required this.peakId,
    required this.searchQuery,
  });

  final int peakId;
  final String searchQuery;
}

void setObjectBoxAdminPendingPeakId(int? peakId) {
  _objectBoxAdminPendingPeakId = peakId;
  if (peakId == null) {
    _objectBoxAdminPendingPeakSearchQuery = '';
  }
}

void setObjectBoxAdminPendingPeakSelection({
  required int peakId,
  required String searchQuery,
}) {
  _objectBoxAdminPendingPeakId = peakId;
  _objectBoxAdminPendingPeakSearchQuery = searchQuery.trim();
}

int? peekObjectBoxAdminPendingPeakId() {
  return _objectBoxAdminPendingPeakId;
}

ObjectBoxAdminPendingPeakSelection? peekObjectBoxAdminPendingPeakSelection() {
  final peakId = _objectBoxAdminPendingPeakId;
  if (peakId == null) {
    return null;
  }
  return ObjectBoxAdminPendingPeakSelection(
    peakId: peakId,
    searchQuery: _objectBoxAdminPendingPeakSearchQuery,
  );
}

int? consumeObjectBoxAdminPendingPeakId() {
  final peakId = _objectBoxAdminPendingPeakId;
  _objectBoxAdminPendingPeakId = null;
  _objectBoxAdminPendingPeakSearchQuery = '';
  return peakId;
}

ObjectBoxAdminPendingPeakSelection?
consumeObjectBoxAdminPendingPeakSelection() {
  final selection = peekObjectBoxAdminPendingPeakSelection();
  _objectBoxAdminPendingPeakId = null;
  _objectBoxAdminPendingPeakSearchQuery = '';
  return selection;
}

enum ObjectBoxAdminViewMode { schema, data }

class ObjectBoxAdminState {
  const ObjectBoxAdminState({
    required this.entities,
    required this.mode,
    required this.searchQuery,
    required this.sortAscending,
    required this.isLoading,
    required this.rows,
    required this.visibleRowCount,
    this.selectedEntity,
    this.selectedRow,
    this.error,
    this.schemaError,
    this.noMatches = false,
  });

  final List<ObjectBoxAdminEntityDescriptor> entities;
  final ObjectBoxAdminEntityDescriptor? selectedEntity;
  final ObjectBoxAdminViewMode mode;
  final String searchQuery;
  final bool sortAscending;
  final bool isLoading;
  final String? error;
  final String? schemaError;
  final List<ObjectBoxAdminRow> rows;
  final int visibleRowCount;
  final ObjectBoxAdminRow? selectedRow;
  final bool noMatches;

  List<ObjectBoxAdminRow> get visibleRows {
    final end = min(visibleRowCount, rows.length);
    return rows.take(end).toList(growable: false);
  }

  ObjectBoxAdminState copyWith({
    List<ObjectBoxAdminEntityDescriptor>? entities,
    ObjectBoxAdminEntityDescriptor? selectedEntity,
    bool clearSelectedEntity = false,
    ObjectBoxAdminViewMode? mode,
    String? searchQuery,
    bool? sortAscending,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? schemaError,
    bool clearSchemaError = false,
    List<ObjectBoxAdminRow>? rows,
    int? visibleRowCount,
    ObjectBoxAdminRow? selectedRow,
    bool clearSelectedRow = false,
    bool? noMatches,
  }) {
    return ObjectBoxAdminState(
      entities: entities ?? this.entities,
      selectedEntity: clearSelectedEntity
          ? null
          : (selectedEntity ?? this.selectedEntity),
      mode: mode ?? this.mode,
      searchQuery: searchQuery ?? this.searchQuery,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      schemaError: clearSchemaError ? null : (schemaError ?? this.schemaError),
      rows: rows ?? this.rows,
      visibleRowCount: visibleRowCount ?? this.visibleRowCount,
      selectedRow: clearSelectedRow ? null : (selectedRow ?? this.selectedRow),
      noMatches: noMatches ?? this.noMatches,
    );
  }
}

final objectboxAdminProvider =
    NotifierProvider<ObjectBoxAdminNotifier, ObjectBoxAdminState>(
      ObjectBoxAdminNotifier.new,
    );

class ObjectBoxAdminNotifier extends Notifier<ObjectBoxAdminState> {
  late final ObjectBoxAdminRepository _repository;
  int _readGeneration = 0;
  int _selectionGeneration = 0;
  String? _recoveryEntityName;

  bool get _savePending => ref.read(objectboxAdminSaveProvider);

  @override
  ObjectBoxAdminState build() {
    _repository = ref.read(objectboxAdminRepositoryProvider);
    List<ObjectBoxAdminEntityDescriptor> entities;
    String? schemaError;
    try {
      entities = _normalizeEntities(_repository.getEntities());
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'ObjectBox admin schema discovery failed',
      );
      entities = [];
      schemaError =
          'Unable to discover the ObjectBox schema. Retry to load metadata.';
    }
    final launchSelection = consumeObjectBoxAdminPendingPeakSelection();
    final launchPeakId = launchSelection?.peakId;
    ObjectBoxAdminEntityDescriptor? initialEntity;
    if (launchPeakId == null) {
      initialEntity = entities.isNotEmpty ? entities.first : null;
    } else {
      initialEntity = _peakEntity(entities);
      initialEntity ??= entities.isNotEmpty ? entities.first : null;
    }
    _recoveryEntityName =
        initialEntity?.name ?? (launchPeakId != null ? 'Peak' : null);

    final initialState = ObjectBoxAdminState(
      entities: entities,
      selectedEntity: initialEntity,
      mode: ObjectBoxAdminViewMode.data,
      searchQuery: launchSelection?.searchQuery ?? '',
      sortAscending: true,
      isLoading: initialEntity != null,
      rows: const [],
      visibleRowCount: 0,
      noMatches: false,
      schemaError: schemaError,
    );

    if (initialEntity != null) {
      final generation = _readGeneration;
      Future<void>.microtask(() async {
        if (!ref.mounted || generation != _readGeneration) return;
        await _loadSelectedEntity(keepSelectedRowPrimaryKey: launchPeakId);
      });
    }

    return initialState;
  }

  Future<void> selectEntity(
    ObjectBoxAdminEntityDescriptor entity, {
    Object? keepSelectedRowPrimaryKey,
  }) async {
    if (_savePending) return;
    if (state.schemaError != null || !state.entities.contains(entity)) return;
    ++_selectionGeneration;
    _recoveryEntityName = entity.name;
    state = state.copyWith(
      selectedEntity: entity,
      isLoading: true,
      clearError: true,
      clearSelectedRow: true,
      rows: const [],
      visibleRowCount: 0,
      noMatches: false,
      searchQuery: '',
      sortAscending: true,
    );

    await _loadSelectedEntity(
      keepSelectedRowPrimaryKey: keepSelectedRowPrimaryKey,
    );
  }

  Future<void> refresh({Object? keepSelectedRowPrimaryKey}) async {
    if (_savePending) return;
    await _refresh(keepSelectedRowPrimaryKey: keepSelectedRowPrimaryKey);
  }

  /// Only the Save action may refresh while its navigation/input gate is held.
  Future<void> refreshAfterSave({required Object keepSelectedRowPrimaryKey}) =>
      _refresh(keepSelectedRowPrimaryKey: keepSelectedRowPrimaryKey);

  /// Delete/recovery owns the same mutation gate as Save. Report failed reads to
  /// the coordinator without destroying the unrelated selected projection.
  Future<void> refreshAfterDelete() async {
    await _refresh(
      keepSelectedRowPrimaryKey: state.selectedRow?.primaryKeyValue,
    );
    if (!ref.mounted) return;
    final error = state.schemaError ?? state.error;
    if (error != null) throw StateError(error);
  }

  void didDeleteRecord(Object primaryKey) {
    ++_readGeneration; // An older read cannot resurrect a removed record.
    final rows = state.rows
        .where((row) => row.primaryKeyValue != primaryKey)
        .toList();
    state = state.copyWith(
      rows: rows,
      visibleRowCount: min(state.visibleRowCount, rows.length),
      clearSelectedRow: state.selectedRow?.primaryKeyValue == primaryKey,
    );
  }

  Future<void> _refresh({Object? keepSelectedRowPrimaryKey}) async {
    ++_readGeneration;
    _recoveryEntityName = state.selectedEntity?.name ?? _recoveryEntityName;
    List<ObjectBoxAdminEntityDescriptor> entities;
    try {
      entities = _normalizeEntities(_repository.getEntities());
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'ObjectBox admin schema discovery failed',
      );
      state = state.copyWith(
        schemaError:
            'Unable to discover the ObjectBox schema. Retry to load metadata.',
        entities: const [],
        clearSelectedEntity: state.selectedRow == null,
        isLoading: false,
        clearSelectedRow: false,
        rows: const [],
        visibleRowCount: 0,
        noMatches: false,
      );
      return;
    }
    final pendingSelection = consumeObjectBoxAdminPendingPeakSelection();
    final selectedEntity = pendingSelection != null
        ? (_peakEntity(entities) ?? _resolveSelectedEntity(entities))
        : _resolveSelectedEntity(entities);
    final searchQuery = pendingSelection?.searchQuery ?? state.searchQuery;
    final selectedRowPrimaryKey =
        pendingSelection?.peakId ??
        keepSelectedRowPrimaryKey ??
        state.selectedRow?.primaryKeyValue;
    _recoveryEntityName = selectedEntity?.name;

    if (selectedEntity == null) {
      state = state.copyWith(
        entities: entities,
        clearSelectedEntity: true,
        clearSchemaError: true,
        isLoading: false,
        clearError: true,
        clearSelectedRow: true,
        rows: const [],
        visibleRowCount: 0,
        noMatches: false,
      );
      return;
    }

    state = state.copyWith(
      entities: entities,
      selectedEntity: selectedEntity,
      clearSchemaError: true,
      mode: pendingSelection != null ? ObjectBoxAdminViewMode.data : state.mode,
      searchQuery: searchQuery,
      isLoading: !_savePending && state.selectedRow == null,
      clearError: true,
      clearSelectedRow: pendingSelection != null,
      rows: _savePending ? state.rows : const [],
      visibleRowCount: _savePending ? state.visibleRowCount : 0,
      noMatches: false,
    );

    await _loadSelectedEntity(keepSelectedRowPrimaryKey: selectedRowPrimaryKey);
  }

  void setMode(ObjectBoxAdminViewMode mode) {
    if (_savePending) return;
    if (state.mode == mode) {
      return;
    }

    ++_selectionGeneration;
    state = state.copyWith(mode: mode, clearSelectedRow: true);
  }

  void updateSearchQuery(String query) {
    if (!_canSearch) return;
    state = state.copyWith(
      searchQuery: query,
      isLoading: true,
      clearError: true,
    );
    unawaited(
      _loadSelectedEntity(
        keepSelectedRowPrimaryKey: state.selectedRow?.primaryKeyValue,
      ),
    );
  }

  Future<void> runSearch() async {
    if (!_canSearch) return;
    state = state.copyWith(isLoading: true, clearError: true);
    await _loadSelectedEntity(
      keepSelectedRowPrimaryKey: state.selectedRow?.primaryKeyValue,
    );
  }

  bool get _canSearch =>
      !_savePending &&
      state.mode == ObjectBoxAdminViewMode.data &&
      state.selectedEntity != null &&
      state.schemaError == null;

  Future<void> toggleSort() async {
    if (_savePending) return;
    state = state.copyWith(
      sortAscending: !state.sortAscending,
      clearSelectedRow: true,
      isLoading: true,
      clearError: true,
      rows: const [],
      visibleRowCount: 0,
      noMatches: false,
    );
    await _loadSelectedEntity();
  }

  void selectRow(ObjectBoxAdminRow row) {
    if (_savePending) return;
    ++_selectionGeneration;
    state = state.copyWith(selectedRow: row);
  }

  void clearSelection() {
    if (_savePending) return;
    ++_selectionGeneration;
    state = state.copyWith(clearSelectedRow: true);
  }

  void loadMoreRows() {
    if (state.visibleRowCount >= state.rows.length) {
      return;
    }

    state = state.copyWith(
      visibleRowCount: min(state.visibleRowCount + 50, state.rows.length),
    );
  }

  Future<void> _loadSelectedEntity({Object? keepSelectedRowPrimaryKey}) async {
    if (!ref.mounted || state.schemaError != null) return;
    final generation = ++_readGeneration;
    final selectionGeneration = _selectionGeneration;
    final entity = state.selectedEntity;
    if (entity == null) {
      state = state.copyWith(
        isLoading: false,
        rows: const [],
        visibleRowCount: 0,
        noMatches: false,
        clearSelectedRow: true,
      );
      return;
    }

    try {
      final rows = await _repository.loadRows(
        entity,
        searchQuery: '',
        ascending: state.sortAscending,
      );

      if (!ref.mounted || generation != _readGeneration) {
        return;
      }

      // Resolve identity from committed records, independently of membership.
      final selectedKey = selectionGeneration == _selectionGeneration
          ? keepSelectedRowPrimaryKey ?? state.selectedRow?.primaryKeyValue
          : state.selectedRow?.primaryKeyValue;
      final nextSelectedRow = selectedKey == null
          ? null
          : _findRowByPrimaryKey(rows, selectedKey);
      final filtered = objectBoxAdminFilterAndSortRows(
        entity,
        rows: rows,
        searchQuery: state.searchQuery,
        ascending: state.sortAscending,
      );

      state = state.copyWith(
        isLoading: false,
        clearError: true,
        rows: filtered,
        visibleRowCount: filtered.isEmpty ? 0 : min(50, filtered.length),
        noMatches: rows.isNotEmpty && filtered.isEmpty,
        selectedRow: nextSelectedRow,
        clearSelectedRow: nextSelectedRow == null,
      );
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'ObjectBox admin load failed for ${entity.displayName}',
      );
      if (!ref.mounted || generation != _readGeneration) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load ${entity.displayName}: $error',
        rows: const [],
        visibleRowCount: 0,
        noMatches: false,
        clearSelectedRow: false,
      );
    }
  }

  ObjectBoxAdminRow? _findRowByPrimaryKey(
    List<ObjectBoxAdminRow> rows,
    Object? primaryKey,
  ) {
    for (final row in rows) {
      if (row.primaryKeyValue == primaryKey) {
        return row;
      }
    }

    return null;
  }

  ObjectBoxAdminEntityDescriptor? _peakEntity(
    List<ObjectBoxAdminEntityDescriptor> entities,
  ) {
    for (final entity in entities) {
      if (entity.name == 'Peak') {
        return entity;
      }
    }
    return null;
  }

  List<ObjectBoxAdminEntityDescriptor> _normalizeEntities(
    List<ObjectBoxAdminEntityDescriptor> entities,
  ) {
    final entitiesByName = <String, ObjectBoxAdminEntityDescriptor>{};
    for (final entity in entities) {
      entitiesByName.putIfAbsent(entity.name, () => entity);
    }
    return entitiesByName.values.toList(growable: false);
  }

  ObjectBoxAdminEntityDescriptor? _resolveSelectedEntity(
    List<ObjectBoxAdminEntityDescriptor> entities,
  ) {
    final currentName = state.selectedEntity?.name ?? _recoveryEntityName;
    if (currentName != null) {
      for (final entity in entities) {
        if (entity.name == currentName) {
          return entity;
        }
      }
    }

    return entities.isNotEmpty ? entities.first : null;
  }
}
