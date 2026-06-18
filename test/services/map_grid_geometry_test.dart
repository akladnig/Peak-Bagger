import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/services/map_grid_geometry.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';

void main() {
  test('builds 1 km grid lines with edge labels', () {
    final geometry = buildMapMgrsGridGeometry(
      visibleBounds: _boundsFromUtm(
        westEasting: 440000,
        eastEasting: 445000,
        southNorthing: 5399000,
        northNorthing: 5404000,
      ),
      interval: MapMgrsGridInterval.oneKilometer,
    );

    expect(geometry.lines, isNotEmpty);
    expect(geometry.labels, isNotEmpty);
    expect(
      geometry.labels.where((label) => label.side == MapGridLabelSide.top),
      isNotEmpty,
    );
    expect(
      geometry.labels.where((label) => label.side == MapGridLabelSide.bottom),
      isNotEmpty,
    );
    expect(
      geometry.labels.where((label) => label.side == MapGridLabelSide.left),
      isNotEmpty,
    );
    expect(
      geometry.labels.where((label) => label.side == MapGridLabelSide.right),
      isNotEmpty,
    );
    for (final label in geometry.labels) {
      expect(label.label, matches(r'^\d{2}$'));
    }
  });

  test('suppresses edge labels for 10 km, 100 km, and 1000 km intervals', () {
    final visibleBounds = _boundsFromUtm(
      westEasting: 440000,
      eastEasting: 480000,
      southNorthing: 5390000,
      northNorthing: 5430000,
    );

    expect(
      buildMapMgrsGridGeometry(
        visibleBounds: visibleBounds,
        interval: MapMgrsGridInterval.tenKilometers,
      ).labels,
      isEmpty,
    );
    expect(
      buildMapMgrsGridGeometry(
        visibleBounds: visibleBounds,
        interval: MapMgrsGridInterval.hundredKilometers,
      ).labels,
      isEmpty,
    );
    expect(
      buildMapMgrsGridGeometry(
        visibleBounds: visibleBounds,
        interval: MapMgrsGridInterval.thousandKilometers,
      ).labels,
      isEmpty,
    );
  });

  test('trims gridlines away from border labels when requested', () {
    final visibleBounds = _boundsFromUtm(
      westEasting: 440000,
      eastEasting: 445000,
      southNorthing: 5399000,
      northNorthing: 5404000,
    );

    final untrimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
    );
    final trimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
      verticalLabelInsetMeters: 1000,
      horizontalLabelWestInsetMeters: 1000,
      horizontalLabelEastInsetMeters: 1000,
    );

    expect(
      trimmed.lines.first.first.latitude,
      greaterThan(untrimmed.lines.first.first.latitude),
    );
    expect(
      trimmed.lines.first.last.latitude,
      lessThan(untrimmed.lines.first.last.latitude),
    );
    expect(
      trimmed.labels.first.anchor.latitude,
      lessThan(trimmed.lines.first.first.latitude),
    );
    expect(
      trimmed.labels[1].anchor.latitude,
      greaterThan(trimmed.lines.first.last.latitude),
    );
  });

  test('trims the east side of horizontal gridlines independently', () {
    final visibleBounds = _boundsFromUtm(
      westEasting: 440000,
      eastEasting: 445000,
      southNorthing: 5399000,
      northNorthing: 5404000,
    );

    final untrimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
    );
    final trimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
      horizontalLabelEastInsetMeters: 1000,
    );

    final untrimmedHorizontal = untrimmed.lines.firstWhere(
      (line) =>
          (line.last.longitude - line.first.longitude).abs() >
          (line.last.latitude - line.first.latitude).abs(),
    );
    final trimmedHorizontal = trimmed.lines.firstWhere(
      (line) =>
          (line.last.longitude - line.first.longitude).abs() >
          (line.last.latitude - line.first.latitude).abs(),
    );

    expect(
      trimmedHorizontal.last.longitude,
      lessThan(untrimmedHorizontal.last.longitude),
    );
    expect(
      trimmedHorizontal.first.longitude,
      equals(untrimmedHorizontal.first.longitude),
    );
  });

  test('trims the eastmost vertical easting away from the FAB rail', () {
    final visibleBounds = _boundsFromUtm(
      westEasting: 440000,
      eastEasting: 445000,
      southNorthing: 5399000,
      northNorthing: 5404000,
    );

    final untrimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
    );
    final trimmed = buildMapMgrsGridGeometry(
      visibleBounds: visibleBounds,
      interval: MapMgrsGridInterval.oneKilometer,
      verticalLineRightInsetMeters: 1000,
    );

    final untrimmedVertical = untrimmed.lines
        .where(
          (line) =>
              (line.last.latitude - line.first.latitude).abs() >
              (line.last.longitude - line.first.longitude).abs(),
        )
        .reduce((a, b) => a.first.longitude > b.first.longitude ? a : b);
    final trimmedVertical = trimmed.lines
        .where(
          (line) =>
              (line.last.latitude - line.first.latitude).abs() >
              (line.last.longitude - line.first.longitude).abs(),
        )
        .reduce((a, b) => a.first.longitude > b.first.longitude ? a : b);

    expect(
      trimmedVertical.first.longitude,
      lessThan(untrimmedVertical.first.longitude),
    );
  });

  test('fails closed for unusable bounds', () {
    final geometry = buildMapMgrsGridGeometry(
      visibleBounds: LatLngBounds(
        const LatLng(-41.5, 146.5),
        const LatLng(-41.5, 146.5),
      ),
      interval: MapMgrsGridInterval.oneKilometer,
    );

    expect(geometry.isEmpty, isTrue);
  });
}

LatLngBounds _boundsFromUtm({
  required int westEasting,
  required int eastEasting,
  required int southNorthing,
  required int northNorthing,
}) {
  final southWest = _latLngFromUtm(westEasting, southNorthing);
  final northWest = _latLngFromUtm(westEasting, northNorthing);
  final southEast = _latLngFromUtm(eastEasting, southNorthing);
  final northEast = _latLngFromUtm(eastEasting, northNorthing);
  return LatLngBounds.fromPoints([southWest, northWest, southEast, northEast]);
}

LatLng _latLngFromUtm(int easting, int northing) {
  final utm = mgrs.UTM(
    easting: easting.toDouble(),
    northing: northing.toDouble(),
    zoneLetter: 'G',
    zoneNumber: 55,
  );
  final coords = mgrs.Mgrs.toPoint(mgrs.Mgrs.encode(utm, 5));
  return LatLng(coords[1], coords[0]);
}
