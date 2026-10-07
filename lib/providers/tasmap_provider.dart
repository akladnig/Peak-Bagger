import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

final tasmapRepositoryProvider = Provider<TasmapRepository>((ref) {
  throw UnimplementedError('tasmapRepositoryProvider must be overridden');
});

class TasmapState {
  final int mapCount;
  final int tasmapRevision;
  final bool isLoading;
  final String? error;

  const TasmapState({
    this.mapCount = 0,
    this.tasmapRevision = 0,
    this.isLoading = false,
    this.error,
  });

  TasmapState copyWith({
    int? mapCount,
    int? tasmapRevision,
    bool? isLoading,
    String? error,
  }) {
    return TasmapState(
      mapCount: mapCount ?? this.mapCount,
      tasmapRevision: tasmapRevision ?? this.tasmapRevision,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

final tasmapStateProvider = NotifierProvider<TasmapNotifier, TasmapState>(
  TasmapNotifier.new,
);

class TasmapNotifier extends Notifier<TasmapState> {
  @override
  TasmapState build() {
    try {
      return TasmapState(mapCount: ref.read(tasmapRepositoryProvider).mapCount);
    } on Object {
      return const TasmapState();
    }
  }

  Future<void> loadCount() async {
    try {
      final repo = ref.read(tasmapRepositoryProvider);
      state = state.copyWith(mapCount: repo.mapCount);
    } catch (_) {}
  }

  Future<TasmapCsvImportResult> updateFromMappingStore() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tasmapRepositoryProvider);
      final catalog = ref.read(mappingCatalogProvider);
      final result = await ref
          .read(mappingStoreOperationCoordinatorProvider)
          .run(
            key: const MappingStoreOperationKey.tasmapUpdate(),
            writerTables: const ['Tasmap50k'],
            action: () => repo.reconcileFromMappingStore(catalog),
          );
      state = state.copyWith(
        mapCount: repo.mapCount,
        tasmapRevision: result.changed
            ? state.tasmapRevision + 1
            : state.tasmapRevision,
      );
      return result;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> bootstrapFromMappingStore() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(tasmapRepositoryProvider);
      final result = await repo.reconcileFromMappingStore(
        ref.read(mappingCatalogProvider),
      );
      state = state.copyWith(
        mapCount: repo.mapCount,
        tasmapRevision: result.changed
            ? state.tasmapRevision + 1
            : state.tasmapRevision,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
      rethrow;
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }
}
