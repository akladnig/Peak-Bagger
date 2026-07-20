import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/local_topo_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
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

  testWidgets('settings screen shows the empty local topo state', (
    tester,
  ) async {
    await _pumpSettingsScreen(tester);

    expect(find.text('Local tile server base URL'), findsNWidgets(2));
    expect(find.text('Saved URL: Empty'), findsOneWidget);
    expect(find.text('Validation state: Empty'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('local-topo-retry-button')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('settings screen saves and shows the live validated state', (
    tester,
  ) async {
    await _pumpSettingsScreen(
      tester,
      client: _FakeHttpClient(
        (request) async => http.Response(jsonEncode(_capabilitiesFixture), 200),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('local-topo-base-url-field')),
      'http://127.0.0.1:8090',
    );
    await tester.tap(find.byKey(const Key('local-topo-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Saved URL: http://127.0.0.1:8090'), findsOneWidget);
    expect(find.text('Validation state: Live validated'), findsOneWidget);
  });
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  http.Client? client,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        if (client != null)
          localTopoSettingsHttpClientProvider.overrideWithValue(client),
      ],
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}

const _capabilitiesFixture = {
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
};

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
