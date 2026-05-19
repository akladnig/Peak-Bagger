import 'package:peak_bagger/models/route.dart';

import '../objectbox.g.dart';

abstract class RouteStorage {
  Route? getById(int id);

  List<Route> getAll();

  int save(Route route);

  bool delete(int id);
}

class ObjectBoxRouteStorage implements RouteStorage {
  ObjectBoxRouteStorage(this._box);

  final Box<Route> _box;

  @override
  Route? getById(int id) => _box.get(id);

  @override
  List<Route> getAll() => _box.getAll();

  @override
  int save(Route route) => _box.put(route);

  @override
  bool delete(int id) => _box.remove(id);
}

class InMemoryRouteStorage implements RouteStorage {
  InMemoryRouteStorage([List<Route> routes = const []])
    : _routes = List<Route>.from(routes),
      _nextId = routes.fold<int>(1, (maxId, route) {
        final candidate = route.id + 1;
        return candidate > maxId ? candidate : maxId;
      });

  List<Route> _routes;
  int _nextId;

  @override
  Route? getById(int id) {
    for (final route in _routes) {
      if (route.id == id) {
        return route;
      }
    }
    return null;
  }

  @override
  List<Route> getAll() => List<Route>.unmodifiable(_routes);

  @override
  int save(Route route) {
    if (route.id == 0) {
      route.id = _nextId++;
    } else if (route.id >= _nextId) {
      _nextId = route.id + 1;
    }
    _routes = [
      ..._routes.where((existing) => existing.id != route.id),
      route,
    ];
    return route.id;
  }

  @override
  bool delete(int id) {
    final before = _routes.length;
    _routes = _routes.where((route) => route.id != id).toList(growable: false);
    return _routes.length != before;
  }
}

class RouteRepository {
  RouteRepository(Store store)
    : _storage = ObjectBoxRouteStorage(store.box<Route>());

  RouteRepository.test(RouteStorage storage) : _storage = storage;

  final RouteStorage _storage;

  List<Route> getAllRoutes() => _storage.getAll();

  Route? findById(int id) => _storage.getById(id);

  Route saveRoute(Route route) {
    final id = _storage.save(route);
    route.id = id;
    return route;
  }

  bool deleteRoute(int id) => _storage.delete(id);
}
