import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/screens/settings_screen.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets(
    'mixed scan summary reports non-Tasmanian files only in nonTasmanianCount',
    (tester) async {
      final initialState = MapState(
        center: _center,
        zoom: 10,
        basemap: Basemap.tracestrack,
        trackOperationStatus:
            'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 0',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(() => TestMapNotifier(initialState)),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.textContaining('Imported 1'), findsOneWidget);
      expect(find.textContaining('replaced 0'), findsOneWidget);
      expect(find.textContaining('unchanged 0'), findsOneWidget);
      expect(find.textContaining('non-Tasmanian 2'), findsOneWidget);
      expect(find.textContaining('errors 0'), findsOneWidget);
    },
  );

  testWidgets('recalc summary reports updated and skipped counts', (
    tester,
  ) async {
    final initialState = MapState(
      center: _center,
      zoom: 10,
      basemap: Basemap.tracestrack,
      trackOperationStatus: 'Updated 3 tracks, skipped 1 tracks',
      trackOperationWarning: 'Some tracks could not be recalculated.',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.textContaining('Updated 3 tracks'), findsOneWidget);
    expect(find.textContaining('skipped 1 tracks'), findsOneWidget);
    expect(
      find.textContaining('Some tracks could not be recalculated.'),
      findsOneWidget,
    );
  });
}

const _center = LatLng(-41.5, 146.5);
