import 'dart:async';
import 'dart:isolate';
import 'dart:developer' as developer;

import 'package:latlong2/latlong.dart';
import 'mapping_store_core.dart';
import 'route_elevation_sampler.dart';
import 'performance_measurement.dart';

/// One lazy session-owned worker. GDAL datasets and transforms never leave it.
/// Requests are serial; full summary recomputation keeps boundary smoothing exact.
class WorkerRouteElevationSampler
    implements RouteElevationSampler, RouteElevationPreparation {
  WorkerRouteElevationSampler({
    required MappingCatalog catalog,
    DemDatasetOpener? datasetOpener,
    MappingStoreFileSystem? fileSystem,
    // Named public parameters keep the worker seam independent of its fields.
    // ignore: prefer_initializing_formals
  }) : _catalog = catalog,
       _opener = datasetOpener,
       // ignore: prefer_initializing_formals
       _fileSystem = fileSystem {
    // Bootstrap can fail before _request reaches its await of this future.
    // Keep that error observed; callers still receive it through the original.
    _ready.future.ignore();
  }

  final MappingCatalog _catalog;
  final DemDatasetOpener? _opener;
  final MappingStoreFileSystem? _fileSystem;
  final _responses = ReceivePort();
  final _pending = <int, Completer<Object?>>{};
  final _ready = Completer<SendPort>();
  final _errors = ReceivePort();
  final _exited = Completer<void>();
  void Function()? _release;
  Future<void>? _closing;
  bool _disposed = false;
  Future<void>? _starting;
  var _serial = 0;

  Future<void> _start() async {
    try {
      _release = _catalog.sessionProtection?.retainNative();
    } catch (_) {
      _finish();
      rethrow;
    }
    _errors.listen((dynamic error) {
      _fail(StateError('Route elevation worker failed: ${error[0]}'));
    });
    _responses.listen((dynamic response) {
      if (response == null) {
        _finish();
      } else if (response is SendPort) {
        _ready.complete(response);
      } else {
        final message = response as List;
        final completion = _pending.remove(message[0] as int);
        if (completion == null) return;
        if (message[2] == null) {
          completion.complete(message[1]);
        } else {
          completion.completeError(message[1]!, message[2] as StackTrace);
        }
      }
    });
    final catalog = MappingCatalog(
      rootPath: _catalog.rootPath,
      regions: _catalog.regions,
      basemaps: _catalog.basemaps,
      tasmapCatalogPath: _catalog.tasmapCatalogPath,
      naturalFeaturesCatalogPath: _catalog.naturalFeaturesCatalogPath,
      demSources: _catalog.demSources,
      routingCoverageRegionKeys: _catalog.routingCoverageRegionKeys,
      polygonDisplayPaths: _catalog.polygonDisplayPaths,
    );
    try {
      await Isolate.spawn(
        _run,
        (
          _responses.sendPort,
          catalog,
          _opener,
          _fileSystem,
          Map<String, Object?>.of(performanceMeasurement.context),
        ),
        debugName: 'route-elevation',
        // Closing acknowledgement precedes exit on this same ordered port.
        onExit: _responses.sendPort,
        onError: _errors.sendPort,
      );
    } catch (_) {
      _finish();
      rethrow;
    }
  }

  void _fail(Object error) {
    developer.log(
      'Route elevation worker failed at ${_catalog.rootPath}',
      error: error,
    );
    if (!_ready.isCompleted) _ready.completeError(error);
    for (final completion in _pending.values) {
      completion.completeError(error);
    }
    _pending.clear();
  }

  void _finish() {
    if (_exited.isCompleted) return;
    if (_starting != null && (_pending.isNotEmpty || !_ready.isCompleted)) {
      _fail(StateError('Route elevation worker exited before completing work'));
    }
    _release?.call();
    _responses.close();
    _errors.close();
    _exited.complete();
  }

  Future<Object?> _request(
    String operation,
    List<LatLng> points,
    int request,
    int geometry,
  ) async {
    if (_disposed && operation != 'close') {
      throw StateError('Mapping DEM sampler is disposed');
    }
    final frozenPoints = List<LatLng>.of(points);
    await (_starting ??= _start());
    if (_exited.isCompleted) {
      throw StateError('Route elevation worker has exited');
    }
    final port = await _ready.future;
    final serial = ++_serial;
    final completion = Completer<Object?>();
    _pending[serial] = completion;
    port.send([serial, operation, frozenPoints, request, geometry]);
    return completion.future;
  }

  @override
  Future<List<double?>> samplePointElevations(List<LatLng> points) async =>
      (await _request('points', points, 0, 0)) as List<double?>;

  @override
  Future<void> prepareForPoints(List<LatLng> points) async {
    await _request('prepare', points, 0, 0);
  }

  @override
  Future<RouteElevationSummary> sampleRoute({
    required List<LatLng> points,
    required int requestId,
    required int geometryVersion,
  }) async =>
      (await _request('summary', points, requestId, geometryVersion))
          as RouteElevationSummary;

  Future<void> dispose() async {
    _disposed = true;
    return _closing ??= _dispose();
  }

  Future<void> _dispose() async {
    if (_starting == null) {
      _finish();
      return;
    }
    try {
      if (!_exited.isCompleted) await _request('close', const [], 0, 0);
    } finally {
      await _exited.future;
    }
  }

  static Future<void> _run(
    (
      SendPort,
      MappingCatalog,
      DemDatasetOpener?,
      MappingStoreFileSystem?,
      Map<String, Object?>,
    )
    config,
  ) async {
    final (responses, catalog, opener, fileSystem, context) = config;
    performanceMeasurement.context.addAll(context);
    final requests = ReceivePort();
    final sampler = RegionAwareRouteElevationSampler(
      catalog: catalog,
      datasetOpener: opener,
      fileSystem: fileSystem,
    );
    responses.send(requests.sendPort);
    await for (final dynamic raw in requests) {
      final message = raw as List;
      final serial = message[0] as int;
      final operation = message[1] as String;
      try {
        final points = message[2] as List<LatLng>;
        final result = switch (operation) {
          'prepare' => await sampler.prepareForPoints(points),
          'points' => await sampler.samplePointElevations(points),
          'summary' => await sampler.sampleRoute(
            points: points,
            requestId: message[3] as int,
            geometryVersion: message[4] as int,
          ),
          'close' => await sampler.dispose(),
          _ => throw StateError('Unknown DEM operation $operation'),
        };
        responses.send([serial, result, null]);
      } catch (error, stack) {
        developer.log(
          'Route elevation $operation failed at ${catalog.rootPath}',
          error: error,
          stackTrace: stack,
        );
        responses.send([serial, error, stack]);
      }
      if (operation == 'close') {
        requests.close();
        break;
      }
    }
  }
}
