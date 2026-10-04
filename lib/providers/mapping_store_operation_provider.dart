import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

final mappingStoreOperationCoordinatorProvider =
    Provider<MappingStoreOperationCoordinator>((ref) {
      final coordinator = MappingStoreOperationCoordinator();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// Rebuilds the dialog host whenever the coordinator's queue changes.
final mappingStoreOperationRevisionProvider =
    NotifierProvider<MappingStoreOperationRevisionNotifier, int>(
      MappingStoreOperationRevisionNotifier.new,
    );

class MappingStoreOperationRevisionNotifier extends Notifier<int> {
  late final MappingStoreOperationCoordinator _coordinator;

  @override
  int build() {
    _coordinator = ref.watch(mappingStoreOperationCoordinatorProvider);
    _coordinator.addListener(_increment);
    ref.onDispose(() => _coordinator.removeListener(_increment));
    return 0;
  }

  void _increment() {
    if (ref.mounted) {
      state++;
    }
  }
}

final mappingStoreBootstrapOperationsProvider =
    Provider<List<MappingStoreBootstrapOperation>>((ref) {
      final repository = ref.read(tasmapRepositoryProvider);
      final notifier = ref.read(tasmapStateProvider.notifier);
      return [
        MappingStoreBootstrapOperation(
          key: const MappingStoreOperationKey.tasmapBootstrap(),
          shouldRun: repository.isEmpty,
          writerTables: const ['Tasmap50k'],
          run: notifier.bootstrapFromMappingStore,
        ),
      ];
    });

final mappingStoreBootstrapCoordinatorProvider =
    Provider<MappingStoreBootstrapCoordinator>((ref) {
      return MappingStoreBootstrapCoordinator(
        operationCoordinator: ref.watch(
          mappingStoreOperationCoordinatorProvider,
        ),
        operations: ref.watch(mappingStoreBootstrapOperationsProvider),
      );
    });

final mappingStoreBootstrapProvider = FutureProvider<void>((ref) {
  return ref.watch(mappingStoreBootstrapCoordinatorProvider).schedule();
});
