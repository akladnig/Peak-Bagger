import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:xml/xml.dart';

class GpxTrackFilterResult {
  const GpxTrackFilterResult({
    required this.filteredXml,
    required this.displaySegments,
    required this.usedRawFallback,
    this.warning,
  });

  final String? filteredXml;
  final List<List<LatLng>> displaySegments;
  final bool usedRawFallback;
  final String? warning;
}

class GpxTrackFilter {
  const GpxTrackFilter();

  static const _distance = Distance();
  static const _maxSpeedMetersPerSecond = 12.0;
  static const _maxJumpMeters = 2_500.0;

  GpxTrackFilterResult filter(
    String rawGpxXml, {
    required GpxFilterConfig config,
  }) {
    try {
      final document = XmlDocument.parse(rawGpxXml);
      final rawDisplaySegments = _extractDisplaySegments(document);
      final sourceSegments = _extractTrackPoints(document);
      final trackName = _extractTrackName(document);
      final filteredSegments = _smoothSegments(sourceSegments, config);

      if (_countPoints(filteredSegments) < 2) {
        return GpxTrackFilterResult(
          filteredXml: null,
          displaySegments: rawDisplaySegments,
          usedRawFallback: true,
          warning: 'Filtered track had too few points; using raw GPX data.',
        );
      }

      final smoothedSegments = _smoothSegments(filteredSegments, config);
      final filteredXml = _buildMinimalDocument(
        trackName: trackName,
        segments: smoothedSegments,
      );

      return GpxTrackFilterResult(
        filteredXml: filteredXml,
        displaySegments: _segmentsToLocations(smoothedSegments),
        usedRawFallback: false,
      );
    } catch (_) {
      return GpxTrackFilterResult(
        filteredXml: null,
        displaySegments: const [],
        usedRawFallback: true,
        warning: 'Filtered track could not be generated; using raw GPX data.',
      );
    }
  }

  List<List<_TrackPoint>> _extractTrackPoints(XmlDocument document) {
    final trackSegments = document
        .findAllElements('trkseg')
        .toList(growable: false);
    if (trackSegments.isNotEmpty) {
      final segments = <List<_TrackPoint>>[];
      for (final segment in trackSegments) {
        final points = <_TrackPoint>[];
        for (final element in segment.findElements('trkpt')) {
          final point = _parsePoint(element);
          if (point != null) {
            points.add(point);
          }
        }
        if (points.isNotEmpty) {
          segments.add(points);
        }
      }
      return segments;
    }

    final points = <_TrackPoint>[];
    for (final element in document.findAllElements('trkpt')) {
      final point = _parsePoint(element);
      if (point != null) {
        points.add(point);
      }
    }

    return points.isEmpty ? const [] : [points];
  }

  List<List<LatLng>> _extractDisplaySegments(XmlDocument document) {
    final trackSegments = document
        .findAllElements('trkseg')
        .toList(growable: false);
    if (trackSegments.isNotEmpty) {
      final segments = <List<LatLng>>[];
      for (final segment in trackSegments) {
        final points = <LatLng>[];
        for (final element in segment.findElements('trkpt')) {
          final lat = double.tryParse(element.getAttribute('lat') ?? '');
          final lon = double.tryParse(element.getAttribute('lon') ?? '');
          if (lat != null && lon != null) {
            points.add(LatLng(lat, lon));
          }
        }
        if (points.isNotEmpty) {
          segments.add(points);
        }
      }
      return segments;
    }

    final points = <LatLng>[];
    for (final element in document.findAllElements('trkpt')) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat != null && lon != null) {
        points.add(LatLng(lat, lon));
      }
    }

    return points.isEmpty ? const [] : [points];
  }

  List<List<_TrackPoint>> _smoothSegments(
    List<List<_TrackPoint>> segments,
    GpxFilterConfig config,
  ) {
    return segments
        .map((segment) {
          final timePruned = _prunePointsWithoutTime(segment);
          final speedFiltered = _rejectImpossiblePoints(timePruned);
          if (speedFiltered.length < 2) {
            return const <_TrackPoint>[];
          }

          final elevationFiltered = _applyHampel(
            speedFiltered,
            config.hampelWindow,
          );
          final smoothedElevations = _smoothElevations(
            elevationFiltered,
            config.elevationSmoother,
            config.elevationWindow,
          );
          return _smoothPositions(
            smoothedElevations,
            config.positionSmoother,
            config.positionWindow,
          );
        })
        .where((segment) => segment.length >= 2)
        .toList(growable: false);
  }

  List<List<LatLng>> _segmentsToLocations(List<List<_TrackPoint>> segments) {
    return segments
        .map(
          (segment) =>
              segment.map((point) => point.location).toList(growable: false),
        )
        .toList(growable: false);
  }

  List<_TrackPoint> _prunePointsWithoutTime(List<_TrackPoint> points) {
    return points
        .where((point) => point.timeLocal != null)
        .toList(growable: false);
  }

  List<_TrackPoint> _rejectImpossiblePoints(List<_TrackPoint> points) {
    if (points.isEmpty) {
      return const [];
    }

    final accepted = <_TrackPoint>[points.first];
    for (var i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = accepted.last;
      final timeDelta = current.timeLocal!
          .difference(previous.timeLocal!)
          .inSeconds;
      if (timeDelta <= 0) {
        continue;
      }

      final distance = _distance.as(
        LengthUnit.Meter,
        previous.location,
        current.location,
      );
      final speed = distance / timeDelta;
      if (speed > _maxSpeedMetersPerSecond || distance > _maxJumpMeters) {
        continue;
      }

      accepted.add(current);
    }

    return accepted;
  }

  List<_TrackPoint> _applyHampel(List<_TrackPoint> points, int windowSize) {
    if (points.length < 3) {
      return points;
    }

    final radius = windowSize ~/ 2;
    final output = List<_TrackPoint>.from(points);

    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].elevation;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }

      if (elevations.length < 3 || points[i].elevation == null) {
        continue;
      }

      elevations.sort();
      final median = _medianOfSorted(elevations);
      final deviations =
          elevations
              .map((value) => (value - median).abs())
              .toList(growable: false)
            ..sort();
      final mad = _medianOfSorted(deviations);
      if (mad == 0) {
        if ((points[i].elevation! - median).abs() > 0) {
          output[i] = points[i].copyWith(elevation: median);
        }
        continue;
      }

      final threshold = 3 * 1.4826 * mad;
      if ((points[i].elevation! - median).abs() > threshold) {
        output[i] = points[i].copyWith(elevation: median);
      }
    }

    return output;
  }

  List<_TrackPoint> _smoothElevations(
    List<_TrackPoint> points,
    GpxTrackElevationSmoother smoother,
    int windowSize,
  ) {
    if (points.length < 3) {
      return points;
    }

    return switch (smoother) {
      GpxTrackElevationSmoother.median => _medianSmooth(points, windowSize),
      GpxTrackElevationSmoother.savitzkyGolay => _savitzkyGolaySmooth(
        points,
        windowSize,
      ),
    };
  }

  List<_TrackPoint> _medianSmooth(List<_TrackPoint> points, int windowSize) {
    final radius = windowSize ~/ 2;
    final output = List<_TrackPoint>.from(points);
    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].elevation;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }
      if (elevations.isEmpty) {
        continue;
      }
      elevations.sort();
      output[i] = points[i].copyWith(elevation: _medianOfSorted(elevations));
    }
    return output;
  }

  List<_TrackPoint> _savitzkyGolaySmooth(
    List<_TrackPoint> points,
    int windowSize,
  ) {
    final radius = windowSize ~/ 2;
    final output = List<_TrackPoint>.from(points);
    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].elevation;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }
      if (elevations.length < 3) {
        continue;
      }
      elevations.sort();
      output[i] = points[i].copyWith(elevation: _medianOfSorted(elevations));
    }
    return output;
  }

  List<_TrackPoint> _smoothPositions(
    List<_TrackPoint> points,
    GpxTrackPositionSmoother smoother,
    int windowSize,
  ) {
    if (points.length < 3) {
      return points;
    }

    return switch (smoother) {
      GpxTrackPositionSmoother.movingAverage => _movingAveragePositions(
        points,
        windowSize,
      ),
      GpxTrackPositionSmoother.kalman => _kalmanPositions(points, windowSize),
    };
  }

  List<_TrackPoint> _movingAveragePositions(
    List<_TrackPoint> points,
    int windowSize,
  ) {
    final radius = windowSize ~/ 2;
    final output = <_TrackPoint>[];
    for (var i = 0; i < points.length; i++) {
      final window = points.sublist(
        math.max(0, i - radius),
        math.min(points.length, i + radius + 1),
      );
      final avgLat =
          window
              .map((point) => point.location.latitude)
              .reduce((a, b) => a + b) /
          window.length;
      final avgLng =
          window
              .map((point) => point.location.longitude)
              .reduce((a, b) => a + b) /
          window.length;
      output.add(points[i].copyWith(location: LatLng(avgLat, avgLng)));
    }
    return output;
  }

  List<_TrackPoint> _kalmanPositions(List<_TrackPoint> points, int windowSize) {
    final output = <_TrackPoint>[];
    var lat = points.first.location.latitude;
    var lng = points.first.location.longitude;
    final gain = 2 / (windowSize + 1);

    output.add(points.first);
    for (var i = 1; i < points.length; i++) {
      lat = lat + gain * (points[i].location.latitude - lat);
      lng = lng + gain * (points[i].location.longitude - lng);
      output.add(points[i].copyWith(location: LatLng(lat, lng)));
    }
    return output;
  }

  String? _extractTrackName(XmlDocument document) {
    final nameElement = document.findAllElements('name').firstOrNull;
    final text = nameElement?.innerText.trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  _TrackPoint? _parsePoint(XmlElement element) {
    final lat = double.tryParse(element.getAttribute('lat') ?? '');
    final lon = double.tryParse(element.getAttribute('lon') ?? '');
    if (lat == null || lon == null) {
      return null;
    }

    final timeText = element.getElement('time')?.innerText.trim();
    if (timeText == null || timeText.isEmpty) {
      return null;
    }

    DateTime? timeLocal;
    try {
      timeLocal = DateTime.parse(timeText).toLocal();
    } catch (_) {
      return null;
    }

    final eleText = element.getElement('ele')?.innerText.trim();
    final elevation = eleText == null || eleText.isEmpty
        ? null
        : double.tryParse(eleText);

    return _TrackPoint(
      location: LatLng(lat, lon),
      timeLocal: timeLocal,
      elevation: elevation,
    );
  }

  int _countPoints(List<List<_TrackPoint>> segments) {
    return segments.fold(0, (sum, segment) => sum + segment.length);
  }

  double _medianOfSorted(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    final middle = values.length ~/ 2;
    if (values.length.isOdd) {
      return values[middle];
    }
    return (values[middle - 1] + values[middle]) / 2;
  }

  String _buildMinimalDocument({
    required String? trackName,
    required List<List<_TrackPoint>> segments,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      attributes: const {'version': '1.1', 'creator': 'peak_bagger'},
      nest: () {
        builder.element(
          'trk',
          nest: () {
            if (trackName != null && trackName.isNotEmpty) {
              builder.element('name', nest: trackName);
            }
            for (final segment in segments) {
              builder.element(
                'trkseg',
                nest: () {
                  for (final point in segment) {
                    builder.element(
                      'trkpt',
                      attributes: {
                        'lat': point.location.latitude.toStringAsFixed(8),
                        'lon': point.location.longitude.toStringAsFixed(8),
                      },
                      nest: () {
                        if (point.elevation != null) {
                          builder.element(
                            'ele',
                            nest: point.elevation!.toStringAsFixed(2),
                          );
                        }
                        if (point.timeLocal != null) {
                          builder.element(
                            'time',
                            nest: point.timeLocal!.toUtc().toIso8601String(),
                          );
                        }
                      },
                    );
                  }
                },
              );
            }
          },
        );
      },
    );
    return builder.buildDocument().toXmlString(pretty: false);
  }
}

class _TrackPoint {
  const _TrackPoint({required this.location, this.timeLocal, this.elevation});

  final LatLng location;
  final DateTime? timeLocal;
  final double? elevation;

  _TrackPoint copyWith({
    LatLng? location,
    DateTime? timeLocal,
    double? elevation,
  }) {
    return _TrackPoint(
      location: location ?? this.location,
      timeLocal: timeLocal ?? this.timeLocal,
      elevation: elevation ?? this.elevation,
    );
  }
}
