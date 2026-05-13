import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/tile_cache_download_scope.dart';

void main() {
  test('selectInitialTileCacheMap uses name sort', () {
    final map = selectInitialTileCacheMap([
      _map(name: 'Zulu'),
      _map(name: 'Alpha'),
    ]);

    expect(map?.name, 'Alpha');
  });

  test('selectInitialTileCacheMap returns null when empty', () {
    expect(selectInitialTileCacheMap(const []), isNull);
  });

  test('buildTileCacheDownloadRegion preserves exact polygon points', () {
    final points = [
      const LatLng(-41.0, 146.0),
      const LatLng(-41.1, 146.5),
      const LatLng(-41.2, 146.2),
      const LatLng(-41.0, 146.0),
    ];

    final region = buildTileCacheDownloadRegion(
      polygonPoints: points,
      minZoom: 6,
      maxZoom: 14,
      options: TileLayer(),
    );

    expect(region.minZoom, 6);
    expect(region.maxZoom, 14);
    expect(region.originalRegion, isA<CustomPolygonRegion>());
    expect(region.originalRegion.outline, points);
  });
}

Tasmap50k _map({required String name, String series = 'TS07'}) {
  return Tasmap50k(
    series: series,
    name: name,
    parentSeries: '8211',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}
