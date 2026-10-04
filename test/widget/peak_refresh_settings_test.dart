import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/settings_screen.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  setUp(() {
    router = createRouter();
  });

  testWidgets('update peak data cancel is a no-op', (tester) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('update-peak-data-tile')));
    await tester.pump();

    expect(find.text('Update Peak Data'), findsOneWidget);
    expect(find.text('Update peaks from Mapping data store'), findsOneWidget);
    expect(find.text('Update Peak Data?'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Update'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('peak-update-cancel')));
    await tester.pump();

    expect(notifier.refreshCallCount, 0);
    expect(find.byKey(const Key('peak-update-status')), findsNothing);
    expect(find.text('Peak Data Updated'), findsNothing);
  });

  testWidgets('update peak data shows loading state', (tester) async {
    final repository = await TestTasmapRepository.create();
    final completer = Completer<PeakRegionAssetImportResult>();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      updateHandler: () => completer.future,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('update-peak-data-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-update-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final tile = tester.widget<ListTile>(
      find.byKey(const Key('update-peak-data-tile')),
    );
    expect(tile.onTap, isNull);
    expect(notifier.refreshCallCount, 1);

    completer.complete(
      const PeakRegionAssetImportResult(
        importedRegions: ['tasmania'],
        importedPeakCount: 1234,
        skippedPeakCount: 0,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('1,234 Peaks updated'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('update peak data shows result dialog with skipped records', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      updateHandler: () async => const PeakRegionAssetImportResult(
        importedRegions: ['tasmania'],
        importedPeakCount: 1234,
        skippedPeakCount: 1234,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pump();

    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('update-peak-data-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-update-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('Peak Data Updated'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('1,234 Peaks updated'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('1,234 peaks skipped'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-update-result-close')), findsOneWidget);
  });
}
