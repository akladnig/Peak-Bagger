import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/theme.dart';
import 'package:peak_bagger/widgets/open_route_service_api_key_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/controlled_preferences.dart';

void main() {
  testWidgets('settings screen shows ORS API key row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      ProviderScope(
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
        ],
        child: MaterialApp(theme: MyTheme.dark, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('open-route-service-api-key-tile')),
      findsOneWidget,
    );
    expect(find.text('OpenRouteService API Key'), findsOneWidget);
  });

  testWidgets('settings screen saves ORS API key changes', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: MyTheme.dark, home: const SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('open-route-service-api-key-tile')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('open-route-service-api-key-field')),
      'new-ors-key',
    );
    await tester.tap(find.byKey(const Key('open-route-service-api-key-save')));
    await tester.pumpAndSettle();

    expect(container.read(openRouteServiceApiKeyProvider), 'new-ors-key');
  });

  for (final throwsError in [false, true]) {
    testWidgets(
      'key dialog guards every dismissal, retains failure and retries ($throwsError)',
      (tester) async {
        final prefs = ControlledPreferences({
          openRouteServiceApiKeyPrefsKey: 'prior-key',
        });
        final prepared = Completer<SharedPreferences>();
        var saving = false;
        var closes = 0;
        final container = ProviderContainer(
          overrides: [
            openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
              () => saving ? prepared.future : Future.value(prefs),
            ),
          ],
        );
        addTearDown(container.dispose);
        container.read(openRouteServiceApiKeyProvider);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: MyTheme.dark,
              home: Builder(
                builder: (context) => FilledButton(
                  onPressed: () async {
                    await showOpenRouteServiceApiKeyDialog(context);
                    closes++;
                  },
                  child: const Text('Edit key'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Edit key'));
        await tester.pumpAndSettle();
        final field = find.byKey(const Key('open-route-service-api-key-field'));
        final save = tester
            .widget<FilledButton>(
              find.byKey(const Key('open-route-service-api-key-save')),
            )
            .onPressed!;
        final cancel = tester
            .widget<FilledButton>(
              find.byKey(const Key('open-route-service-api-key-cancel')),
            )
            .onPressed!;
        await tester.enterText(field, '  retained-draft  ');
        saving = true;
        save();
        save();
        cancel(); // All captured before a rebuild.
        final navigator = Navigator.of(tester.element(field));
        navigator.pop();
        await navigator.maybePop();
        await tester.pump();
        expect(tester.widget<TextField>(field).enabled, isFalse);
        expect(
          find.byKey(const Key('open-route-service-api-key-progress')),
          findsOneWidget,
        );
        await tester.tapAt(const Offset(10, 10));
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.binding.handlePopRoute();
        await tester.pump();
        expect(closes, 0);
        expect(container.read(openRouteServiceApiKeyProvider), 'prior-key');
        prefs.onWrite = (_, _) async {
          if (throwsError) throw StateError('private-key-payload');
          return false;
        };
        prepared.complete(prefs);
        await tester.pumpAndSettle();
        expect(closes, 0);
        expect(
          tester.widget<TextField>(field).controller!.text,
          '  retained-draft  ',
        );
        expect(
          find.text('Could not save the API key. Try Save again, or Cancel.'),
          findsOneWidget,
        );
        expect(container.read(openRouteServiceApiKeyProvider), 'prior-key');
        expect(prefs.writes.length, 1);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('open-route-service-api-key-cancel')),
              )
              .onPressed,
          isNotNull,
        );
        prefs.onWrite = null;
        await tester.tap(
          find.byKey(const Key('open-route-service-api-key-save')),
        );
        await tester.pumpAndSettle();
        expect(closes, 1);
        expect(prefs.writes.length, 2);
        expect(
          container.read(openRouteServiceApiKeyProvider),
          'retained-draft',
        );
        expect(prefs.stored[openRouteServiceApiKeyPrefsKey], 'retained-draft');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('idle key Cancel and outside dismissal discard without writing', (
    tester,
  ) async {
    final prefs = ControlledPreferences();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openRouteServiceApiKeyPreferencesLoaderProvider.overrideWithValue(
            () async => prefs,
          ),
        ],
        child: MaterialApp(
          theme: MyTheme.dark,
          home: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showOpenRouteServiceApiKeyDialog(context),
              child: const Text('Edit key'),
            ),
          ),
        ),
      ),
    );
    for (final outside in [false, true]) {
      await tester.tap(find.text('Edit key'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('open-route-service-api-key-field')),
        'discard-me',
      );
      if (outside) {
        await tester.tapAt(const Offset(10, 10));
      } else {
        await tester.tap(
          find.byKey(const Key('open-route-service-api-key-cancel')),
        );
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('open-route-service-api-key-dialog')),
        findsNothing,
      );
    }
    expect(prefs.writes, isEmpty);
  });
}
