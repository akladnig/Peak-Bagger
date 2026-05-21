import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final routeGraphStoreProvider = Provider<RouteGraphStore>((ref) {
  return BundledRouteGraphStore();
});

enum RouteGraphReadinessStatus { preloading, ready, failed }

class RouteGraphReadinessState {
  const RouteGraphReadinessState._({
    required this.status,
    this.error,
  });

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

final routeGraphReadinessProvider = NotifierProvider<
  RouteGraphReadinessNotifier,
  RouteGraphReadinessState
>(RouteGraphReadinessNotifier.new);

class RouteGraphReadinessNotifier extends Notifier<RouteGraphReadinessState> {
  bool _bootstrapStarted = false;

  @override
  RouteGraphReadinessState build() {
    _ensureBootstrapStarted();
    return const RouteGraphReadinessState.preloading();
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

  void _ensureBootstrapStarted() {
    if (_bootstrapStarted) {
      return;
    }

    _bootstrapStarted = true;
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    state = const RouteGraphReadinessState.preloading();
    try {
      await ref.read(routeGraphStoreProvider).preload();
      if (ref.mounted) {
        state = const RouteGraphReadinessState.ready();
      }
    } catch (error) {
      if (ref.mounted) {
        state = RouteGraphReadinessState.failed(error.toString());
      }
    }
  }
}
