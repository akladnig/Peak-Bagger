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
}
