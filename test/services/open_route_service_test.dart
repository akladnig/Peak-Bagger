import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/open_route_service.dart';

void main() {
  test('maps successful driving summary response', () async {
    final service = HttpOpenRouteService(
      apiKey: 'key',
      client: _FakeHttpClient(
        (request) async => http.Response(
          jsonEncode({
            'routes': [
              {
                'summary': {'distance': 12345.0, 'duration': 4567.0},
              },
            ],
          }),
          200,
        ),
      ),
    );

    final summary = await service.fetchDrivingSummary(
      origin: const LatLng(-41.6, 146.6),
      destination: const LatLng(-41.5, 146.5),
    );

    expect(summary.distanceMeters, 12345.0);
    expect(summary.durationSeconds, 4567);
  });

  test('fails closed when API key is missing', () async {
    final service = HttpOpenRouteService(
      apiKey: '',
      client: _FakeHttpClient(
        (request) async => http.Response('{}', 200),
      ),
    );

    await expectLater(
      service.fetchDrivingSummary(
        origin: const LatLng(-41.6, 146.6),
        destination: const LatLng(-41.5, 146.5),
      ),
      throwsA(isA<OpenRouteServiceException>()),
    );
  });

  test('maps non-200 responses into app-owned failure', () async {
    final service = HttpOpenRouteService(
      apiKey: 'key',
      client: _FakeHttpClient(
        (request) async => http.Response('nope', 429),
      ),
    );

    await expectLater(
      service.fetchDrivingSummary(
        origin: const LatLng(-41.6, 146.6),
        destination: const LatLng(-41.5, 146.5),
      ),
      throwsA(isA<OpenRouteServiceException>()),
    );
  });

  test('maps malformed payloads into app-owned failure', () async {
    final service = HttpOpenRouteService(
      apiKey: 'key',
      client: _FakeHttpClient(
        (request) async => http.Response('{"routes":[{}]}', 200),
      ),
    );

    await expectLater(
      service.fetchDrivingSummary(
        origin: const LatLng(-41.6, 146.6),
        destination: const LatLng(-41.5, 146.5),
      ),
      throwsA(isA<OpenRouteServiceException>()),
    );
  });

  test('maps timeouts into app-owned failure', () async {
    final service = HttpOpenRouteService(
      apiKey: 'key',
      timeout: const Duration(milliseconds: 1),
      client: _FakeHttpClient(
        (request) async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        },
      ),
    );

    await expectLater(
      service.fetchDrivingSummary(
        origin: const LatLng(-41.6, 146.6),
        destination: const LatLng(-41.5, 146.5),
      ),
      throwsA(isA<OpenRouteServiceException>()),
    );
  });
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
