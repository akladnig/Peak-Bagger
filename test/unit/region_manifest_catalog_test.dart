import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';

void main() {
  test('Basemap.values keeps the manifest-prescribed order', () {
    expect(
      Basemap.values.map((basemap) => basemap.name).toList(growable: false),
      const [
        'tasmapTopo',
        'tasmap50k',
        'tasmap25k',
        'tracestrack',
        'openstreetmap',
        'nswImagery',
        'nswBasemap',
        'nswTopo',
        'sloveniaOrtofoto',
      ],
    );
  });

  test('region lookup resolves regions and misses cleanly', () {
    expect(
      regionManifestCatalog.regionKeyForPoint(const LatLng(-44.0, 148.8867)),
      'tasmania',
    );
    expect(regionManifestCatalog.regionKeyForPoint(const LatLng(0, 0)), isNull);
  });

  test('region basemaps stay ordered and deduped', () {
    expect(
      regionManifestCatalog
          .basemapsForRegionKey('new-south-wales')
          .map((basemap) => basemap.key)
          .toList(growable: false),
      const [
        'openstreetmap',
        'tracestrack',
        'nswImagery',
        'nswBasemap',
        'nswTopo',
      ],
    );
    expect(
      regionManifestCatalog
          .basemapsForRegionKey('tasmania')
          .map((basemap) => basemap.key)
          .toList(growable: false),
      const [
        'openstreetmap',
        'tracestrack',
        'tasmapTopo',
        'tasmap50k',
        'tasmap25k',
      ],
    );
  });

  test('mapTileUrl reads from the manifest catalog', () {
    expect(
      mapTileUrl(Basemap.tasmap50k),
      regionManifestCatalog.basemapByKey('tasmap50k')!.tileUrl,
    );
    expect(
      mapTileUrl(Basemap.nswTopo),
      regionManifestCatalog.basemapByKey('nswTopo')!.tileUrl,
    );
  });
}
