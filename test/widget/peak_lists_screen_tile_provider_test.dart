import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/screens/peak_lists_screen.dart';

void main() {
  test('buildPeakListMiniMapTileProvider prefers cache when available', () {
    expect(
      buildPeakListMiniMapTileProvider(cacheAvailable: false),
      isA<NetworkTileProvider>(),
    );
    expect(
      buildPeakListMiniMapTileProvider(cacheAvailable: true),
      isA<FMTCTileProvider>(),
    );
  });
}
