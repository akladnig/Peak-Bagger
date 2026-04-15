import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('manual rescan shows no-GPX snackbar message', (tester) async {
    await _pumpApp(
      tester,
      TestMapNotifier(
        _baseState(),
        rescanStatus: 'No GPX files found in watched folder',
        rescanSnackbarMessage: 'No GPX files found in watched folder',
      ),
    );

    await tester.tap(find.byKey(const Key('import-tracks-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('No GPX files found in watched folder'), findsOneWidget);
  });

  testWidgets('mixed result shows route-shell snackbar and settings warning', (
    tester,
  ) async {
    await _pumpApp(
      tester,
      TestMapNotifier(
        _baseState(),
        rescanStatus:
            'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 1',
        rescanWarning: 'Some files need manual review. See import.log.',
      ),
    );

    await tester.tap(find.byKey(const Key('import-tracks-fab')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(
        'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 1',
      ),
      findsOneWidget,
    );

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Some files need manual review. See import.log.'),
      findsOneWidget,
    );
  });

  testWidgets('reset track data shows result dialog', (tester) async {
    await _pumpApp(tester, TestMapNotifier(_baseState()));

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('reset-track-data-tile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reset-track-data-confirm')));
    await tester.pumpAndSettle();

    expect(find.text('Track Data Reset'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('Imported 1'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpApp(WidgetTester tester, TestMapNotifier notifier) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mapProvider.overrideWith(() => notifier)],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

MapState _baseState() {
  return MapState(
    center: const LatLng(-41.5, 146.5),
    zoom: 10,
    basemap: Basemap.tracestrack,
  );
}
