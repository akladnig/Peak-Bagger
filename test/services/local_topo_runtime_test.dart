import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:peak_bagger/services/region_manifest_catalog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../harness/controlled_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    registerLocalTopoRegionKeyValidator(
      (regionKey) => testMappingCatalog.regionByKey(regionKey) != null,
    );
    localTopoRuntime.resetForTesting();
  });

  tearDown(() {
    localTopoRuntime.resetForTesting();
  });

  test(
    'runtime requires confirmed writes and does not restore an incomplete validation',
    () async {
      final prefs = ControlledPreferences();
      final runtime = LocalTopoRuntime();
      final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
        baseUrl: Uri.parse('http://127.0.0.1:8090'),
        decoded: jsonDecode(
          File(
            'local_topo/tasmania/fixtures/capabilities.json',
          ).readAsStringSync(),
        ),
      );
      prefs.onWrite = (_, _) async => false;
      await expectLater(
        runtime.saveBaseUrl(
          snapshot.baseUrl,
          loadPreferences: () async => prefs,
        ),
        throwsStateError,
      );
      expect(runtime.savedBaseUrl, isNull);
      prefs.onWrite = null;
      await runtime.saveBaseUrl(
        snapshot.baseUrl,
        loadPreferences: () async => prefs,
      );
      await prefs.setString('local_topo_validation_status_v1', 'validating');
      await runtime.saveValidatedSnapshot(
        snapshot,
        loadPreferences: () async => prefs,
        activate: false,
      );
      expect(runtime.hasCapabilitySnapshot, isFalse);
      await runtime.restore(loadPreferences: () async => prefs);
      expect(runtime.hasCapabilitySnapshot, isFalse);
      await prefs.setString(
        'local_topo_validation_status_v1',
        'live-validated',
      );
      await runtime.restore(loadPreferences: () async => prefs);
      expect(runtime.hasCapabilitySnapshot, isTrue);
      prefs.onWrite = (_, _) async => false;
      await expectLater(
        runtime.clearCapabilitySnapshot(loadPreferences: () async => prefs),
        throwsStateError,
      );
      expect(runtime.hasCapabilitySnapshot, isFalse);
    },
  );

  test(
    'changing URL deactivates old runtime before failed snapshot cleanup',
    () async {
      final prefs = ControlledPreferences();
      final runtime = LocalTopoRuntime();
      final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
        baseUrl: Uri.parse('http://127.0.0.1:8090'),
        decoded: jsonDecode(
          File(
            'local_topo/tasmania/fixtures/capabilities.json',
          ).readAsStringSync(),
        ),
      );
      await runtime.saveValidatedSnapshot(
        snapshot,
        loadPreferences: () async => prefs,
      );
      prefs.onWrite = (key, _) async =>
          key != localTopoCapabilitySnapshotPrefsKey;
      await expectLater(
        runtime.saveBaseUrl(
          Uri.parse('http://127.0.0.1:8091'),
          loadPreferences: () async => prefs,
        ),
        throwsStateError,
      );
      expect(runtime.savedBaseUrl.toString(), 'http://127.0.0.1:8091');
      expect(runtime.hasCapabilitySnapshot, isFalse);
      expect(
        prefs.stored[localTileServerBaseUrlPrefsKey],
        'http://127.0.0.1:8091',
      );
    },
  );

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

  test('capability parser accepts the v2 fixture contract', () {
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
    expect(
      snapshot.resolvedOverlayTileUrlTemplate(
        key: 'terrainReliefShading',
        regionKey: 'tasmania',
      ),
      'http://127.0.0.1:8090/tasmania/terrain-relief-shading/{z}/{x}/{y}.png',
    );
  });

  test('capability parser keeps v1 snapshots valid without overlays', () {
    final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
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
                'tilePathTemplate': '/tasmania/local-topo/{z}/{x}/{y}.png',
              },
            ],
          },
        ],
      },
    );

    expect(snapshot.overlays, isNull);
    expect(snapshot.overlayCapabilities, isEmpty);
    expect(snapshot.toJson().containsKey('overlays'), isFalse);
  });

  test('capability parser discards malformed overlays and duplicate keys', () {
    final decoded =
        jsonDecode(
              File(
                'local_topo/tasmania/fixtures/capabilities.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final overlays = (decoded['overlays'] as List<dynamic>)
      ..add({
        'key': 'terrainReliefShading',
        'label': 'Terrain relief shading',
        'regions': [
          {
            'regionKey': 'tasmania',
            'tilePathTemplate': '/duplicate/{z}/{x}/{y}.png',
          },
        ],
      })
      ..add({
        'key': 'contourLines',
        'label': 'Wrong label',
        'regions': [
          {
            'regionKey': 'tasmania',
            'tilePathTemplate': '/ignored/{z}/{x}/{y}.png',
          },
        ],
      });
    decoded['overlays'] = overlays;

    final snapshot = LocalTopoCapabilitySnapshot.fromCapabilitiesResponse(
      baseUrl: Uri.parse('http://127.0.0.1:8090'),
      decoded: decoded,
    );

    expect(snapshot.overlayByKey('terrainReliefShading'), isNull);
    expect(snapshot.overlayByKey('contourLines'), isNotNull);
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
      expect(
        mapTileUrl(Basemap.localTopo, catalog: testMappingCatalog),
        localTopoPlaceholderTileUrl,
      );
      expect(
        buildBasemapTileLayer(
          Basemap.localTopo,
          catalog: testMappingCatalog,
        ).maxNativeZoom,
        18,
      );

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
        mapTileUrl(Basemap.localTopo, catalog: testMappingCatalog),
        'http://127.0.0.1:8090/tasmania/local-topo/{z}/{x}/{y}.png',
      );
      expect(
        buildBasemapTileLayer(
          Basemap.localTopo,
          catalog: testMappingCatalog,
        ).maxNativeZoom,
        18,
      );

      await localTopoRuntime.saveBaseUrl(Uri.parse('http://127.0.0.1:8091'));

      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      expect(
        mapTileUrl(Basemap.localTopo, catalog: testMappingCatalog),
        localTopoPlaceholderTileUrl,
      );
    },
  );
}
