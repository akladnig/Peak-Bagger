import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/open_route_service_api_key_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('settings screen shows ORS API key row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

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
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    expect(find.byKey(const Key('open-route-service-api-key-tile')), findsOneWidget);
    expect(find.text('OpenRouteService API Key'), findsOneWidget);
  });

  testWidgets('settings screen saves ORS API key changes', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final container = ProviderContainer(
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
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SettingsScreen()),
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
}
