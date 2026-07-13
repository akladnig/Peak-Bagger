import 'dart:async';
import 'dart:collection';

import 'package:fvg_topo_proxy/src/transparent_tile.dart';
import 'package:fvg_topo_proxy/src/upstream_wms_client.dart';
import 'package:fvg_topo_proxy/src/web_mercator.dart';
import 'package:shelf/shelf.dart';

export 'upstream_wms_client.dart' show UpstreamTileResponse, UpstreamWmsClient;
export 'web_mercator.dart'
    show
        ProjectedBounds,
        TileCoordinate,
        fvgCoverageBounds,
        tileBoundsInWebMercator;

const _routePrefix = 'fvg-topo';
const _defaultMaxConcurrentUpstreamRequests = 2;
const _defaultUpstreamAttempts = 6;
const _baseRetryDelay = Duration(milliseconds: 400);

final _sharedUpstreamSemaphore = AsyncSemaphore(
  _defaultMaxConcurrentUpstreamRequests,
);

class FvgTopoTileHandler {
  FvgTopoTileHandler({
    required this._upstreamClient,
    this._maxZoom = 19,
    this._upstreamAttempts = _defaultUpstreamAttempts,
    AsyncSemaphore? upstreamSemaphore,
  }) : _upstreamSemaphore = upstreamSemaphore ?? _sharedUpstreamSemaphore;

  final UpstreamWmsClient _upstreamClient;
  final int _maxZoom;
  final int _upstreamAttempts;
  final AsyncSemaphore _upstreamSemaphore;

  Future<Response> handle(Request request) async {
    final coordinate = TileCoordinate.tryParse(
      request.url.pathSegments,
      routePrefix: _routePrefix,
    );
    if (coordinate == null) {
      return Response.badRequest(body: 'Invalid tile path');
    }

    if (coordinate.z > _maxZoom) {
      return _transparentTileResponse();
    }

    final bbox = tileBoundsInWebMercator(coordinate);
    if (!bbox.intersects(fvgCoverageBounds)) {
      return _transparentTileResponse();
    }

    try {
      return await _upstreamSemaphore.withPermit(() async {
        final layerName = upstreamLayerNameForZoom(coordinate.z);
        for (var attempt = 1; attempt <= _upstreamAttempts; attempt++) {
          try {
            final upstreamResponse = await _upstreamClient.fetchTile(
              bbox: bbox,
              layerName: layerName,
            );
            if (upstreamResponse.statusCode == 200 &&
                (upstreamResponse.contentType?.startsWith('image/png') ??
                    false)) {
              return Response.ok(
                upstreamResponse.bodyBytes,
                headers: {
                  'Content-Type': 'image/png',
                  'Cache-Control': 'public, max-age=86400',
                },
              );
            }
          } on TimeoutException {
            if (attempt == _upstreamAttempts) {
              return _transientFailureTileResponse();
            }
          } catch (_) {
            if (attempt == _upstreamAttempts) {
              return _transientFailureTileResponse();
            }
          }

          if (attempt == _upstreamAttempts) {
            return _transientFailureTileResponse();
          }

          await Future<void>.delayed(_retryDelayForAttempt(attempt));
        }

        return _transientFailureTileResponse();
      });
    } catch (_) {
      return _transientFailureTileResponse();
    }
  }
}

Duration _retryDelayForAttempt(int attempt) {
  return _baseRetryDelay * attempt * attempt;
}

Response _transparentTileResponse() {
  return Response.ok(
    transparentTilePngBytes,
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=3600',
    },
  );
}

Response _transientFailureTileResponse() {
  return Response.ok(
    transparentTilePngBytes,
    headers: {
      'Content-Type': 'image/png',
      'Cache-Control': 'public, max-age=60',
    },
  );
}

class AsyncSemaphore {
  AsyncSemaphore(this._maxPermits);

  final int _maxPermits;
  int _activePermits = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();

  Future<T> withPermit<T>(Future<T> Function() action) async {
    await _acquire();
    try {
      return await action();
    } finally {
      _release();
    }
  }

  Future<void> _acquire() {
    if (_activePermits < _maxPermits) {
      _activePermits++;
      return Future<void>.value();
    }

    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  void _release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeFirst().complete();
      return;
    }

    _activePermits--;
  }
}
