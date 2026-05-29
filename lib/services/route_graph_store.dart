import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import 'route_graph_errors.dart';

export 'route_graph_errors.dart';

const _bundledRouteGraphAsset = 'assets/highway.json';
const _routeGraphDirectoryName = 'route_graph';
const _routeGraphSnapshotName = 'highway.json';

class RouteGraphStore {
  Future<trip_routing.TripService> preload() async {
    throw const RouteGraphLoadException('Preload is not implemented.');
  }

  Future<trip_routing.TripService> reload() async {
    return preload();
  }

  Future<void> replaceSnapshot(String rawJson) async {
    throw const RouteGraphLoadException('Snapshot replacement is not supported.');
  }

  Future<File> snapshotFile() async {
    throw const RouteGraphLoadException('Snapshot persistence is not supported.');
  }
}

class BundledRouteGraphStore extends RouteGraphStore {
  BundledRouteGraphStore({
    Future<Directory> Function()? supportDirectoryLoader,
    Future<String> Function(String assetPath)? assetLoader,
    trip_routing.TripService Function()? tripServiceFactory,
    this.assetPath = _bundledRouteGraphAsset,
  })  : _supportDirectoryLoader = supportDirectoryLoader ?? getApplicationSupportDirectory,
        _assetLoader = assetLoader ?? rootBundle.loadString,
        _tripServiceFactory = tripServiceFactory ?? trip_routing.TripService.new;

  final Future<Directory> Function() _supportDirectoryLoader;
  final Future<String> Function(String assetPath) _assetLoader;
  final trip_routing.TripService Function() _tripServiceFactory;
  final String assetPath;

  Future<trip_routing.TripService>? _serviceFuture;

  @override
  Future<trip_routing.TripService> preload() {
    final cached = _serviceFuture;
    if (cached != null) {
      return cached;
    }

    final loading = _loadService();
    final wrapped = loading.then((service) {
      _serviceFuture = Future.value(service);
      return service;
    }).catchError((error, stackTrace) {
      _serviceFuture = null;
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    });
    _serviceFuture = wrapped;
    return wrapped;
  }

  @override
  Future<trip_routing.TripService> reload() {
    final loading = _loadService();
    final wrapped = loading.then((service) {
      _serviceFuture = Future.value(service);
      return service;
    }).catchError((error, stackTrace) {
      Error.throwWithStackTrace(_normalizeError(error), stackTrace);
    });
    return wrapped;
  }

  @override
  Future<void> replaceSnapshot(String rawJson) async {
    final decodedJson = _decodeSnapshot(rawJson);
    final validationService = _tripServiceFactory();
    try {
      await validationService.loadOverpassJson(
        decodedJson,
        preferWalkingPaths: true,
        source: assetPath,
      );
    } catch (error) {
      throw _normalizeError(error);
    }

    final file = await snapshotFile();
    final tempFile = File('${file.path}.tmp.${DateTime.now().microsecondsSinceEpoch}');
    await tempFile.parent.create(recursive: true);
    await tempFile.writeAsString(rawJson, flush: true);
    await tempFile.rename(file.path);
  }

  @override
  Future<File> snapshotFile() async {
    final supportDir = await _supportDirectoryLoader();
    final graphDir = Directory(p.join(supportDir.path, _routeGraphDirectoryName));
    await graphDir.create(recursive: true);
    return File(p.join(graphDir.path, _routeGraphSnapshotName));
  }

  Future<trip_routing.TripService> _loadService() async {
    final file = await snapshotFile();
    if (!await file.exists()) {
      final rawAsset = await _assetLoader(assetPath);
      await file.writeAsString(rawAsset, flush: true);
    }

    final rawJson = await file.readAsString();
    final decodedJson = _decodeSnapshot(rawJson);
    final tripService = _tripServiceFactory();
    try {
      await tripService.loadOverpassJson(
        decodedJson,
        preferWalkingPaths: true,
        source: file.path,
      );
    } catch (error) {
      throw _normalizeError(error);
    }
    return tripService;
  }

  Map<String, dynamic> _decodeSnapshot(String rawJson) {
    try {
      final decodedJson = jsonDecode(rawJson);
      if (decodedJson is! Map<String, dynamic>) {
        throw const RouteGraphLoadException(
          'Expected decoded Overpass JSON object.',
        );
      }
      return decodedJson;
    } catch (error) {
      if (error is RouteGraphLoadException) {
        rethrow;
      }
      throw RouteGraphLoadException('Failed to decode route graph snapshot: $error');
    }
  }

  Object _normalizeError(Object error) {
    if (error is RouteGraphLoadException) {
      return error;
    }
    return RouteGraphLoadException('Failed to load local route graph: $error');
  }
}
