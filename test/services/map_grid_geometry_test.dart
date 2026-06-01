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

  test('suppresses edge labels for 10 km and 100 km intervals', () {
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
