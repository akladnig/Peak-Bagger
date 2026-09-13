import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';

const overlayTileRequestTimeout = Duration(seconds: 15);

class OverlayTileOutageReporter {
  OverlayTileOutageReporter([this._onReport]);

  final void Function(String message)? _onReport;
  final Set<String> _reportedOverlayKeys = <String>{};
  final StreamController<String> _messages = StreamController<String>.broadcast(
    sync: true,
  );

  Stream<String> get messages => _messages.stream;

  void report(String overlayKey) {
    if (!_reportedOverlayKeys.add(overlayKey)) {
      return;
    }

    final message = switch (overlayKey) {
      terrainReliefShadingOverlayKey =>
        'Terrain relief shading is unavailable from the local tile server',
      contourLinesOverlayKey =>
        'Contour lines are unavailable from the local tile server',
      _ => null,
    };
    if (message != null) {
      _onReport?.call(message);
      _messages.add(message);
    }
  }

  void resetOverlay(String overlayKey) {
    _reportedOverlayKeys.remove(overlayKey);
  }

  void resetAfterCapabilityValidation() {
    _reportedOverlayKeys.clear();
  }

  Future<void> dispose() => _messages.close();
}

class OverlayTileProvider extends TileProvider {
  OverlayTileProvider({
    required String overlayKey,
    required OverlayTileOutageReporter reporter,
    http.Client? httpClient,
    Duration requestTimeout = overlayTileRequestTimeout,
  }) : _ownsHttpClient = httpClient == null {
    _requestClient = OverlayTileRequestClient(
      delegate: httpClient ?? http.Client(),
      overlayKey: overlayKey,
      reporter: reporter,
      timeout: requestTimeout,
    );
    _delegate = NetworkTileProvider(
      httpClient: _requestClient,
      silenceExceptions: true,
      attemptDecodeOfHttpErrorResponses: false,
      cachingProvider: DisabledMapCachingProvider(),
    );
  }

  late final OverlayTileRequestClient _requestClient;
  late final NetworkTileProvider _delegate;
  final bool _ownsHttpClient;

  @override
  Map<String, String> get headers => _delegate.headers;

  @override
  bool get supportsCancelLoading => _delegate.supportsCancelLoading;

  @override
  ImageProvider<Object> getImage(
    TileCoordinates coordinates,
    TileLayer options,
  ) => _delegate.getImage(coordinates, options);

  @override
  ImageProvider<Object> getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) => _delegate.getImageWithCancelLoadingSupport(
    coordinates,
    options,
    cancelLoading,
  );

  @override
  Future<void> dispose() async {
    await _delegate.dispose();
    if (_ownsHttpClient) {
      _requestClient.close();
    }
    super.dispose();
  }
}

class OverlayTileRequestClient extends http.BaseClient {
  OverlayTileRequestClient({
    required this.delegate,
    required this.overlayKey,
    required this.reporter,
    this.timeout = overlayTileRequestTimeout,
  });

  final http.Client delegate;
  final String overlayKey;
  final OverlayTileOutageReporter reporter;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    try {
      final response = await delegate.send(request).timeout(timeout);
      if (response.statusCode >= 500) {
        reporter.report(overlayKey);
      }
      return response;
    } on http.RequestAbortedException {
      rethrow;
    } on TimeoutException {
      reporter.report(overlayKey);
      rethrow;
    } catch (_) {
      reporter.report(overlayKey);
      rethrow;
    }
  }
}
