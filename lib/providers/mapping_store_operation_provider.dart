import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';

final mappingStoreOperationCoordinatorProvider =
    Provider<MappingStoreOperationCoordinator>((ref) {
      final coordinator = MappingStoreOperationCoordinator();
      ref.onDispose(coordinator.dispose);
      return coordinator;
    });

/// The production ready scope enables post-ready Natural Features bootstrap.
/// Lightweight widget harnesses intentionally leave it disabled.
final naturalFeatureBootstrapEnabledProvider = Provider<bool>((ref) => false);

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
      final operations = <MappingStoreBootstrapOperation>[
        MappingStoreBootstrapOperation(
          key: const MappingStoreOperationKey.tasmapBootstrap(),
          shouldRun: repository.isEmpty,
          writerTables: const ['Tasmap50k'],
          run: notifier.bootstrapFromMappingStore,
        ),
      ];
      if (ref.watch(naturalFeatureBootstrapEnabledProvider)) {
        final naturalFeatureRepository = ref.read(
          naturalFeatureRepositoryProvider,
        );
        final naturalFeatureRefresh = ref.read(
          naturalFeatureRefreshServiceProvider,
        );
        operations.add(
          MappingStoreBootstrapOperation(
            key: const MappingStoreOperationKey.naturalFeaturesBootstrap(),
            shouldRun: naturalFeatureRepository.isEmpty,
            writerTables: const ['NaturalFeature'],
            run: naturalFeatureRefresh.refresh,
          ),
        );
      }
      return operations;
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

class NaturalFeatureAvailability {
  const NaturalFeatureAvailability._(this.reason);

  const NaturalFeatureAvailability.available() : this._(null);
  const NaturalFeatureAvailability.unavailable(String reason) : this._(reason);

  final String? reason;
  bool get isAvailable => reason == null;
}

final naturalFeatureAvailabilityProvider = Provider<NaturalFeatureAvailability>((
  ref,
) {
  ref.watch(mappingStoreOperationRevisionProvider);
  if (!ref.watch(naturalFeatureBootstrapEnabledProvider)) {
    return const NaturalFeatureAvailability.available();
  }
  final repository = ref.watch(naturalFeatureRepositoryProvider);
  if (!repository.isEmpty()) {
    return const NaturalFeatureAvailability.available();
  }
  final coordinator = ref.watch(mappingStoreOperationCoordinatorProvider);
  const key = MappingStoreOperationKey.naturalFeaturesBootstrap();
  if (coordinator.isPending(key)) {
    return const NaturalFeatureAvailability.unavailable(
      'Natural Features are loading from the Mapping data store.',
    );
  }
  final failure = coordinator.failureFor(key);
  if (failure != null) {
    return NaturalFeatureAvailability.unavailable(failure.toString());
  }
  return const NaturalFeatureAvailability.unavailable(
    'Natural Features are unavailable until their Mapping data store bootstrap completes.',
  );
});
