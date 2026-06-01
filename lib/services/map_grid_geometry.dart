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

const _lineSampleCount = 16;

MapMgrsGridGeometry buildMapMgrsGridGeometry({
  required LatLngBounds visibleBounds,
  required MapMgrsGridInterval interval,
}) {
  if (!_hasUsableBounds(visibleBounds)) {
    return const MapMgrsGridGeometry();
  }

  try {
    final corners = [
      LatLng(visibleBounds.south, visibleBounds.west),
      LatLng(visibleBounds.north, visibleBounds.west),
      LatLng(visibleBounds.south, visibleBounds.east),
      LatLng(visibleBounds.north, visibleBounds.east),
    ];
    final utmCorners = corners.map(_utmFromLatLng).toList(growable: false);
    final minEasting = utmCorners
        .map((utm) => utm.easting)
        .reduce(math.min);
    final maxEasting = utmCorners
        .map((utm) => utm.easting)
        .reduce(math.max);
    final minNorthing = utmCorners
        .map((utm) => utm.northing)
        .reduce(math.min);
    final maxNorthing = utmCorners
        .map((utm) => utm.northing)
        .reduce(math.max);
    final centerLongitude = (visibleBounds.west + visibleBounds.east) / 2;
    final zoneNumber = _utmZoneNumberForLongitude(centerLongitude);
    final lines = <List<LatLng>>[];
    final labels = <MapGridBorderLabel>[];
    final intervalMeters = interval.meters;

    final startEasting = _alignedStart(minEasting, intervalMeters);
    final endEasting = _alignedEnd(maxEasting, intervalMeters);
    for (var easting = startEasting; easting <= endEasting; easting += intervalMeters) {
      final line = _buildVerticalLine(
        easting: easting.toDouble(),
        minNorthing: minNorthing,
        maxNorthing: maxNorthing,
        zoneNumber: zoneNumber,
        southLatitude: visibleBounds.south,
        northLatitude: visibleBounds.north,
      );
      if (line.isEmpty) {
        continue;
      }
      lines.add(line);
      if (interval == MapMgrsGridInterval.oneKilometer) {
        final label = _twoDigitGridLabel(easting);
        labels.add(
          MapGridBorderLabel(
            anchor: line.first,
            label: label,
            side: MapGridLabelSide.bottom,
          ),
        );
        labels.add(
          MapGridBorderLabel(
            anchor: line.last,
            label: label,
            side: MapGridLabelSide.top,
          ),
        );
      }
    }

    final startNorthing = _alignedStart(minNorthing, intervalMeters);
    final endNorthing = _alignedEnd(maxNorthing, intervalMeters);
    for (var northing = startNorthing;
        northing <= endNorthing;
        northing += intervalMeters) {
      final line = _buildHorizontalLine(
        northing: northing.toDouble(),
        minEasting: minEasting,
        maxEasting: maxEasting,
        zoneNumber: zoneNumber,
        southLatitude: visibleBounds.south,
        northLatitude: visibleBounds.north,
        minNorthing: minNorthing,
        maxNorthing: maxNorthing,
      );
      if (line.isEmpty) {
        continue;
      }
      lines.add(line);
      if (interval == MapMgrsGridInterval.oneKilometer) {
        final label = _twoDigitGridLabel(northing);
        labels.add(
          MapGridBorderLabel(
            anchor: line.first,
            label: label,
            side: MapGridLabelSide.left,
          ),
        );
        labels.add(
          MapGridBorderLabel(
            anchor: line.last,
            label: label,
            side: MapGridLabelSide.right,
          ),
        );
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

List<LatLng> _buildVerticalLine({
  required double easting,
  required double minNorthing,
  required double maxNorthing,
  required int zoneNumber,
  required double southLatitude,
  required double northLatitude,
}) {
  final points = <LatLng>[];
  for (var i = 0; i < _lineSampleCount; i++) {
    final t = i / (_lineSampleCount - 1);
    final northing = _lerp(minNorthing, maxNorthing, t);
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
  return points;
}

List<LatLng> _buildHorizontalLine({
  required double northing,
  required double minEasting,
  required double maxEasting,
  required int zoneNumber,
  required double southLatitude,
  required double northLatitude,
  required double minNorthing,
  required double maxNorthing,
}) {
  final points = <LatLng>[];
  final latitudeGuess = _lerp(
    southLatitude,
    northLatitude,
    maxNorthing == minNorthing
        ? 0
        : (northing - minNorthing) / (maxNorthing - minNorthing),
  ).clamp(southLatitude, northLatitude).toDouble();
  final zoneLetter = _utmZoneLetterForLatitude(latitudeGuess);
  for (var i = 0; i < _lineSampleCount; i++) {
    final t = i / (_lineSampleCount - 1);
    final easting = _lerp(minEasting, maxEasting, t);
    points.add(
      _latLngFromUtm(
        easting: easting,
        northing: northing,
        zoneNumber: zoneNumber,
        zoneLetter: zoneLetter,
      ),
    );
  }
  return points;
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

String _utmZoneLetterForLatitude(double latitude) {
  const letters = 'CDEFGHJKLMNPQRSTUVWX';
  final clamped = latitude.clamp(-80.0, 84.0);
  final index = (((clamped + 80) / 8).floor()).clamp(0, letters.length - 1);
  return letters[index];
}

String _twoDigitGridLabel(int absoluteMeters) =>
    ((absoluteMeters ~/ 1000) % 100).toString().padLeft(2, '0');
