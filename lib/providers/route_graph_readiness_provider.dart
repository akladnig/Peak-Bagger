import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/route_graph_import_coordinator.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final routeGraphStoreProvider = Provider<RouteGraphStore>((ref) {
  throw UnimplementedError('routeGraphStoreProvider must be overridden');
});

final routeGraphImportCoordinatorProvider =
    Provider<RouteGraphImportCoordinator>((ref) {
      final store = ref.watch(routeGraphStoreProvider);
      if (store case ObjectBoxRouteGraphStore(:final importCoordinator?)) {
        return importCoordinator;
      }
      throw UnimplementedError(
        'routeGraphImportCoordinatorProvider must be overridden',
      );
    });

enum RouteGraphReadinessStatus { preloading, ready, failed }

class RouteGraphReadinessState {
  const RouteGraphReadinessState._({required this.status, this.error});

  const RouteGraphReadinessState.preloading()
    : this._(status: RouteGraphReadinessStatus.preloading);

  const RouteGraphReadinessState.ready()
    : this._(status: RouteGraphReadinessStatus.ready);

  const RouteGraphReadinessState.failed(String error)
    : this._(status: RouteGraphReadinessStatus.failed, error: error);

  final RouteGraphReadinessStatus status;
  final String? error;

  bool get isReady => status == RouteGraphReadinessStatus.ready;
}

final routeGraphReadinessProvider =
    NotifierProvider<RouteGraphReadinessNotifier, RouteGraphReadinessState>(
      RouteGraphReadinessNotifier.new,
    );

class RouteGraphReadinessNotifier extends Notifier<RouteGraphReadinessState> {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.preloading();
  }

  void markPreloading() {
    if (!ref.mounted) {
      return;
    }

    state = const RouteGraphReadinessState.preloading();
  }

  void markReady() {
    if (!ref.mounted) {
      return;
    }

    state = const RouteGraphReadinessState.ready();
  }

  void markFailed(String error) {
    if (!ref.mounted) {
      return;
    }

    state = RouteGraphReadinessState.failed(error);
  }
}

final routeGraphCoverageImportStateProvider =
    NotifierProvider<
      RouteGraphCoverageImportStateNotifier,
      List<RouteGraphCoverageImportState>
    >(RouteGraphCoverageImportStateNotifier.new);

class RouteGraphCoverageImportStateNotifier
    extends Notifier<List<RouteGraphCoverageImportState>> {
  @override
  List<RouteGraphCoverageImportState> build() {
    final coordinator = ref.watch(routeGraphImportCoordinatorProvider);
    void sync() {
      if (ref.mounted) {
        state = coordinator.states;
      }
    }

    coordinator.addListener(sync);
    ref.onDispose(() => coordinator.removeListener(sync));
    return coordinator.states;
  }
}

final routeGraphBootstrapProvider =
    FutureProvider<RouteGraphImportBatchResult?>((ref) async {
      final readiness = ref.read(routeGraphReadinessProvider.notifier);

      try {
        final store = ref.read(routeGraphStoreProvider);
        final coordinator = store is ObjectBoxRouteGraphStore
            ? store.importCoordinator
            : null;
        if (coordinator == null) {
          await store.bootstrapData();
          readiness.markReady();
          return null;
        }

        final result = await coordinator.bootstrap();
        final hasUsableGraph = coordinator.states.any(
          (state) => state.hasActiveGeneration,
        );
        if (hasUsableGraph) {
          readiness.markReady();
        } else {
          readiness.markFailed(
            result is RouteGraphImportBatchConfigurationFailure
                ? result.error
                : 'Route graph bootstrap failed.',
          );
        }
        return result;
      } catch (error) {
        readiness.markFailed('$error');
        return null;
      }
    });

final routeGraphRepositoryProviderAvailableProvider = Provider<bool>((ref) {
  try {
    final store = ref.read(routeGraphStoreProvider);
    if (store is! RouteGraphRepositoryProvider) {
      return false;
    }
    final repository = (store as RouteGraphRepositoryProvider).repository;
    return repository != null && repository.hasUsableActiveGeneration;
  } catch (_) {
    return false;
  }
});
