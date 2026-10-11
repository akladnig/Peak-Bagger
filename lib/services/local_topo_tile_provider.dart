import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;

const localTopoTileRequestTimeout = Duration(seconds: 15);

/// Bounds local tile requests and reports transport outages without image errors.
/// The tile layer owns this provider and its HTTP client.
class LocalTopoTileProvider extends NetworkTileProvider {
  factory LocalTopoTileProvider({
    Map<String, String>? headers,
    http.Client? httpClient,
    void Function(Uri)? onUnavailable,
    Duration requestTimeout = localTopoTileRequestTimeout,
  }) => LocalTopoTileProvider._(
    LocalTopoTileRequestClient(
      delegate: httpClient ?? http.Client(),
      onUnavailable: onUnavailable,
      timeout: requestTimeout,
    ),
    headers: headers,
  );

  LocalTopoTileProvider._(this._client, {super.headers})
    : super(
        httpClient: _client,
        silenceExceptions: true,
        attemptDecodeOfHttpErrorResponses: false,
        cachingProvider: const DisabledMapCachingProvider(),
      );

  final LocalTopoTileRequestClient _client;

  @override
  Future<void> dispose() async {
    _client.close();
    await super.dispose();
  }
}

class LocalTopoTileRequestClient extends http.BaseClient {
  LocalTopoTileRequestClient({
    required this.delegate,
    this.onUnavailable,
    this.timeout = localTopoTileRequestTimeout,
  });

  final http.Client delegate;
  final void Function(Uri)? onUnavailable;
  final Duration timeout;
  bool _reportedUnavailable = false;
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final abort = Completer<void>();
    void abortRequest() {
      if (!abort.isCompleted) abort.complete();
    }

    if (request case http.Abortable(:final abortTrigger?)) {
      unawaited(abortTrigger.then((_) => abortRequest()));
    }
    final outgoing =
        http.AbortableStreamedRequest(
            request.method,
            request.url,
            abortTrigger: abort.future,
          )
          ..headers.addAll(request.headers)
          ..followRedirects = request.followRedirects
          ..maxRedirects = request.maxRedirects
          ..persistentConnection = request.persistentConnection
          ..contentLength = request.contentLength;
    request.finalize().listen(
      outgoing.sink.add,
      onError: outgoing.sink.addError,
      onDone: outgoing.sink.close,
    );
    try {
      final response = await delegate
          .send(outgoing)
          .timeout(
            timeout,
            onTimeout: () {
              abortRequest();
              throw TimeoutException(
                'Local tile server connection timed out.',
                timeout,
              );
            },
          );
      if (response.statusCode >= 500) {
        _reportUnavailable(
          request.url,
          http.ClientException(
            'Local tile server returned HTTP ${response.statusCode}.',
            request.url,
          ),
          StackTrace.current,
        );
      }
      return http.StreamedResponse(
        response.stream.timeout(timeout).handleError((
          Object error,
          StackTrace stackTrace,
        ) {
          if (error is! http.RequestAbortedException) {
            _reportUnavailable(request.url, error, stackTrace);
            abortRequest();
          }
          Error.throwWithStackTrace(error, stackTrace);
        }),
        response.statusCode,
        contentLength: response.contentLength,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } on http.RequestAbortedException {
      rethrow;
    } catch (error, stackTrace) {
      _reportUnavailable(request.url, error, stackTrace);
      rethrow;
    }
  }

  void _reportUnavailable(Uri uri, Object error, StackTrace stackTrace) {
    if (_closed || _reportedUnavailable) return;
    _reportedUnavailable = true;
    developer.log(
      'Local Topo tile request failed: $uri',
      name: 'LocalTopoTileProvider',
      error: error,
      stackTrace: stackTrace,
    );
    onUnavailable?.call(uri);
  }

  @override
  void close() {
    _closed = true;
    delegate.close();
    super.close();
  }
}
