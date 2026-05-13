import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../harness/test_tasmap_repository.dart';
import 'tile_cache_robot.dart';

void main() {
  testWidgets('tile cache journey downloads the selected Tasmap polygon', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final alpha = _map(
      name: 'Alpha',
      series: 'TS01',
      points: const [
        'DN6000009999',
        'DN9999909999',
        'DM6000080000',
        'DM9999980000',
      ],
    );
    final zulu = _map(
      name: 'Zulu',
      series: 'TS99',
      points: const [
        'DN6100010000',
        'DN9800099990',
        'DM6100081000',
        'DM9800081000',
      ],
    );
    final repository = await TestTasmapRepository.create(maps: [zulu, alpha]);
    final robot = TileCacheRobot(tester, repository);
    addTearDown(robot.repository.dispose);

    final capturedBasemaps = <Basemap>[];
    late dynamic capturedRegion;

    await robot.pumpApp(
      tileCacheBuilder: (_) => TileCacheSettingsScreen(
        downloadStarter: ({
          required basemap,
          required region,
          required skipExistingTiles,
        }) {
          capturedBasemaps.add(basemap);
          capturedRegion = region;
          expect(skipExistingTiles, isTrue);
          return (
            tileEvents: const Stream<TileEvent>.empty(),
            downloadProgress: const Stream<DownloadProgress>.empty(),
          );
        },
      ),
    );

    await robot.openTileCacheSettings();
    await robot.searchMaps('Zu');
    await robot.selectMapSuggestion(0);
    robot.expectSelectedMap('Zulu');
    robot.expectBasemapSelected(Basemap.openstreetmap);

    await robot.toggleBasemap(Basemap.tracestrack);
    robot.expectBasemapSelected(Basemap.openstreetmap);
    robot.expectBasemapSelected(Basemap.tracestrack);

    await robot.scrollToDownloadButton();
    await robot.tapDownload();

    expect(capturedBasemaps, [Basemap.openstreetmap, Basemap.tracestrack]);
    expect(capturedRegion.originalRegion.outline, repository.getMapPolygonPoints(zulu));
  });
}

Tasmap50k _map({
  required String name,
  required String series,
  required List<String> points,
}) {
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
    p1: points[0],
    p2: points[1],
    p3: points[2],
    p4: points[3],
  );
}
