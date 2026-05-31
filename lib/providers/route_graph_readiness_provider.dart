import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final routeGraphStoreProvider = Provider<RouteGraphStore>((ref) {
  throw UnimplementedError('routeGraphStoreProvider must be overridden');
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
    return const RouteGraphReadinessState.ready();
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

final routeGraphBootstrapProvider = FutureProvider<void>((ref) async {
  final readiness = ref.read(routeGraphReadinessProvider.notifier);
  readiness.markPreloading();

  try {
    await ref.read(routeGraphStoreProvider).bootstrapData();
    readiness.markReady();
  } catch (error) {
    readiness.markFailed('$error');
  }
});
