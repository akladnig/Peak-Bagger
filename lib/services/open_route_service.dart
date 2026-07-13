import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class OpenRouteServiceSummary {
  const OpenRouteServiceSummary({
    required this.distanceMeters,
    required this.durationSeconds,
  });

  final double distanceMeters;
  final int durationSeconds;
}

class OpenRouteServiceException implements Exception {
  const OpenRouteServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class OpenRouteService {
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  });
}

class HttpOpenRouteService implements OpenRouteService {
  HttpOpenRouteService({
    required this._apiKey,
    http.Client? client,
    Uri? endpoint,
    this._timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _endpoint =
           endpoint ??
           Uri.parse(
             'https://api.openrouteservice.org/v2/directions/driving-car',
           );

  final String _apiKey;
  final http.Client _client;
  final Uri _endpoint;
  final Duration _timeout;

  @override
  Future<OpenRouteServiceSummary> fetchDrivingSummary({
    required LatLng origin,
    required LatLng destination,
  }) async {
    if (_apiKey.trim().isEmpty) {
      throw const OpenRouteServiceException(
        'OpenRouteService API key is missing',
      );
    }

    late final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Authorization': _apiKey,
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'coordinates': [
                [origin.longitude, origin.latitude],
                [destination.longitude, destination.latitude],
              ],
            }),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const OpenRouteServiceException(
        'OpenRouteService request timed out',
      );
    } catch (error) {
      throw OpenRouteServiceException(
        'OpenRouteService request failed: $error',
      );
    }

    if (response.statusCode != 200) {
      throw OpenRouteServiceException(
        'OpenRouteService request failed (${response.statusCode})',
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const OpenRouteServiceException(
        'OpenRouteService response was malformed',
      );
    }

    final routes = decoded['routes'];
    if (routes is! List || routes.isEmpty) {
      throw const OpenRouteServiceException(
        'OpenRouteService returned no routes',
      );
    }

    final firstRoute = routes.first;
    if (firstRoute is! Map<String, dynamic>) {
      throw const OpenRouteServiceException(
        'OpenRouteService response was malformed',
      );
    }

    final summary = firstRoute['summary'];
    if (summary is! Map<String, dynamic>) {
      throw const OpenRouteServiceException(
        'OpenRouteService response was missing a summary',
      );
    }

    final distance = summary['distance'];
    final duration = summary['duration'];
    if (distance is! num || duration is! num) {
      throw const OpenRouteServiceException(
        'OpenRouteService summary was malformed',
      );
    }

    return OpenRouteServiceSummary(
      distanceMeters: distance.toDouble(),
      durationSeconds: duration.round(),
    );
  }
}
