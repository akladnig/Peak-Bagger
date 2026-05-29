import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('settings screen shows peak info row', (tester) async {
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

    await tester.scrollUntilVisible(
      find.text('Show Peak Info', skipOffstage: false),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Show Peak Info', skipOffstage: false), findsOneWidget);
  });
}
