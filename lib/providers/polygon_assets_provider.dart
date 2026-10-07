import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

final polygonAssetRepositoryProvider = Provider<PolygonAssetRepository>((ref) {
  return PolygonAssetRepository(catalog: ref.watch(mappingCatalogProvider));
});

class PolygonDisplayState {
  PolygonDisplayState({
    Map<String, MapPolygonAsset> loaded = const {},
    Map<String, String> failures = const {},
    Set<String> pending = const {},
  }) : loaded = Map.unmodifiable(loaded),
       failures = Map.unmodifiable(failures),
       pending = Set.unmodifiable(pending),
       polygons = List.unmodifiable(loaded.values);

  final Map<String, MapPolygonAsset> loaded;
  final List<MapPolygonAsset> polygons;
  final Map<String, String> failures;
  final Set<String> pending;

  String? get unavailableReason =>
      failures.isEmpty ? null : failures.values.join('\n');
}

final polygonDisplayStateProvider =
    NotifierProvider<PolygonDisplayNotifier, PolygonDisplayState>(
      PolygonDisplayNotifier.new,
    );

class PolygonDisplayNotifier extends Notifier<PolygonDisplayState> {
  @override
  PolygonDisplayState build() => PolygonDisplayState();

  Future<MapPolygonAsset> load(String path) {
    final repository = ref.read(polygonAssetRepositoryProvider);
    path = repository.validatePath(path);
    return ref
        .read(mappingStoreOperationCoordinatorProvider)
        .run(
          key: MappingStoreOperationKey.polygonDisplay(path),
          action: () async {
            if (!ref.mounted) {
              throw StateError('Polygon display scope disposed.');
            }
            state = PolygonDisplayState(
              loaded: state.loaded,
              failures: state.failures,
              pending: {...state.pending, path},
            );
            try {
              final polygon = await repository.loadPolygon(path);
              if (ref.mounted) {
                state = PolygonDisplayState(
                  loaded: {...state.loaded, path: polygon},
                  failures: {...state.failures}..remove(path),
                  pending: {...state.pending}..remove(path),
                );
              }
              return polygon;
            } on MappingStoreOperationException catch (error) {
              if (ref.mounted) {
                state = PolygonDisplayState(
                  loaded: state.loaded,
                  failures: {...state.failures, path: error.toString()},
                  pending: {...state.pending}..remove(path),
                );
              }
              rethrow;
            }
          },
        );
  }

  Future<void> loadAll() async {
    final paths = ref.read(polygonAssetRepositoryProvider).paths.toList()
      ..sort();
    for (final path in paths) {
      if (!ref.mounted) return;
      try {
        await load(path);
      } on MappingStoreOperationException {
        // Retain successful geometry while the shared host presents each failure.
      }
    }
  }

  Future<void> retryUnavailable() async {
    final coordinator = ref.read(mappingStoreOperationCoordinatorProvider);
    for (final path in state.failures.keys.toList()) {
      if (!ref.mounted) return;
      await coordinator.retry(MappingStoreOperationKey.polygonDisplay(path));
    }
  }
}

/// Watched only when polygon display is requested. Constructing the repository
/// or ready scope never opens optional polygons.
final polygonAssetsProvider = FutureProvider<void>((ref) {
  return ref.read(polygonDisplayStateProvider.notifier).loadAll();
});
