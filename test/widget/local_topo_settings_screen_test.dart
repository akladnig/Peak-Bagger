import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/local_topo_settings_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/theme.dart';
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

  testWidgets('settings screen shows the empty local topo state', (
    tester,
  ) async {
    await _pumpSettingsScreen(tester);

    expect(find.text('Local tile server base URL'), findsNWidgets(2));
    expect(find.text('Saved URL: Empty'), findsOneWidget);
    expect(find.text('Validation state: Empty'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('local-topo-base-url-field')))
          .controller
          ?.text,
      defaultLocalTopoBaseUrlText,
    );
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

    await tester.tap(find.byKey(const Key('local-topo-save-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));

    expect(find.text('Saved URL: http://127.0.0.1:8090'), findsOneWidget);
    expect(find.text('Validation state: Live validated'), findsOneWidget);
  });

  testWidgets('URL syntax feedback wraps beside retained URL draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSettingsScreen(tester, scale: 2);
    final field = find.byKey(const Key('local-topo-base-url-field'));
    await tester.enterText(field, 'ftp://retained.invalid');
    await tester.tap(find.byKey(const Key('local-topo-save-button')));
    await tester.pumpAndSettle();
    expect(
      find.text('Enter a valid http or https base URL.'),
      findsNWidgets(2),
    );
    expect(
      tester.widget<TextField>(field).controller!.text,
      'ftp://retained.invalid',
    );
    expect(tester.widget<TextField>(field).keyboardType, TextInputType.url);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'URL early pending guard and partial persistence keep draft and confirmed Retry target',
    (tester) async {
      final prefs = ControlledPreferences({
        localTileServerBaseUrlPrefsKey: 'http://old.invalid',
      });
      final prepared = Completer<SharedPreferences>();
      var saving = false;
      await _pumpSettingsScreen(
        tester,
        loader: () => saving ? prepared.future : Future.value(prefs),
        client: _FakeHttpClient(
          (_) async => http.Response(jsonEncode(_capabilitiesFixture), 200),
        ),
      );
      final field = find.byKey(const Key('local-topo-base-url-field'));
      await tester.enterText(field, '  http://new.invalid  ');
      final save = tester
          .widget<FilledButton>(find.byKey(const Key('local-topo-save-button')))
          .onPressed!;
      final clear = tester
          .widget<FilledButton>(
            find.byKey(const Key('local-topo-clear-button')),
          )
          .onPressed!;
      saving = true;
      save();
      save();
      clear();
      await tester.pump();
      expect(tester.widget<TextField>(field).enabled, isFalse);
      expect(find.byKey(const Key('local-topo-pending')), findsOneWidget);
      prefs.onWrite = (key, _) async =>
          key != localTopoCapabilitySnapshotPrefsKey;
      prepared.complete(prefs);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        '  http://new.invalid  ',
      );
      expect(find.text('Saved URL: http://new.invalid'), findsOneWidget);
      expect(find.text('Validation state: Validation failed'), findsOneWidget);
      expect(
        find.textContaining('Use Retry for the saved URL'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('local-topo-retry-button')),
            )
            .onPressed,
        isNotNull,
      );
      prefs.onWrite = null;
      await tester.tap(find.byKey(const Key('local-topo-retry-button')));
      await tester.pumpAndSettle();
      expect(find.text('Validation state: Live validated'), findsOneWidget);
      expect(
        tester.widget<TextField>(field).controller!.text,
        '  http://new.invalid  ',
      );
    },
  );
}

Future<void> _pumpSettingsScreen(
  WidgetTester tester, {
  http.Client? client,
  Future<SharedPreferences> Function()? loader,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...mappingCatalogTestOverrides,
        if (loader != null)
          localTopoSettingsPreferencesLoaderProvider.overrideWithValue(loader),
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
      child: MaterialApp(
        theme: MyTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
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
