import 'dart:math' as math;

import 'package:slovenia_ortofoto_proxy/src/projection.dart';
import 'package:test/test.dart';

void main() {
  test('tile bounds keep XYZ Y orientation', () {
    final northTile = tileBoundsInWebMercator(
      const TileCoordinate(z: 1, x: 1, y: 0),
    );
    final southTile = tileBoundsInWebMercator(
      const TileCoordinate(z: 1, x: 1, y: 1),
    );

    expect(northTile.maxY, greaterThan(southTile.maxY));
    expect(northTile.minY, greaterThanOrEqualTo(southTile.maxY));
  });

  test('partial-overlap tile keeps exact projected tile extent', () {
    final seedTile = _tileForLatLng(
      latitude: 46.0,
      longitude: 13.35,
      zoom: 10,
    );
    final tile = _findPartialOverlapTile(seedTile);

    final bounds = projectTileBoundsToSloveniaCrs(tile);

    expect(bounds.intersects(sloveniaCoverageBounds), isTrue);
    expect(bounds.minX, lessThan(sloveniaCoverageBounds.minX));
    expect(bounds.maxX, greaterThan(sloveniaCoverageBounds.minX));
  });
}

TileCoordinate _tileForLatLng({
  required double latitude,
  required double longitude,
  required int zoom,
}) {
  final tileCount = 1 << zoom;
  final x = ((longitude + 180) / 360 * tileCount).floor();
  final latitudeRadians = latitude * math.pi / 180;
  final mercatorY =
      (1 - math.log(math.tan(latitudeRadians) + 1 / math.cos(latitudeRadians)) / math.pi) /
      2;
  final y = (mercatorY * tileCount).floor();
  return TileCoordinate(z: zoom, x: x, y: y);
}

TileCoordinate _findPartialOverlapTile(TileCoordinate seed) {
  for (var dx = -2; dx <= 2; dx++) {
    for (var dy = -2; dy <= 2; dy++) {
      final candidate = TileCoordinate(
        z: seed.z,
        x: seed.x + dx,
        y: seed.y + dy,
      );
      final bounds = projectTileBoundsToSloveniaCrs(candidate);
      final overlapsWestEdge =
          bounds.intersects(sloveniaCoverageBounds) &&
          bounds.minX < sloveniaCoverageBounds.minX &&
          bounds.maxX > sloveniaCoverageBounds.minX;
      if (overlapsWestEdge) {
        return candidate;
      }
    }
  }

  throw StateError('No partial-overlap tile found near Slovenia west edge');
}
