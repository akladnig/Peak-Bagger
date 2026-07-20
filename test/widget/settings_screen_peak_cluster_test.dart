import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_mini_map_cluster_display_settings_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('settings screen no longer shows map peak cluster row', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    expect(find.byKey(const Key('show-map-peak-clusters-tile')), findsNothing);
    expect(
      find.byKey(const Key('show-map-peak-clusters-switch')),
      findsNothing,
    );
    expect(find.text('Show Map Peak Clusters'), findsNothing);
  });

  testWidgets('settings screen shows peak list mini-map cluster row', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-list-mini-map-clusters-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      find.byKey(const Key('show-peak-list-mini-map-clusters-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('show-peak-list-mini-map-clusters-switch')),
      findsOneWidget,
    );
    expect(find.text('Show Peak List Mini-Map Clusters'), findsOneWidget);
  });

  testWidgets('settings screen shows peak ownership ring row', (tester) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-ownership-rings-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      find.byKey(const Key('show-peak-ownership-rings-tile')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('show-peak-ownership-rings-switch')),
      findsOneWidget,
    );
    expect(find.text('Show Peak Ownership Rings'), findsOneWidget);
  });

  testWidgets('peak ownership ring toggle persists across rebuilds', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-ownership-rings-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-ownership-rings-switch')),
          )
          .value,
      isFalse,
    );

    await tester.tap(find.byKey(const Key('show-peak-ownership-rings-tile')));
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-ownership-rings-switch')),
          )
          .value,
      isTrue,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(peakOwnershipRingSettingsProvider),
      isTrue,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-ownership-rings-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-ownership-rings-switch')),
          )
          .value,
      isTrue,
    );
  });

  testWidgets('peak list mini-map cluster toggle persists across rebuilds', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    await _pumpSettingsScreen(tester);

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-list-mini-map-clusters-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-list-mini-map-clusters-switch')),
          )
          .value,
      isTrue,
    );

    await tester.tap(
      find.byKey(const Key('show-peak-list-mini-map-clusters-tile')),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-list-mini-map-clusters-switch')),
          )
          .value,
      isFalse,
    );
    expect(
      ProviderScope.containerOf(
        tester.element(find.byType(SettingsScreen)),
      ).read(peakListMiniMapClusterDisplaySettingsProvider),
      isFalse,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await _pumpSettingsScreen(tester);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const Key('show-peak-list-mini-map-clusters-tile')),
      200,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('settings-scrollable')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pump();

    expect(
      tester
          .widget<Switch>(
            find.byKey(const Key('show-peak-list-mini-map-clusters-switch')),
          )
          .value,
      isFalse,
    );
  });
}

Future<void> _pumpSettingsScreen(WidgetTester tester) async {
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
  await tester.pumpAndSettle();
}
