import 'dart:convert';

import 'package:latlong2/latlong.dart';

class ElevationProfileSample {
  const ElevationProfileSample({
    required this.distanceMeters,
    required this.elevationMeters,
    this.timeLocal,
  });

  final double distanceMeters;
  final double? elevationMeters;
  final DateTime? timeLocal;
}

class ElevationProfileSeries {
  const ElevationProfileSeries({
    required this.samples,
    required this.supportsTimeAxis,
  });

  final List<ElevationProfileSample> samples;
  final bool supportsTimeAxis;

  bool get isEmpty => samples.isEmpty;

  bool get hasUsableElevation =>
      samples.any((sample) => sample.elevationMeters != null);

  bool get hasUsableTimeAxis {
    if (!supportsTimeAxis) {
      return false;
    }
    return samples.where((sample) => sample.timeLocal != null).length >= 2;
  }

  double get maxDistanceMeters =>
      samples.isEmpty ? 0 : samples.last.distanceMeters;
}

abstract final class ElevationProfileSeriesBuilder {
  static const _distance = Distance();

  static ElevationProfileSeries fromTrackProfileJson(String jsonString) {
    if (jsonString.isEmpty || jsonString == '[]') {
      return const ElevationProfileSeries(samples: [], supportsTimeAxis: false);
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      return const ElevationProfileSeries(samples: [], supportsTimeAxis: false);
    }

    if (decoded is! List) {
      return const ElevationProfileSeries(samples: [], supportsTimeAxis: false);
    }

    final samples = <ElevationProfileSample>[];
    var validTimeCount = 0;

    for (final entry in decoded) {
      if (entry is! Map) {
        continue;
      }

      final distanceMeters = _asDouble(entry['distanceMeters']);
      if (distanceMeters == null) {
        continue;
      }

      final elevationMeters = _asDouble(entry['elevationMeters']);
      final timeLocal = _parseTimeLocal(entry['timeLocal']);
      if (timeLocal != null) {
        validTimeCount += 1;
      }

      samples.add(
        ElevationProfileSample(
          distanceMeters: distanceMeters,
          elevationMeters: elevationMeters,
          timeLocal: timeLocal,
        ),
      );
    }

    return ElevationProfileSeries(
      samples: samples,
      supportsTimeAxis: validTimeCount >= 2,
    );
  }

  static ElevationProfileSeries fromRoutePoints({
    required List<LatLng> points,
    required List<num?> elevations,
  }) {
    if (points.isEmpty) {
      return const ElevationProfileSeries(samples: [], supportsTimeAxis: false);
    }

    final samples = <ElevationProfileSample>[];
    var distanceMeters = 0.0;
    for (var index = 0; index < points.length; index++) {
      if (index > 0) {
        distanceMeters += _distance.as(
          LengthUnit.Meter,
          points[index - 1],
          points[index],
        );
      }

      final elevationMeters = index < elevations.length
          ? elevations[index]?.toDouble()
          : null;

      samples.add(
        ElevationProfileSample(
          distanceMeters: distanceMeters,
          elevationMeters: elevationMeters,
        ),
      );
    }

    return ElevationProfileSeries(samples: samples, supportsTimeAxis: false);
  }

  static double? _asDouble(Object? value) {
    return value is num ? value.toDouble() : null;
  }

  static DateTime? _parseTimeLocal(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    try {
      return DateTime.parse(value).toLocal();
    } catch (_) {
      return null;
    }
  }
}
