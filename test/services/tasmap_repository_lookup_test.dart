import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mgrs_dart/mgrs_dart.dart' as mgrs;
import 'package:peak_bagger/models/tasmap50k.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('findByPoint resolves a point clearly inside a polygon', () async {
    final map = _polygonMap(
      id: 1,
      name: 'Inside Map',
      series: 'TS01',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0100),
        LatLng(-42.0100, 146.0100),
        LatLng(-42.0100, 146.0000),
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [map]);

    final resolved = repository.findByPoint(const LatLng(-42.0050, 146.0050));

    expect(resolved?.name, 'Inside Map');
  });

  test('findByPoint rejects a rectangle false-positive outside the polygon', () async {
    final map = _polygonMap(
      id: 1,
      name: 'Triangle Map',
      series: 'TS01',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0200),
        LatLng(-42.0200, 146.0000),
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [map]);

    final resolved = repository.findByPoint(const LatLng(-42.0150, 146.0150));

    expect(resolved, isNull);
  });

  test('findByPoint uses deterministic ordering when multiple polygons match', () async {
    final alpha = _polygonMap(
      id: 2,
      name: 'Alpha Map',
      series: 'TS02',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0200),
        LatLng(-42.0200, 146.0200),
        LatLng(-42.0100, 146.0000),
      ],
    );
    final beta = _polygonMap(
      id: 1,
      name: 'Beta Map',
      series: 'TS01',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0200),
        LatLng(-42.0200, 146.0200),
        LatLng(-42.0100, 146.0000),
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [beta, alpha]);

    final resolved = repository.findByPoint(const LatLng(-42.0050, 146.0050));

    expect(resolved?.name, 'Alpha Map');
  });

  test('findByMgrsCodeAndCoordinates delegates through polygon lookup', () async {
    final map = _polygonMap(
      id: 1,
      name: 'Delegated Map',
      series: 'TS01',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0100),
        LatLng(-42.0100, 146.0100),
        LatLng(-42.0100, 146.0000),
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [map]);
    final point = const LatLng(-42.0050, 146.0050);

    final resolved = repository.findByMgrsCodeAndCoordinates(_fullMgrs(point));

    expect(resolved?.name, 'Delegated Map');
  });

  test('addMaps invalidates cached lookup geometry', () async {
    final existing = _polygonMap(
      id: 1,
      name: 'Existing Map',
      series: 'TS01',
      vertices: const [
        LatLng(-42.0000, 146.0000),
        LatLng(-42.0000, 146.0100),
        LatLng(-42.0100, 146.0100),
        LatLng(-42.0100, 146.0000),
      ],
    );
    final added = _polygonMap(
      id: 2,
      name: 'Added Map',
      series: 'TS02',
      vertices: const [
        LatLng(-42.0200, 146.0200),
        LatLng(-42.0200, 146.0300),
        LatLng(-42.0300, 146.0300),
        LatLng(-42.0300, 146.0200),
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [existing]);
    const addedPoint = LatLng(-42.0250, 146.0250);

    expect(repository.findByPoint(addedPoint), isNull);

    await repository.addMaps([added]);

    expect(repository.findByPoint(addedPoint)?.name, 'Added Map');
  });
}

Tasmap50k _polygonMap({
  required int id,
  required String name,
  required String series,
  required List<LatLng> vertices,
}) {
  final pointStrings = vertices.map(_pointString).toList(growable: false);
  final mgrsCodes = pointStrings
      .map((point) => point.substring(0, 2))
      .toSet()
      .join(' ');

  return Tasmap50k(
    id: id,
    series: series,
    name: name,
    parentSeries: 'parent',
    mgrs100kIds: mgrsCodes,
    eastingMin: 0,
    eastingMax: 99999,
    northingMin: 0,
    northingMax: 99999,
    p1: _pointAt(pointStrings, 0),
    p2: _pointAt(pointStrings, 1),
    p3: _pointAt(pointStrings, 2),
    p4: _pointAt(pointStrings, 3),
    p5: _pointAt(pointStrings, 4),
    p6: _pointAt(pointStrings, 5),
    p7: _pointAt(pointStrings, 6),
    p8: _pointAt(pointStrings, 7),
    p9: _pointAt(pointStrings, 8),
    p10: _pointAt(pointStrings, 9),
    p11: _pointAt(pointStrings, 10),
    p12: _pointAt(pointStrings, 11),
  );
}

String _pointAt(List<String> points, int index) {
  return index < points.length ? points[index] : '';
}

String _pointString(LatLng point) {
  return _fullMgrs(point).replaceAll(RegExp(r'[\n\s]'), '').substring(3);
}

String _fullMgrs(LatLng point) {
  return mgrs.Mgrs.forward([point.longitude, point.latitude], 5);
}
