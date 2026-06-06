import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

void main() {
  test('returns true for a point inside a square and false outside', () {
    final square = const [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];

    expect(polygonContainsPoint(const LatLng(1, 1), square), isTrue);
    expect(polygonContainsPoint(const LatLng(3, 3), square), isFalse);
  });

  test('counts points on an edge or vertex as inside', () {
    final square = const [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];

    expect(polygonContainsPoint(const LatLng(0, 1), square), isTrue);
    expect(polygonContainsPoint(const LatLng(0, 0), square), isTrue);
  });

  test('counts points on a shared vertical boundary as inside', () {
    final rectangle = const [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];

    expect(polygonContainsPoint(const LatLng(1, 2), rectangle), isTrue);
  });

  test('treats open and explicitly closed rings identically', () {
    final openRing = const [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
    ];
    final closedRing = const [
      LatLng(0, 0),
      LatLng(0, 2),
      LatLng(2, 2),
      LatLng(2, 0),
      LatLng(0, 0),
    ];

    expect(polygonContainsPoint(const LatLng(1, 1), openRing), isTrue);
    expect(polygonContainsPoint(const LatLng(1, 1), closedRing), isTrue);
    expect(polygonContainsPoint(const LatLng(3, 3), openRing), isFalse);
    expect(polygonContainsPoint(const LatLng(3, 3), closedRing), isFalse);
  });

  test('handles concave polygons correctly', () {
    final concave = const [
      LatLng(0, 0),
      LatLng(0, 4),
      LatLng(4, 4),
      LatLng(4, 0),
      LatLng(2, 0),
      LatLng(2, 2),
      LatLng(1, 2),
      LatLng(1, 0),
    ];

    expect(polygonContainsPoint(const LatLng(3, 3), concave), isTrue);
    expect(polygonContainsPoint(const LatLng(1.5, 1.5), concave), isFalse);
  });

  test('throws ArgumentError for empty and underspecified rings', () {
    expect(
      () => polygonContainsPoint(const LatLng(0, 0), const []),
      throwsArgumentError,
    );
    expect(
      () => polygonContainsPoint(const LatLng(0, 0), const [
        LatLng(0, 0),
        LatLng(1, 1),
      ]),
      throwsArgumentError,
    );
    expect(
      () => polygonContainsPoint(const LatLng(0, 0), const [
        LatLng(0, 0),
        LatLng(1, 1),
        LatLng(0, 0),
      ]),
      throwsArgumentError,
    );
  });

  test('parses the bundled tasmania polygon into generic vertices', () async {
    final contents = await File('assets/polygons/tasmania.poly').readAsString();

    final result = parsePolygonText(contents);

    expect(result.isSuccess, isTrue);
    expect(result.polygon!.name, 'none');
    expect(result.polygon!.vertices, hasLength(8));
    expect(result.polygon!.vertices.first, const LatLng(-44.0, 148.8867));
  });

  test('rejects malformed polygon text inputs', () {
    final malformedCoordinate = parsePolygonText(
      'none\n1\ninvalid line\nEND\nEND\n',
    );
    final missingEnd = parsePolygonText('none\n1\n0 0\n1 0\n1 1\n');
    final emptyRing = parsePolygonText('none\n1\nEND\nEND\n');
    final extraRing = parsePolygonText(
      'none\n1\n0 0\n1 0\n1 1\n0 0\nEND\n2\n2 2\nEND\nEND\n',
    );

    expect(malformedCoordinate.isSuccess, isFalse);
    expect(malformedCoordinate.error, contains('invalid coordinate line'));
    expect(missingEnd.isSuccess, isFalse);
    expect(missingEnd.error, contains('missing the end of the first ring'));
    expect(emptyRing.isSuccess, isFalse);
    expect(emptyRing.error, contains('complete ring'));
    expect(extraRing.isSuccess, isFalse);
    expect(extraRing.error, contains('unsupported additional rings'));
  });

  test(
    'parsed tasmania vertices interoperate with containment checks',
    () async {
      final contents = await File(
        'assets/polygons/tasmania.poly',
      ).readAsString();
      final result = parsePolygonText(contents);

      expect(result.isSuccess, isTrue);
      expect(
        polygonContainsPoint(
          const LatLng(-42.896016, 147.237306),
          result.polygon!.vertices,
        ),
        isTrue,
      );
      expect(
        polygonContainsPoint(
          const LatLng(-33.865143, 151.209900),
          result.polygon!.vertices,
        ),
        isFalse,
      );
    },
  );
}
