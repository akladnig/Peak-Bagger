import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/objectbox.g.dart';

final routeRevisionProvider = NotifierProvider<RouteRevisionNotifier, int>(
  RouteRevisionNotifier.new,
);

final routeRepositoryProvider = Provider<RouteStore>((ref) {
  try {
    return RouteStore(objectboxStore.box<Route>());
  } catch (_) {
    return RouteStore.inMemory();
  }
});

final routeListProvider = Provider<List<Route>>((ref) {
  ref.watch(routeRevisionProvider);
  return ref.watch(routeRepositoryProvider).getAllRoutes();
});

final routeAvailabilityProvider = Provider<RouteAvailabilityState>((ref) {
  final routes = ref.watch(routeListProvider);
  if (routes.isEmpty) {
    return const RouteAvailabilityState.empty();
  }
  return RouteAvailabilityState.available(routes);
});

class RouteStore {
  RouteStore(this._box) : _routes = null;

  RouteStore.inMemory([List<Route> routes = const []])
    : _box = null,
      _routes = List<Route>.from(routes);

  final Box<Route>? _box;
  final List<Route>? _routes;

  List<Route> getAllRoutes() {
    return List<Route>.unmodifiable(_box?.getAll() ?? _routes ?? const <Route>[]);
  }
}

class RouteAvailabilityState {
  const RouteAvailabilityState._({required this.routes, required this.isAvailable});

  const RouteAvailabilityState.empty()
    : this._(routes: const [], isAvailable: false);

  const RouteAvailabilityState.available(this.routes) : isAvailable = true;

  final List<Route> routes;
  final bool isAvailable;

  String? get helperText => isAvailable ? null : 'No routes available';
}

class RouteRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state += 1;
  }
}
