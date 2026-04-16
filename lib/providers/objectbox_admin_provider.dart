import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';

final objectboxAdminRepositoryProvider = Provider<ObjectBoxAdminRepository>((
  ref,
) {
  throw UnimplementedError(
    'objectboxAdminRepositoryProvider must be overridden',
  );
});

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
    this.noMatches = false,
  });

  final List<ObjectBoxAdminEntityDescriptor> entities;
  final ObjectBoxAdminEntityDescriptor? selectedEntity;
  final ObjectBoxAdminViewMode mode;
  final String searchQuery;
  final bool sortAscending;
  final bool isLoading;
  final String? error;
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
    ObjectBoxAdminViewMode? mode,
    String? searchQuery,
    bool? sortAscending,
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<ObjectBoxAdminRow>? rows,
    int? visibleRowCount,
    ObjectBoxAdminRow? selectedRow,
    bool clearSelectedRow = false,
    bool? noMatches,
  }) {
    return ObjectBoxAdminState(
      entities: entities ?? this.entities,
      selectedEntity: selectedEntity ?? this.selectedEntity,
      mode: mode ?? this.mode,
      searchQuery: searchQuery ?? this.searchQuery,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
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

  @override
  ObjectBoxAdminState build() {
    _repository = ref.read(objectboxAdminRepositoryProvider);
    final entities = _repository.getEntities();
    final initialEntity = entities.isNotEmpty ? entities.first : null;

    final initialState = ObjectBoxAdminState(
      entities: entities,
      selectedEntity: initialEntity,
      mode: ObjectBoxAdminViewMode.data,
      searchQuery: '',
      sortAscending: true,
      isLoading: initialEntity != null,
      rows: const [],
      visibleRowCount: 0,
      noMatches: false,
    );

    if (initialEntity != null) {
      Future.microtask(_loadSelectedEntity);
    }

    return initialState;
  }

  Future<void> selectEntity(ObjectBoxAdminEntityDescriptor entity) async {
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

    await _loadSelectedEntity();
  }

  Future<void> refresh() async {
    final entities = _repository.getEntities();
    final selectedEntity = _resolveSelectedEntity(entities);

    if (selectedEntity == null) {
      state = state.copyWith(
        entities: entities,
        selectedEntity: null,
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
      isLoading: true,
      clearError: true,
      clearSelectedRow: true,
      rows: const [],
      visibleRowCount: 0,
      noMatches: false,
    );

    await _loadSelectedEntity();
  }

  void setMode(ObjectBoxAdminViewMode mode) {
    if (state.mode == mode) {
      return;
    }

    state = state.copyWith(mode: mode, clearSelectedRow: true);
  }

  void updateSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  Future<void> runSearch() async {
    await _loadSelectedEntity();
  }

  Future<void> toggleSort() async {
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
    state = state.copyWith(selectedRow: row);
  }

  void clearSelection() {
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

  Future<void> _loadSelectedEntity() async {
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
        searchQuery: state.searchQuery,
        ascending: state.sortAscending,
      );

      if (!ref.mounted) {
        return;
      }

      state = state.copyWith(
        isLoading: false,
        error: null,
        rows: rows,
        visibleRowCount: rows.isEmpty ? 0 : min(50, rows.length),
        noMatches: rows.isEmpty,
        clearSelectedRow: true,
      );
    } catch (error, stackTrace) {
      logObjectBoxAdminError(
        error,
        stackTrace,
        'ObjectBox admin load failed for ${entity.displayName}',
      );
      if (!ref.mounted) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load ${entity.displayName}: $error',
        rows: const [],
        visibleRowCount: 0,
        noMatches: false,
        clearSelectedRow: true,
      );
    }
  }

  ObjectBoxAdminEntityDescriptor? _resolveSelectedEntity(
    List<ObjectBoxAdminEntityDescriptor> entities,
  ) {
    final currentName = state.selectedEntity?.name;
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
