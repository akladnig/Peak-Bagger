import 'dart:io';

import 'package:peak_bagger/services/route_graph_import_service.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'route_graph_errors.dart';

export 'route_graph_errors.dart';

abstract class RouteGraphRepositoryProvider {
  RouteGraphRepository? get repository;
}

class RouteGraphStore {
  Future<void> bootstrapData() async {
    await preload();
  }

  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('Preload is not implemented.');
  }

  Future<trip_routing.TripService> reload() async {
    return preload();
  }

  Future<void> replaceSnapshot(String rawJson) async {
    throw const RouteGraphLoadException(
      'Snapshot replacement is not supported.',
    );
  }

  Future<File> snapshotFile() async {
    throw const RouteGraphLoadException(
      'Snapshot persistence is not supported.',
    );
  }
}

class ObjectBoxRouteGraphStore extends RouteGraphStore
    implements RouteGraphRepositoryProvider {
  ObjectBoxRouteGraphStore({
    required RouteGraphRepository repository,
    required RouteGraphImportService importService,
  }) : _repository = repository,
       _importService = importService;

  final RouteGraphRepository _repository;
  final RouteGraphImportService _importService;

  @override
  RouteGraphRepository get repository => _repository;

  Future<trip_routing.TripService>? _serviceFuture;

  @override
  Future<void> bootstrapData() async {
    await _importService.bootstrapIfNeeded();
  }

  @override
  Future<trip_routing.TripService> preload() {
    final cached = _serviceFuture;
    if (cached != null) {
      return cached;
    }

    final loading = _loadService(allowBootstrap: true);
    final wrapped = loading
        .then((service) {
          _serviceFuture = Future.value(service);
          return service;
        })
        .catchError((error, stackTrace) {
          _serviceFuture = null;
          Error.throwWithStackTrace(_normalizeError(error), stackTrace);
        });
    _serviceFuture = wrapped;
    return wrapped;
  }

  @override
  Future<trip_routing.TripService> reload() {
    final loading = _loadService(allowBootstrap: false, forceRefresh: true);
    final wrapped = loading
        .then((service) {
          _serviceFuture = Future.value(service);
          return service;
        })
        .catchError((error, stackTrace) {
          Error.throwWithStackTrace(_normalizeError(error), stackTrace);
        });
    return wrapped;
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {
    await _importService.importRawJson(rawJson, bootstrap: false);
    _serviceFuture = null;
  }

  @override
  Future<File> snapshotFile() async {
    throw const RouteGraphLoadException(
      'Route graph snapshot persistence is not supported.',
    );
  }

  Future<trip_routing.TripService> _loadService({
    required bool allowBootstrap,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _importService.refreshFromBundledAsset();
    } else if (allowBootstrap) {
      await _importService.bootstrapIfNeeded();
    }

    return _repository.buildTripServiceForActiveGeneration();
  }

  Object _normalizeError(Object error) {
    if (error is RouteGraphLoadException) {
      return error;
    }
    return RouteGraphLoadException('Failed to load local route graph: $error');
  }
}
