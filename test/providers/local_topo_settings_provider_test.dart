import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/local_topo_settings_provider.dart';
import 'package:peak_bagger/providers/local_topo_overlay_outage_provider.dart';
import 'package:peak_bagger/providers/local_topo_overlay_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/controlled_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    localTopoRuntime.resetForTesting();
  });

  tearDown(() {
    localTopoRuntime.resetForTesting();
  });

  test('restores snapshot state without probing on launch', () async {
    SharedPreferences.setMockInitialValues({
      localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
      localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
      localTopoValidationStatusPrefsKey: 'live-validated',
    });

    var requestCount = 0;
    final container = _buildContainer(
      client: _FakeHttpClient((request) async {
        requestCount += 1;
        return http.Response('{}', 500);
      }),
    );
    addTearDown(container.dispose);

    container.read(localTopoSettingsProvider);
    await _drainAsync();

    final state = container.read(localTopoSettingsProvider);
    expect(state.savedBaseUrlText, 'http://127.0.0.1:8090');
    expect(state.validationStatus, LocalTopoValidationStatus.restoredSnapshot);
    expect(state.activeSnapshot, isNotNull);
    expect(requestCount, 0);
  });

  test('tile outage falls back once and retains settings for retry', () async {
    SharedPreferences.setMockInitialValues({
      localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
      localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
    });
    final container = _buildContainer(
      initialBasemap: Basemap.localTopo,
      client: _FakeHttpClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(container.dispose);
    container.read(localTopoSettingsProvider);
    await _drainAsync();
    final notifier = container.read(localTopoSettingsProvider.notifier);
    final failedTile = Uri.parse(
      'http://127.0.0.1:8090/tasmania/local-topo/12/3714/2583.png',
    );

    expect(notifier.fallbackAfterTileFailure(failedTile), isTrue);
    expect(container.read(mapProvider).basemap, Basemap.tracestrack);
    expect(notifier.fallbackAfterTileFailure(failedTile), isFalse);
    expect(localTopoRuntime.hasCapabilitySnapshot, isTrue);
    expect(
      container.read(localTopoSettingsProvider).savedBaseUrlText,
      'http://127.0.0.1:8090',
    );
  });

  test('ignores tile failures from a previously configured server', () async {
    SharedPreferences.setMockInitialValues({
      localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
      localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
    });
    final container = _buildContainer(
      initialBasemap: Basemap.localTopo,
      client: _FakeHttpClient((_) async => http.Response('{}', 500)),
    );
    addTearDown(container.dispose);
    container.read(localTopoSettingsProvider);
    await _drainAsync();

    expect(
      container
          .read(localTopoSettingsProvider.notifier)
          .fallbackAfterTileFailure(
            Uri.parse(
              'http://127.0.0.1:8091/tasmania/local-topo/12/3714/2583.png',
            ),
          ),
      isFalse,
    );
    expect(container.read(mapProvider).basemap, Basemap.localTopo);
  });

  test(
    'saving a different URL deactivates the old snapshot immediately',
    () async {
      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
        localTopoValidationStatusPrefsKey: 'live-validated',
      });
      final responseCompleter = Completer<http.Response>();

      final container = _buildContainer(
        client: _FakeHttpClient((request) => responseCompleter.future),
      );
      addTearDown(container.dispose);

      container.read(localTopoSettingsProvider);
      await _drainAsync();

      final pendingSave = container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8091');
      await _drainAsync();

      final validatingState = container.read(localTopoSettingsProvider);
      expect(validatingState.savedBaseUrlText, 'http://127.0.0.1:8091');
      expect(
        validatingState.validationStatus,
        LocalTopoValidationStatus.validating,
      );
      expect(validatingState.activeSnapshot, isNull);
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);

      responseCompleter.complete(
        http.Response(jsonEncode(_capabilitiesJson()), 200),
      );
      await pendingSave;

      final state = container.read(localTopoSettingsProvider);
      expect(state.validationStatus, LocalTopoValidationStatus.liveValidated);
      expect(state.savedBaseUrlText, 'http://127.0.0.1:8091');
      expect(state.activeSnapshot, isNotNull);
    },
  );

  test(
    'failed retry clears the snapshot and falls back to tracestrack',
    () async {
      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
        localTopoValidationStatusPrefsKey: 'live-validated',
      });

      final container = _buildContainer(
        initialBasemap: Basemap.localTopo,
        client: _FakeHttpClient((request) async => http.Response('boom', 500)),
      );
      addTearDown(container.dispose);

      container.read(localTopoSettingsProvider);
      await _drainAsync();
      await container
          .read(localTopoSettingsProvider.notifier)
          .retryValidation();

      final state = container.read(localTopoSettingsProvider);
      expect(
        state.validationStatus,
        LocalTopoValidationStatus.validationFailed,
      );
      expect(state.activeSnapshot, isNull);
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      expect(container.read(mapProvider).basemap, Basemap.tracestrack);
    },
  );

  test(
    'successful validation falls back when accepted support no longer intersects the viewport',
    () async {
      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
        localTopoValidationStatusPrefsKey: 'live-validated',
      });

      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.localTopo,
                visibleBounds: LatLngBounds(
                  const LatLng(-43.5, 145.5),
                  const LatLng(-40.5, 148.5),
                ),
              ),
            ),
          ),
          localTopoSettingsHttpClientProvider.overrideWithValue(
            _FakeHttpClient(
              (request) async => http.Response(
                jsonEncode(
                  _capabilitiesJson(
                    regionKey: 'slovenia',
                    tilePathTemplate: '/slovenia/local-topo/{z}/{x}/{y}.png',
                  ),
                ),
                200,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(localTopoSettingsProvider);
      await _drainAsync();
      await container
          .read(localTopoSettingsProvider.notifier)
          .retryValidation();

      expect(container.read(mapProvider).basemap, Basemap.tracestrack);
      expect(
        container.read(localTopoSettingsProvider).validationStatus,
        LocalTopoValidationStatus.liveValidated,
      );
    },
  );

  test(
    'clear removes the saved setting and falls back to tracestrack',
    () async {
      SharedPreferences.setMockInitialValues({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
        localTopoValidationStatusPrefsKey: 'live-validated',
      });

      final container = _buildContainer(initialBasemap: Basemap.localTopo);
      addTearDown(container.dispose);

      container.read(localTopoSettingsProvider);
      await _drainAsync();
      await container.read(localTopoSettingsProvider.notifier).clearSetting();

      final state = container.read(localTopoSettingsProvider);
      final prefs = await SharedPreferences.getInstance();
      expect(state.validationStatus, LocalTopoValidationStatus.empty);
      expect(state.savedBaseUrlText, isEmpty);
      expect(container.read(mapProvider).basemap, Basemap.tracestrack);
      expect(prefs.getString(localTileServerBaseUrlPrefsKey), isNull);
      expect(prefs.getString(localTopoCapabilitySnapshotPrefsKey), isNull);
    },
  );

  test('invalid save reports the invalid URL syntax state', () async {
    final container = _buildContainer();
    addTearDown(container.dispose);

    container.read(localTopoSettingsProvider);
    await _drainAsync();
    await container
        .read(localTopoSettingsProvider.notifier)
        .saveAndValidate('ftp://example.com/tiles');

    final state = container.read(localTopoSettingsProvider);
    expect(state.validationStatus, LocalTopoValidationStatus.invalidUrlSyntax);
    expect(state.savedBaseUrlText, isEmpty);
  });

  test(
    'successful capability validation resets overlay outage suppression',
    () async {
      final container = _buildContainer(
        client: _FakeHttpClient(
          (_) async => http.Response(jsonEncode(_capabilitiesJson()), 200),
        ),
      );
      addTearDown(container.dispose);
      final messages = <String>[];
      final subscription = container
          .read(localTopoOverlayOutageReporterProvider)
          .messages
          .listen(messages.add);
      addTearDown(subscription.cancel);
      final reporter = container.read(localTopoOverlayOutageReporterProvider);

      reporter.report(terrainReliefShadingOverlayKey);
      await container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8090');
      reporter.report(terrainReliefShadingOverlayKey);
      await Future<void>.delayed(Duration.zero);

      expect(messages, [
        'Terrain relief shading is unavailable from the local tile server',
        'Terrain relief shading is unavailable from the local tile server',
      ]);
    },
  );

  for (final throwsError in [false, true]) {
    for (var phase = 1; phase <= 5; phase++) {
      test(
        'save reconciles preference phase $phase failure ($throwsError)',
        () async {
          final prefs = ControlledPreferences({
            localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
            localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
            localTopoValidationStatusPrefsKey: 'live-validated',
          });
          final hosts = <String>[];
          final container = _buildContainer(
            prefs: prefs,
            initialBasemap: Basemap.localTopo,
            client: _FakeHttpClient((request) async {
              hosts.add(request.url.toString());
              return http.Response(jsonEncode(_capabilitiesJson()), 200);
            }),
          );
          addTearDown(container.dispose);
          container.read(localTopoSettingsProvider);
          await _drainAsync();
          prefs.onWrite = (_, _) async {
            if (prefs.writes.length == phase) {
              if (throwsError) throw StateError('injected persistence failure');
              return false;
            }
            return true;
          };
          final notifier = container.read(localTopoSettingsProvider.notifier);
          await notifier.saveAndValidate('  http://127.0.0.1:8091  ');
          final failed = container.read(localTopoSettingsProvider);
          final expectedUrl = 'http://127.0.0.1:${phase == 1 ? 8090 : 8091}';
          expect(failed.savedBaseUrlText, expectedUrl);
          expect(failed.isValidating, isFalse);
          expect(failed.canRetry, isTrue);
          expect(
            failed.detailMessage,
            contains(phase == 1 ? 'Try Save' : 'Retry'),
          );
          expect(prefs.stored[localTileServerBaseUrlPrefsKey], expectedUrl);
          expect(localTopoRuntime.savedBaseUrl.toString(), expectedUrl);
          if (phase == 1) {
            expect(failed.activeSnapshot, isNotNull);
            expect(localTopoRuntime.hasCapabilitySnapshot, isTrue);
            expect(container.read(mapProvider).basemap, Basemap.localTopo);
            await notifier.saveAndValidate('http://127.0.0.1:8091');
          } else {
            expect(
              failed.validationStatus,
              LocalTopoValidationStatus.validationFailed,
            );
            expect(failed.activeSnapshot, isNull);
            expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
            expect(container.read(mapProvider).basemap, Basemap.tracestrack);
            await localTopoRuntime.restore(loadPreferences: () async => prefs);
            expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
            await notifier.retryValidation();
          }
          expect(hosts.last, 'http://127.0.0.1:8091/capabilities');
          expect(
            container.read(localTopoSettingsProvider).validationStatus,
            LocalTopoValidationStatus.liveValidated,
          );
        },
      );
    }

    for (var phase = 1; phase <= 3; phase++) {
      test(
        'partial Clear reconciles phase $phase and allows Clear retry ($throwsError)',
        () async {
          final prefs = ControlledPreferences({
            localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
            localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
            localTopoValidationStatusPrefsKey: 'live-validated',
          });
          final container = _buildContainer(
            prefs: prefs,
            initialBasemap: Basemap.localTopo,
          );
          addTearDown(container.dispose);
          container.read(localTopoSettingsProvider);
          await _drainAsync();
          prefs.onWrite = (_, _) async {
            if (prefs.writes.length != phase) return true;
            if (throwsError) throw StateError('clear failure');
            return false;
          };
          final notifier = container.read(localTopoSettingsProvider.notifier);
          await notifier.clearSetting();
          final failed = container.read(localTopoSettingsProvider);
          expect(
            failed.validationStatus,
            LocalTopoValidationStatus.validationFailed,
          );
          expect(
            failed.savedBaseUrlText,
            prefs.stored[localTileServerBaseUrlPrefsKey] ?? '',
          );
          expect(failed.canClear, isTrue);
          expect(failed.isValidating, isFalse);
          expect(failed.detailMessage, contains('Try Clear again'));
          expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
          expect(container.read(mapProvider).basemap, Basemap.tracestrack);
          await notifier.clearSetting();
          expect(
            container.read(localTopoSettingsProvider).validationStatus,
            LocalTopoValidationStatus.empty,
          );
          expect(prefs.stored, isEmpty);
        },
      );
    }

    for (var phase = 3; phase <= 4; phase++) {
      test(
        'network failure cleanup phase $phase releases lock ($throwsError)',
        () async {
          final prefs = ControlledPreferences({
            localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
            localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
            localTopoValidationStatusPrefsKey: 'live-validated',
          });
          final container = _buildContainer(
            prefs: prefs,
            initialBasemap: Basemap.localTopo,
            client: _FakeHttpClient((_) async => http.Response('{}', 500)),
          );
          addTearDown(container.dispose);
          container.read(localTopoSettingsProvider);
          await _drainAsync();
          prefs.onWrite = (_, _) async {
            if (prefs.writes.length != phase) return true;
            if (throwsError) throw StateError('cleanup failure');
            return false;
          };
          await container
              .read(localTopoSettingsProvider.notifier)
              .retryValidation();
          final failed = container.read(localTopoSettingsProvider);
          expect(failed.canRetry, isTrue);
          expect(failed.isValidating, isFalse);
          expect(failed.savedBaseUrlText, 'http://127.0.0.1:8090');
          expect(failed.detailMessage, contains('Preferences'));
          expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
        },
      );
    }
  }

  test(
    'uncertain readback disables availability and does not offer uncertain Retry',
    () async {
      final prefs = ControlledPreferences();
      final container = _buildContainer(prefs: prefs);
      addTearDown(container.dispose);
      container.read(localTopoSettingsProvider);
      await _drainAsync();
      prefs.onWrite = (_, _) async => false;
      prefs.onReload = () async => throw StateError('readback failed');
      await container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8091');
      final state = container.read(localTopoSettingsProvider);
      expect(state.storageConfirmed, isFalse);
      expect(state.canRetry, isFalse);
      expect(state.canClear, isTrue);
      expect(state.isValidating, isFalse);
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
    },
  );

  test(
    'attempt guard covers preparation, stale hydration and conflicting callbacks',
    () async {
      final prefs = ControlledPreferences();
      final preparation = Completer<SharedPreferences>();
      final response = Completer<http.Response>();
      var loads = 0;
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          localTopoSettingsPreferencesLoaderProvider.overrideWithValue(() {
            loads++;
            return preparation.future;
          }),
          localTopoSettingsHttpClientProvider.overrideWithValue(
            _FakeHttpClient((_) => response.future),
          ),
        ],
      );
      container.read(localTopoSettingsProvider);
      final notifier = container.read(localTopoSettingsProvider.notifier);
      final attempt = notifier.saveAndValidate('http://127.0.0.1:8091');
      expect(container.read(localTopoSettingsProvider).isValidating, isTrue);
      await notifier.saveAndValidate('http://other.invalid');
      await notifier.retryValidation();
      await notifier.clearSetting();
      expect(loads, 2); // Hydration and the one accepted attempt.
      preparation.complete(prefs);
      await _drainAsync();
      expect(
        container.read(localTopoSettingsProvider).savedBaseUrlText,
        'http://127.0.0.1:8091',
      );
      container.dispose();
      response.complete(http.Response(jsonEncode(_capabilitiesJson()), 200));
      await attempt;
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      expect(prefs.stored[localTopoCapabilitySnapshotPrefsKey], isNull);
    },
  );

  test(
    'successful snapshot is not active until final status persistence completes',
    () async {
      final prefs = ControlledPreferences();
      final statusWrite = Completer<bool>();
      prefs.onWrite = (key, value) async {
        if (key == localTopoValidationStatusPrefsKey &&
            value == 'live-validated') {
          return statusWrite.future;
        }
        return true;
      };
      final container = _buildContainer(
        prefs: prefs,
        client: _FakeHttpClient(
          (_) async => http.Response(jsonEncode(_capabilitiesJson()), 200),
        ),
      );
      addTearDown(container.dispose);
      final attempt = container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8090');
      await _drainAsync();
      expect(prefs.stored[localTopoCapabilitySnapshotPrefsKey], isNotNull);
      expect(container.read(localTopoSettingsProvider).isValidating, isTrue);
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      statusWrite.complete(false);
      await attempt;
      expect(
        container.read(localTopoSettingsProvider).validationStatus,
        LocalTopoValidationStatus.validationFailed,
      );
      expect(localTopoRuntime.hasCapabilitySnapshot, isFalse);
      expect(container.read(localTopoSettingsProvider).canRetry, isTrue);
    },
  );

  test(
    'preference preparation failure preserves confirmed previous configuration',
    () async {
      final prefs = ControlledPreferences({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090',
        localTopoCapabilitySnapshotPrefsKey: jsonEncode(_snapshotJson()),
      });
      var fail = false;
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.localTopo,
              ),
            ),
          ),
          localTopoSettingsPreferencesLoaderProvider.overrideWithValue(
            () async {
              if (fail) throw StateError('preference preparation failed');
              return prefs;
            },
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(localTopoSettingsProvider);
      await _drainAsync();
      fail = true;
      await container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8091');
      expect(
        container.read(localTopoSettingsProvider).savedBaseUrlText,
        'http://127.0.0.1:8090',
      );
      expect(container.read(localTopoSettingsProvider).isValidating, isFalse);
      expect(localTopoRuntime.hasCapabilitySnapshot, isTrue);
      expect(prefs.writes, isEmpty);
    },
  );

  test(
    'failed URL write retains semantically identical legacy snapshot encoding',
    () async {
      final prefs = ControlledPreferences({
        localTileServerBaseUrlPrefsKey: 'http://127.0.0.1:8090/',
        localTopoCapabilitySnapshotPrefsKey: const JsonEncoder.withIndent(
          '  ',
        ).convert(_snapshotJson()),
      });
      final container = _buildContainer(
        prefs: prefs,
        initialBasemap: Basemap.localTopo,
      );
      addTearDown(container.dispose);
      container.read(localTopoSettingsProvider);
      await _drainAsync();
      prefs.onWrite = (_, _) async => false;
      await container
          .read(localTopoSettingsProvider.notifier)
          .saveAndValidate('http://127.0.0.1:8091');
      expect(
        container.read(localTopoSettingsProvider).savedBaseUrlText,
        'http://127.0.0.1:8090',
      );
      expect(container.read(localTopoSettingsProvider).isValidating, isFalse);
      expect(localTopoRuntime.hasCapabilitySnapshot, isTrue);
      expect(container.read(mapProvider).basemap, Basemap.localTopo);
      expect(prefs.writes.length, 1);
    },
  );
}

ProviderContainer _buildContainer({
  Basemap initialBasemap = Basemap.tracestrack,
  http.Client? client,
  SharedPreferences? prefs,
}) {
  return ProviderContainer(
    overrides: [
      ...mappingCatalogTestOverrides,
      if (prefs != null)
        localTopoSettingsPreferencesLoaderProvider.overrideWithValue(
          () async => prefs,
        ),
      mapProvider.overrideWith(
        () => TestMapNotifier(
          MapState(
            center: const LatLng(-41.5, 146.5),
            zoom: 10,
            basemap: initialBasemap,
          ),
        ),
      ),
      if (client != null)
        localTopoSettingsHttpClientProvider.overrideWithValue(client),
    ],
  );
}

Map<String, dynamic> _snapshotJson({String baseUrl = 'http://127.0.0.1:8090'}) {
  return {
    'baseUrl': baseUrl,
    'regions': [
      {
        'regionKey': 'tasmania',
        'tilePathTemplate': '/tasmania/local-topo/{z}/{x}/{y}.png',
      },
    ],
  };
}

Map<String, dynamic> _capabilitiesJson({
  String regionKey = 'tasmania',
  String tilePathTemplate = '/tasmania/local-topo/{z}/{x}/{y}.png',
}) {
  return {
    'service': 'peak-bagger-local-topo',
    'version': 1,
    'basemaps': [
      {
        'key': 'localTopo',
        'label': 'Local Topo',
        'regions': [
          {'regionKey': regionKey, 'tilePathTemplate': tilePathTemplate},
        ],
      },
    ],
  };
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(const Duration(milliseconds: 20));
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient(this._handler);

  final Future<http.Response> Function(http.BaseRequest request) _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
      reasonPhrase: response.reasonPhrase,
    );
  }
}
