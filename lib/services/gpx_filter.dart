import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:xml/xml.dart';

import 'gpx_point_sample.dart';

class GpxFilterResult {
  const GpxFilterResult({
    required this.filteredSegments,
    required this.displaySegments,
    required this.usedRawFallback,
    required this.sourceKind,
    this.filteredXml,
    this.warning,
    this.name,
    this.desc,
  });

  final List<List<GpxPointSample>> filteredSegments;
  final List<List<LatLng>> displaySegments;
  final bool usedRawFallback;
  final GpxPointSourceKind sourceKind;
  final String? filteredXml;
  final String? warning;
  final String? name;
  final String? desc;
}

class GpxFilter {
  const GpxFilter();

  static const _distance = Distance();

  GpxFilterResult filter(String rawGpxXml, {required GpxFilterConfig config}) {
    try {
      final document = XmlDocument.parse(rawGpxXml);
      final sourceKind = _hasTrackGeometry(document)
          ? GpxPointSourceKind.track
          : GpxPointSourceKind.route;
      final name = _extractMetadata(document, 'name', sourceKind);
      final desc = _extractMetadata(document, 'desc', sourceKind);
      final rawSegments = _extractPointSegments(document, sourceKind);
      final rawDisplaySegments = _segmentsToLocations(rawSegments);
      final filteredSegments = _smoothSegments(rawSegments, config);

      if (_countPoints(filteredSegments) < 2) {
        return GpxFilterResult(
          filteredSegments: rawSegments,
          displaySegments: rawDisplaySegments,
          usedRawFallback: true,
          sourceKind: sourceKind,
          warning: 'Filtered track had too few points; using raw GPX data.',
          name: name,
          desc: desc,
        );
      }

      final filteredXml = _buildMinimalDocument(
        sourceKind: sourceKind,
        name: name,
        desc: desc,
        segments: filteredSegments,
      );

      return GpxFilterResult(
        filteredSegments: filteredSegments,
        displaySegments: _segmentsToLocations(filteredSegments),
        usedRawFallback: false,
        sourceKind: sourceKind,
        filteredXml: filteredXml,
        name: name,
        desc: desc,
      );
    } catch (_) {
      return const GpxFilterResult(
        filteredSegments: [],
        displaySegments: [],
        usedRawFallback: true,
        sourceKind: GpxPointSourceKind.track,
        warning: 'Filtered track could not be generated; using raw GPX data.',
      );
    }
  }

  bool _hasTrackGeometry(XmlDocument document) {
    return document.findAllElements('trkpt').isNotEmpty;
  }

  List<List<GpxPointSample>> _extractPointSegments(
    XmlDocument document,
    GpxPointSourceKind sourceKind,
  ) {
    if (sourceKind == GpxPointSourceKind.track) {
      final trackSegments = document
          .findAllElements('trkseg')
          .toList(growable: false);
      if (trackSegments.isNotEmpty) {
        final segments = <List<GpxPointSample>>[];
        for (final segment in trackSegments) {
          final points = <GpxPointSample>[];
          for (final element in segment.findElements('trkpt')) {
            final point = _parsePoint(element, sourceKind);
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
    }

    final points = <GpxPointSample>[];
    for (final element in document.findAllElements('rtept')) {
      final point = _parsePoint(element, sourceKind);
      if (point != null) {
        points.add(point);
      }
    }

    return points.isEmpty ? const [] : [points];
  }

  List<List<LatLng>> _segmentsToLocations(List<List<GpxPointSample>> segments) {
    return segments
        .map(
          (segment) =>
              segment.map((point) => point.location).toList(growable: false),
        )
        .toList(growable: false);
  }

  List<List<GpxPointSample>> _smoothSegments(
    List<List<GpxPointSample>> segments,
    GpxFilterConfig config,
  ) {
    return segments
        .map((segment) {
          final timeFiltered = _pruneByTimeWhenAvailable(segment);
          if (timeFiltered.length < 2) {
            return const <GpxPointSample>[];
          }

          final speedFiltered = _rejectImpossiblePoints(timeFiltered);
          if (speedFiltered.length < 2) {
            return const <GpxPointSample>[];
          }

          final elevationFiltered = switch (config.outlierFilter) {
            GpxTrackOutlierFilter.none => speedFiltered,
            GpxTrackOutlierFilter.hampel => _applyHampel(
              speedFiltered,
              config.hampelWindow,
            ),
          };
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

  List<GpxPointSample> _pruneByTimeWhenAvailable(List<GpxPointSample> points) {
    if (!points.any((point) => point.time != null)) {
      return points;
    }

    return points.where((point) => point.time != null).toList(growable: false);
  }

  List<GpxPointSample> _rejectImpossiblePoints(List<GpxPointSample> points) {
    if (points.isEmpty || points.any((point) => point.time == null)) {
      return points;
    }

    final accepted = <GpxPointSample>[points.first];
    for (var i = 1; i < points.length; i++) {
      final current = points[i];
      final previous = accepted.last;
      final timeDelta = current.time!.difference(previous.time!).inSeconds;
      if (timeDelta <= 0) {
        continue;
      }

      final distance = _distance.as(
        LengthUnit.Meter,
        previous.location,
        current.location,
      );
      final speed = distance / timeDelta;
      if (speed > GpxConstants.maxSpeedMetersPerSecond ||
          distance > GpxConstants.maxJumpMeters) {
        continue;
      }

      accepted.add(current);
    }

    return accepted;
  }

  List<GpxPointSample> _applyHampel(
    List<GpxPointSample> points,
    int windowSize,
  ) {
    if (points.length < 3) {
      return points;
    }

    final radius = windowSize ~/ 2;
    final output = List<GpxPointSample>.from(points);

    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].ele;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }

      if (elevations.length < 3 || points[i].ele == null) {
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
        if ((points[i].ele! - median).abs() > 0) {
          output[i] = points[i].copyWith(ele: median);
        }
        continue;
      }

      final threshold = 3 * 1.4826 * mad;
      if ((points[i].ele! - median).abs() > threshold) {
        output[i] = points[i].copyWith(ele: median);
      }
    }

    return output;
  }

  List<GpxPointSample> _smoothElevations(
    List<GpxPointSample> points,
    GpxTrackElevationSmoother smoother,
    int windowSize,
  ) {
    if (points.length < 3) {
      return points;
    }

    return switch (smoother) {
      GpxTrackElevationSmoother.none => points,
      GpxTrackElevationSmoother.median => _medianSmooth(points, windowSize),
      GpxTrackElevationSmoother.savitzkyGolay => _savitzkyGolaySmooth(
        points,
        windowSize,
      ),
    };
  }

  List<GpxPointSample> _medianSmooth(
    List<GpxPointSample> points,
    int windowSize,
  ) {
    final radius = windowSize ~/ 2;
    final output = List<GpxPointSample>.from(points);
    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].ele;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }
      if (elevations.isEmpty) {
        continue;
      }
      elevations.sort();
      output[i] = points[i].copyWith(ele: _medianOfSorted(elevations));
    }
    return output;
  }

  List<GpxPointSample> _savitzkyGolaySmooth(
    List<GpxPointSample> points,
    int windowSize,
  ) {
    final radius = windowSize ~/ 2;
    final output = List<GpxPointSample>.from(points);
    for (var i = 0; i < points.length; i++) {
      final elevations = <double>[];
      for (
        var j = math.max(0, i - radius);
        j <= math.min(points.length - 1, i + radius);
        j++
      ) {
        final elevation = points[j].ele;
        if (elevation != null) {
          elevations.add(elevation);
        }
      }
      if (elevations.length < 3) {
        continue;
      }
      elevations.sort();
      output[i] = points[i].copyWith(ele: _medianOfSorted(elevations));
    }
    return output;
  }

  List<GpxPointSample> _smoothPositions(
    List<GpxPointSample> points,
    GpxTrackPositionSmoother smoother,
    int windowSize,
  ) {
    if (points.length < 3) {
      return points;
    }

    return switch (smoother) {
      GpxTrackPositionSmoother.none => points,
      GpxTrackPositionSmoother.movingAverage => _movingAveragePositions(
        points,
        windowSize,
      ),
      GpxTrackPositionSmoother.kalman => _kalmanPositions(points, windowSize),
    };
  }

  List<GpxPointSample> _movingAveragePositions(
    List<GpxPointSample> points,
    int windowSize,
  ) {
    final radius = windowSize ~/ 2;
    final output = <GpxPointSample>[];
    for (var i = 0; i < points.length; i++) {
      final window = points.sublist(
        math.max(0, i - radius),
        math.min(points.length, i + radius + 1),
      );
      final avgLat =
          window.map((point) => point.lat).reduce((a, b) => a + b) /
          window.length;
      final avgLng =
          window.map((point) => point.lon).reduce((a, b) => a + b) /
          window.length;
      output.add(points[i].copyWith(lat: avgLat, lon: avgLng));
    }
    return output;
  }

  List<GpxPointSample> _kalmanPositions(
    List<GpxPointSample> points,
    int windowSize,
  ) {
    final output = <GpxPointSample>[];
    var lat = points.first.lat;
    var lng = points.first.lon;
    final gain = 2 / (windowSize + 1);

    output.add(points.first);
    for (var i = 1; i < points.length; i++) {
      lat = lat + gain * (points[i].lat - lat);
      lng = lng + gain * (points[i].lon - lng);
      output.add(points[i].copyWith(lat: lat, lon: lng));
    }
    return output;
  }

  GpxPointSample? _parsePoint(
    XmlElement element,
    GpxPointSourceKind sourceKind,
  ) {
    final lat = double.tryParse(element.getAttribute('lat') ?? '');
    final lon = double.tryParse(element.getAttribute('lon') ?? '');
    if (lat == null || lon == null) {
      return null;
    }

    final timeText = element.getElement('time')?.innerText.trim();
    DateTime? time;
    if (timeText != null && timeText.isNotEmpty) {
      try {
        time = DateTime.parse(timeText).toLocal();
      } catch (_) {
        time = null;
      }
    }

    final eleText = element.getElement('ele')?.innerText.trim();
    final elevation = eleText == null || eleText.isEmpty
        ? null
        : double.tryParse(eleText);

    return GpxPointSample(
      lat: lat,
      lon: lon,
      ele: elevation,
      time: time,
      sourceKind: sourceKind,
    );
  }

  int _countPoints(List<List<GpxPointSample>> segments) {
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
    required GpxPointSourceKind sourceKind,
    required String? name,
    required String? desc,
    required List<List<GpxPointSample>> segments,
  }) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element(
      'gpx',
      attributes: const {'version': '1.1', 'creator': 'peak_bagger'},
      nest: () {
        if (sourceKind == GpxPointSourceKind.track) {
          builder.element(
            'trk',
            nest: () {
              if (name != null && name.isNotEmpty) {
                builder.element('name', nest: name);
              }
              if (desc != null && desc.isNotEmpty) {
                builder.element('desc', nest: desc);
              }
              for (final segment in segments) {
                builder.element(
                  'trkseg',
                  nest: () {
                    for (final point in segment) {
                      builder.element(
                        'trkpt',
                        attributes: {
                          'lat': formatCoordinate(point.lat),
                          'lon': formatCoordinate(point.lon),
                        },
                        nest: () {
                          if (point.ele != null) {
                            builder.element(
                              'ele',
                              nest: point.ele!.toStringAsFixed(2),
                            );
                          }
                          if (point.time != null) {
                            builder.element(
                              'time',
                              nest: point.time!.toUtc().toIso8601String(),
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
        } else {
          builder.element(
            'rte',
            nest: () {
              if (name != null && name.isNotEmpty) {
                builder.element('name', nest: name);
              }
              if (desc != null && desc.isNotEmpty) {
                builder.element('desc', nest: desc);
              }
              final routePoints = segments.expand((segment) => segment);
              for (final point in routePoints) {
                builder.element(
                  'rtept',
                  attributes: {
                    'lat': formatCoordinate(point.lat),
                    'lon': formatCoordinate(point.lon),
                  },
                  nest: () {
                    if (point.ele != null) {
                      builder.element(
                        'ele',
                        nest: point.ele!.toStringAsFixed(2),
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
    return builder.buildDocument().toXmlString(pretty: false);
  }

  String? _extractMetadata(
    XmlDocument document,
    String elementName,
    GpxPointSourceKind sourceKind,
  ) {
    final containerName = sourceKind == GpxPointSourceKind.track
        ? 'trk'
        : 'rte';
    final container = document.findAllElements(containerName).firstOrNull;
    final text = container?.getElement(elementName)?.innerText.trim();
    return text == null || text.isEmpty ? null : text;
  }
}
