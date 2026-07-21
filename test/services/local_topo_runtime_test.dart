import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerLocalTopoRegionKeyValidator(
      (regionKey) => regionManifestCatalog.regionByKey(regionKey) != null,
    );
    localTopoRuntime.resetForTesting();
  });

  tearDown(() {
    localTopoRuntime.resetForTesting();
  });

  test(
    'local tile server base URL parser accepts only http and https roots',
    () {
      expect(
        parseLocalTileServerBaseUrl('http://127.0.0.1:8090')?.toString(),
        'http://127.0.0.1:8090',
      );
      expect(
        parseLocalTileServerBaseUrl('https://tiles.lan.example/')?.toString(),
        'https://tiles.lan.example',
      );

      expect(parseLocalTileServerBaseUrl(''), isNull);
      expect(parseLocalTileServerBaseUrl('ftp://127.0.0.1:8090'), isNull);
      expect(
        parseLocalTileServerBaseUrl('http://127.0.0.1:8090/tasmania'),
        isNull,
      );
      expect(parseLocalTileServerBaseUrl('http://127.0.0.1:8090?x=1'), isNull);
      expect(
        parseLocalTileServerBaseUrl('http://user@example.com:8090'),
        isNull,
      );
    },
  );

  test('capability parser accepts the v1 fixture contract', () {
    final decoded = jsonDecode(
      File('local_topo/tasmania/fixtures/capabilities.json').readAsStringSync(),
    );

    final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
      baseUrl: Uri.parse('http://127.0.0.1:8090'),
      decoded: decoded,
    );

    expect(snapshot.baseUrl.toString(), 'http://127.0.0.1:8090');
    expect(snapshot.regions.map((region) => region.regionKey), ['tasmania']);
    expect(
      snapshot.resolvedTileUrlTemplate(),
      'http://127.0.0.1:8090/tasmania/local-topo/{z}/{x}/{y}.png',
    );
  });

  test(
    'capability parser filters unsupported regions and rejects empty matches',
    () {
      final decoded = {
        'service': 'peak-bagger-local-topo',
        'version': 1,
        'basemaps': [
          {
            'key': 'localTopo',
            'label': 'Local Topo',
            'regions': [
              {
                'regionKey': 'unknown-region',
                'tilePathTemplate': '/unknown/{z}/{x}/{y}.png',
              },
              {
                'regionKey': 'tasmania',
                'tilePathTemplate': '/tasmania/local-topo/{z}/{x}/{y}.png',
              },
            ],
          },
        ],
      };

      final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
        baseUrl: Uri.parse('http://127.0.0.1:8090'),
        decoded: decoded,
      );

      expect(snapshot.regions.map((region) => region.regionKey), ['tasmania']);

      expect(
        () => LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
          baseUrl: Uri.parse('http://127.0.0.1:8090'),
          decoded: {
            'service': 'peak-bagger-local-topo',
            'version': 1,
            'basemaps': [
              {
                'key': 'localTopo',
                'label': 'Local Topo',
                'regions': [
                  {
                    'regionKey': 'tasmania',
                    'tilePathTemplate': 'https://example.com/{z}/{x}/{y}.png',
                  },
                ],
              },
            ],
          },
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'runtime restore only activates snapshots tied to the saved base URL',
    () async {
      final activeSnapshot = LocalTopoCapabilitySnapshot(
        baseUrl: Uri.parse('http://127.0.0.1:8090'),
        regions: const [
          LocalTopoRegionCapability(
            regionKey: 'tasmania',
            tilePathTemplate: '/tasmania/local-topo/{z}/{x}/{y}.png',
          ),
        ],
      );
      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(
          activeSnapshot.toJson(),
        ),
      });

      await localTopoRuntime.restore();

      expect(
        localTopoRuntime.savedBaseUrl?.toString(),
        'http://127.0.0.1:8090',
      );
      expect(localTopoRuntime.hasCapabilitySnapshot, isTrue);
      expect(
        localTopoRuntime.resolvedTileUrlTemplate(),
        'http://127.0.0.1:8090/tasmania/local-topo/{z}/{x}/{y}.png',
      );

      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8091',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(
          activeSnapshot.toJson(),
        ),
      });
      localTopoRuntime.resetForTesting();

      await localTopoRuntime.restore();

      expect(
        localTopoRuntime.savedBaseUrl?.toString(),
        'http://127.0.0.1:8091',
      );
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
    },
  );

  test(
    'Local Topo stays unavailable until restore and uses runtime URL after it',
    () async {
      expect(isBasemapAvailable(Basemap.localTopo), isFalse);
      expect(mapTileUrl(Basemap.localTopo), localTopoPlaceholderTileUrl);
      expect(buildBasemapTileLayer(Basemap.localTopo).maxNativeZoom, 16);

      final snapshot = LocalTopoCapabilitySnapshot(
        baseUrl: Uri.parse('http://127.0.0.1:8090'),
        regions: const [
          LocalTopoRegionCapability(
            regionKey: 'tasmania',
            tilePathTemplate: '/tasmania/local-topo/{z}/{x}/{y}.png',
          ),
        ],
      );

      await localTopoRuntime.saveValidatedSnapshot(snapshot);

      expect(isBasemapAvailable(Basemap.localTopo), isTrue);
      expect(
        mapTileUrl(Basemap.localTopo),
        'http://127.0.0.1:8090/tasmania/local-topo/{z}/{x}/{y}.png',
      );
      expect(buildBasemapTileLayer(Basemap.localTopo).maxNativeZoom, 16);

      await localTopoRuntime.saveBaseUrl(Uri.parse('http://127.0.0.1:8091'));

      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      expect(mapTileUrl(Basemap.localTopo), localTopoPlaceholderTileUrl);
    },
  );
}
