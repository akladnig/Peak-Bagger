import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart' show LatLngBounds;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/local_topo_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/local_topo_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

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
}

ProviderContainer _buildContainer({
  Basemap initialBasemap = Basemap.tracestrack,
  http.Client? client,
}) {
  return ProviderContainer(
    overrides: [
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
