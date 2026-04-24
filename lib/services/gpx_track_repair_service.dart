import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class RepairResult {
  const RepairResult({
    required this.repairedXml,
    required this.repairPerformed,
    required this.gapCount,
    required this.interpolatedSegmentCount,
    this.warning,
  });

  final String repairedXml;
  final bool repairPerformed;
  final int gapCount;
  final int interpolatedSegmentCount;
  final String? warning;
}

class GpxTrackRepairService {
  const GpxTrackRepairService({
    this.distanceMeters = 50,
    this.gapSeconds = 60,
  });

  static const _distance = Distance();

  final double distanceMeters;
  final int gapSeconds;

  RepairResult analyzeAndRepair(String gpxXml) {
    try {
      final document = XmlDocument.parse(gpxXml);
      if (_hasInterpolatedSegment(document)) {
        return RepairResult(
          repairedXml: gpxXml,
          repairPerformed: false,
          gapCount: 0,
          interpolatedSegmentCount: 0,
        );
      }

      final tracks = document.findAllElements('trk').toList(growable: false);
      if (tracks.isEmpty) {
        return RepairResult(
          repairedXml: gpxXml,
          repairPerformed: false,
          gapCount: 0,
          interpolatedSegmentCount: 0,
        );
      }

      final trackSegments = <List<_SegmentInfo>>[];
      var hasAnyTimestamp = false;

      for (final track in tracks) {
        final segments = <_SegmentInfo>[];
        var childIndex = 0;
        for (final child in track.children) {
          if (child is! XmlElement || child.name.local != 'trkseg') {
            childIndex++;
            continue;
          }

          final points = _extractPoints(child.findElements('trkpt'));
          final timedPoints = points
              .where((point) => point.timeLocal != null)
              .toList(growable: false);
          if (timedPoints.isNotEmpty) {
            hasAnyTimestamp = true;
          }

          segments.add(
            _SegmentInfo(
              childIndex: childIndex,
              firstTimedPoint:
                  timedPoints.isEmpty ? null : timedPoints.first,
              lastTimedPoint: timedPoints.isEmpty ? null : timedPoints.last,
            ),
          );
          childIndex++;
        }

        trackSegments.add(segments);
      }

      if (!hasAnyTimestamp) {
        return RepairResult(
          repairedXml: gpxXml,
          repairPerformed: false,
          gapCount: 0,
          interpolatedSegmentCount: 0,
          warning: 'No timestamps found; skipping repair.',
        );
      }

      final repairedDocument = document.copy();
      final repairedTracks = repairedDocument.findAllElements('trk').toList(
        growable: false,
      );

      var gapCount = 0;
      var interpolatedSegmentCount = 0;

      for (var trackIndex = 0; trackIndex < trackSegments.length; trackIndex++) {
        final segments = trackSegments[trackIndex];
        if (segments.length < 2) {
          continue;
        }

        final insertions = <_SegmentInsertion>[];
        for (var i = 0; i < segments.length - 1; i++) {
          final current = segments[i];
          final next = segments[i + 1];
          final currentLast = current.lastTimedPoint;
          final nextFirst = next.firstTimedPoint;

          if (currentLast == null || nextFirst == null) {
            continue;
          }

          final gap = nextFirst.timeLocal!
              .difference(currentLast.timeLocal!)
              .inSeconds;
          if (gap <= gapSeconds) {
            continue;
          }

          gapCount += 1;
          final distance = _distance.as(
            LengthUnit.Meter,
            currentLast.location,
            nextFirst.location,
          );
          if (distance > distanceMeters) {
            interpolatedSegmentCount += 1;
            insertions.add(
              _SegmentInsertion(
                childIndex: current.childIndex,
                segment: _buildInterpolatedSegment(
                  currentLast.element,
                  nextFirst.element,
                ),
              ),
            );
          }
        }

        final trackCopy = repairedTracks[trackIndex];
        for (final insertion in insertions.reversed) {
          trackCopy.children.insert(insertion.childIndex + 1, insertion.segment);
        }
      }

      if (interpolatedSegmentCount == 0) {
        return RepairResult(
          repairedXml: gpxXml,
          repairPerformed: false,
          gapCount: gapCount,
          interpolatedSegmentCount: 0,
        );
      }

      return RepairResult(
        repairedXml: repairedDocument.toXmlString(pretty: false),
        repairPerformed: true,
        gapCount: gapCount,
        interpolatedSegmentCount: interpolatedSegmentCount,
      );
    } on XmlException {
      return RepairResult(
        repairedXml: gpxXml,
        repairPerformed: false,
        gapCount: 0,
        interpolatedSegmentCount: 0,
        warning: 'Invalid GPX XML',
      );
    }
  }

  bool _hasInterpolatedSegment(XmlDocument document) {
    return document.findAllElements('trkseg').any((segment) {
      final typeElement = segment.getElement('type');
      return typeElement != null &&
          typeElement.innerText.trim().toLowerCase() == 'interpolated';
    });
  }

  List<_TrackPoint> _extractPoints(Iterable<XmlElement> elements) {
    final points = <_TrackPoint>[];
    for (final element in elements) {
      final lat = double.tryParse(element.getAttribute('lat') ?? '');
      final lon = double.tryParse(element.getAttribute('lon') ?? '');
      if (lat == null || lon == null) {
        continue;
      }

      final timeText = element.getElement('time')?.innerText.trim();
      DateTime? timeLocal;
      if (timeText != null && timeText.isNotEmpty) {
        try {
          timeLocal = DateTime.parse(timeText).toLocal();
        } catch (_) {
          timeLocal = null;
        }
      }

      points.add(
        _TrackPoint(
          element: element,
          location: LatLng(lat, lon),
          timeLocal: timeLocal,
        ),
      );
    }
    return points;
  }

  XmlElement _buildInterpolatedSegment(
    XmlElement previousPoint,
    XmlElement nextPoint,
  ) {
    return XmlElement.tag(
      'trkseg',
      children: [
        XmlElement.tag(
          'type',
          children: [XmlText('interpolated')],
          isSelfClosing: false,
        ),
        previousPoint.copy(),
        nextPoint.copy(),
      ],
      isSelfClosing: false,
    );
  }
}

class _TrackPoint {
  const _TrackPoint({
    required this.element,
    required this.location,
    required this.timeLocal,
  });

  final XmlElement element;
  final LatLng location;
  final DateTime? timeLocal;
}

class _SegmentInfo {
  const _SegmentInfo({
    required this.childIndex,
    required this.firstTimedPoint,
    required this.lastTimedPoint,
  });

  final int childIndex;
  final _TrackPoint? firstTimedPoint;
  final _TrackPoint? lastTimedPoint;
}

class _SegmentInsertion {
  const _SegmentInsertion({
    required this.childIndex,
    required this.segment,
  });

  final int childIndex;
  final XmlElement segment;
}
