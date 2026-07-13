import 'dart:math' as math;

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;

import 'package:peak_bagger/services/map_ruler_scale.dart';

enum MapGridLabelSide { top, bottom, left, right }

class MapGridBorderLabel {
  const MapGridBorderLabel({
    required this.anchor,
    required this.label,
    required this.side,
  });

  final LatLng anchor;
  final String label;
  final MapGridLabelSide side;
}

class MapMgrsGridGeometry {
  const MapMgrsGridGeometry({this.lines = const [], this.labels = const []});

  final List<List<LatLng>> lines;
  final List<MapGridBorderLabel> labels;

  bool get isEmpty => lines.isEmpty && labels.isEmpty;
}

class _MapMgrsGridLine {
  const _MapMgrsGridLine({
    required this.points,
    required this.startAnchor,
    required this.endAnchor,
  });

  final List<LatLng> points;
  final LatLng startAnchor;
  final LatLng endAnchor;
}

class _MapMgrsGridZoneSlice {
  const _MapMgrsGridZoneSlice({required this.zoneNumber, required this.bounds});

  final int zoneNumber;
  final LatLngBounds bounds;
}

const _lineSampleCount = 16;
const _zoneBoundaryLongitudeEpsilon = 0.000001;

MapMgrsGridGeometry buildMapMgrsGridGeometry({
  required LatLngBounds visibleBounds,
  required MapMgrsGridInterval interval,
  double verticalLabelInsetMeters = 0,
  double verticalLineRightInsetMeters = 0,
  double horizontalLabelWestInsetMeters = 0,
  double horizontalLabelEastInsetMeters = 0,
}) {
  if (!_hasUsableBounds(visibleBounds)) {
    return const MapMgrsGridGeometry();
  }

  try {
    final lines = <List<LatLng>>[];
    final labels = <MapGridBorderLabel>[];
    final intervalMeters = interval.meters;
    final showBorderLabels = interval == MapMgrsGridInterval.oneKilometer;

    for (final slice in _zoneSlicesForBounds(visibleBounds)) {
      final corners = [
        LatLng(slice.bounds.south, slice.bounds.west),
        LatLng(slice.bounds.north, slice.bounds.west),
        LatLng(slice.bounds.south, slice.bounds.east),
        LatLng(slice.bounds.north, slice.bounds.east),
      ];
      final utmCorners = corners.map(_utmFromLatLng).toList(growable: false);
      final minEasting = utmCorners.map((utm) => utm.easting).reduce(math.min);
      final maxEasting = utmCorners.map((utm) => utm.easting).reduce(math.max);
      final minNorthing = utmCorners
          .map((utm) => utm.northing)
          .reduce(math.min);
      final maxNorthing = utmCorners
          .map((utm) => utm.northing)
          .reduce(math.max);

      final startEasting = _alignedStart(minEasting, intervalMeters);
      final endEasting = _alignedEnd(
        maxEasting - verticalLineRightInsetMeters,
        intervalMeters,
      );
      for (
        var easting = startEasting;
        easting <= endEasting;
        easting += intervalMeters
      ) {
        final line = _buildVerticalLine(
          easting: easting.toDouble(),
          minNorthing: minNorthing,
          maxNorthing: maxNorthing,
          zoneNumber: slice.zoneNumber,
          southLatitude: slice.bounds.south,
          northLatitude: slice.bounds.north,
          labelInsetMeters: verticalLabelInsetMeters,
        );
        if (line.points.isEmpty) {
          continue;
        }
        lines.add(line.points);
        if (showBorderLabels) {
          final label = _twoDigitGridLabel(easting);
          labels.add(
            MapGridBorderLabel(
              anchor: line.startAnchor,
              label: label,
              side: MapGridLabelSide.bottom,
            ),
          );
          labels.add(
            MapGridBorderLabel(
              anchor: line.endAnchor,
              label: label,
              side: MapGridLabelSide.top,
            ),
          );
        }
      }

      final startNorthing = _alignedStart(minNorthing, intervalMeters);
      final endNorthing = _alignedEnd(maxNorthing, intervalMeters);
      for (
        var northing = startNorthing;
        northing <= endNorthing;
        northing += intervalMeters
      ) {
        final line = _buildHorizontalLine(
          northing: northing.toDouble(),
          minEasting: minEasting,
          maxEasting: maxEasting,
          zoneNumber: slice.zoneNumber,
          southLatitude: slice.bounds.south,
          northLatitude: slice.bounds.north,
          minNorthing: minNorthing,
          maxNorthing: maxNorthing,
          westLabelInsetMeters: horizontalLabelWestInsetMeters,
          eastLabelInsetMeters: horizontalLabelEastInsetMeters,
        );
        if (line.points.isEmpty) {
          continue;
        }
        lines.add(line.points);
        if (showBorderLabels) {
          final label = _twoDigitGridLabel(northing);
          labels.add(
            MapGridBorderLabel(
              anchor: line.startAnchor,
              label: label,
              side: MapGridLabelSide.left,
            ),
          );
          labels.add(
            MapGridBorderLabel(
              anchor: line.endAnchor,
              label: label,
              side: MapGridLabelSide.right,
            ),
          );
        }
      }
    }

    return MapMgrsGridGeometry(lines: lines, labels: labels);
  } catch (_) {
    return const MapMgrsGridGeometry();
  }
}

bool _hasUsableBounds(LatLngBounds visibleBounds) {
  return visibleBounds.south.isFinite &&
      visibleBounds.north.isFinite &&
      visibleBounds.west.isFinite &&
      visibleBounds.east.isFinite &&
      visibleBounds.south < visibleBounds.north &&
      visibleBounds.west < visibleBounds.east;
}

int _alignedStart(double value, int intervalMeters) =>
    (value / intervalMeters).ceil() * intervalMeters;

int _alignedEnd(double value, int intervalMeters) =>
    (value / intervalMeters).floor() * intervalMeters;

_MapMgrsGridLine _buildVerticalLine({
  required double easting,
  required double minNorthing,
  required double maxNorthing,
  required int zoneNumber,
  required double southLatitude,
  required double northLatitude,
  required double labelInsetMeters,
}) {
  final inset = labelInsetMeters
      .clamp(0.0, (maxNorthing - minNorthing) / 2)
      .toDouble();
  final points = <LatLng>[];
  final lineSouthNorthing = minNorthing + inset;
  final lineNorthNorthing = maxNorthing - inset;
  for (var i = 0; i < _lineSampleCount; i++) {
    final t = i / (_lineSampleCount - 1);
    final northing = _lerp(lineSouthNorthing, lineNorthNorthing, t);
    final latitudeGuess = _lerp(southLatitude, northLatitude, t);
    points.add(
      _latLngFromUtm(
        easting: easting,
        northing: northing,
        zoneNumber: zoneNumber,
        zoneLetter: _utmZoneLetterForLatitude(latitudeGuess),
      ),
    );
  }

  return _MapMgrsGridLine(
    points: points,
    startAnchor: _latLngFromUtm(
      easting: easting,
      northing: minNorthing,
      zoneNumber: zoneNumber,
      zoneLetter: _utmZoneLetterForLatitude(southLatitude),
    ),
    endAnchor: _latLngFromUtm(
      easting: easting,
      northing: maxNorthing,
      zoneNumber: zoneNumber,
      zoneLetter: _utmZoneLetterForLatitude(northLatitude),
    ),
  );
}

_MapMgrsGridLine _buildHorizontalLine({
  required double northing,
  required double minEasting,
  required double maxEasting,
  required int zoneNumber,
  required double southLatitude,
  required double northLatitude,
  required double minNorthing,
  required double maxNorthing,
  required double westLabelInsetMeters,
  required double eastLabelInsetMeters,
}) {
  final westInset = westLabelInsetMeters
      .clamp(0.0, (maxEasting - minEasting) / 2)
      .toDouble();
  final eastInset = eastLabelInsetMeters
      .clamp(0.0, (maxEasting - minEasting) / 2)
      .toDouble();
  final points = <LatLng>[];
  final latitudeGuess = _lerp(
    southLatitude,
    northLatitude,
    maxNorthing == minNorthing
        ? 0
        : (northing - minNorthing) / (maxNorthing - minNorthing),
  ).clamp(southLatitude, northLatitude).toDouble();
  final zoneLetter = _utmZoneLetterForLatitude(latitudeGuess);
  final lineWestEasting = minEasting + westInset;
  final lineEastEasting = maxEasting - eastInset;
  for (var i = 0; i < _lineSampleCount; i++) {
    final t = i / (_lineSampleCount - 1);
    final easting = _lerp(lineWestEasting, lineEastEasting, t);
    points.add(
      _latLngFromUtm(
        easting: easting,
        northing: northing,
        zoneNumber: zoneNumber,
        zoneLetter: zoneLetter,
      ),
    );
  }

  return _MapMgrsGridLine(
    points: points,
    startAnchor: _latLngFromUtm(
      easting: minEasting,
      northing: northing,
      zoneNumber: zoneNumber,
      zoneLetter: zoneLetter,
    ),
    endAnchor: _latLngFromUtm(
      easting: maxEasting,
      northing: northing,
      zoneNumber: zoneNumber,
      zoneLetter: zoneLetter,
    ),
  );
}

double _lerp(double start, double end, double t) => start + (end - start) * t;

mgrs.UTM _utmFromLatLng(LatLng point) {
  final mgrsValue = mgrs.Mgrs.forward([point.longitude, point.latitude], 5);
  return mgrs.Mgrs.decode(mgrsValue);
}

LatLng _latLngFromUtm({
  required double easting,
  required double northing,
  required int zoneNumber,
  required String zoneLetter,
}) {
  final utm = mgrs.UTM(
    easting: easting,
    northing: northing,
    zoneLetter: zoneLetter,
    zoneNumber: zoneNumber,
  );
  final coords = mgrs.Mgrs.toPoint(mgrs.Mgrs.encode(utm, 5));
  return LatLng(coords[1], coords[0]);
}

int _utmZoneNumberForLongitude(double longitude) =>
    (((longitude + 180) / 6).floor() + 1).clamp(1, 60);

List<_MapMgrsGridZoneSlice> _zoneSlicesForBounds(LatLngBounds visibleBounds) {
  final startZone = _utmZoneNumberForLongitude(visibleBounds.west);
  final endZone = _utmZoneNumberForLongitude(visibleBounds.east);
  final slices = <_MapMgrsGridZoneSlice>[];

  for (var zoneNumber = startZone; zoneNumber <= endZone; zoneNumber++) {
    final zoneWest = -180.0 + (zoneNumber - 1) * 6.0;
    final zoneEast = zoneWest + 6.0;
    var west = math.max(visibleBounds.west, zoneWest);
    var east = math.min(visibleBounds.east, zoneEast);
    if (zoneNumber > startZone) {
      west += _zoneBoundaryLongitudeEpsilon;
    }
    if (zoneNumber < endZone) {
      east -= _zoneBoundaryLongitudeEpsilon;
    }
    if (west >= east) {
      continue;
    }
    slices.add(
      _MapMgrsGridZoneSlice(
        zoneNumber: zoneNumber,
        bounds: LatLngBounds(
          LatLng(visibleBounds.south, west),
          LatLng(visibleBounds.north, east),
        ),
      ),
    );
  }

  return slices;
}

String _utmZoneLetterForLatitude(double latitude) {
  const letters = 'CDEFGHJKLMNPQRSTUVWX';
  final clamped = latitude.clamp(-80.0, 84.0);
  final index = (((clamped + 80) / 8).floor()).clamp(0, letters.length - 1);
  return letters[index];
}

String _twoDigitGridLabel(int absoluteMeters) =>
    ((absoluteMeters ~/ 1000) % 100).toString().padLeft(2, '0');
