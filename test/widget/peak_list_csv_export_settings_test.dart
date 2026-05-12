import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_csv_export_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('export peak lists shows loading state and success', (
    tester,
  ) async {
    Finder tile(String key) => find.byKey(Key(key), skipOffstage: false);
    final settingsScrollable = find.byType(Scrollable).last;

    final repository = await TestTasmapRepository.create();
    final completer = Completer<PeakListCsvExportResult>();
    var exportCalls = 0;
    Future<PeakListCsvExportResult> exportRunner() {
      exportCalls += 1;
      return completer.future;
    }

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
          peakListCsvExportRunnerProvider.overrideWithValue(exportRunner),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-peak-lists-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-list-export-status')),
      200,
      scrollable: settingsScrollable,
    );

    expect(exportCalls, 1);
    expect(
      tester.widget<ListTile>(tile('export-peak-lists-tile')).onTap,
      isNull,
    );
    expect(
      tester.widget<ListTile>(tile('refresh-peak-data-tile')).onTap,
      isNull,
    );
    expect(tester.widget<ListTile>(tile('reset-map-data-tile')).onTap, isNull);
    expect(
      tester.widget<ListTile>(tile('export-peak-data-tile')).onTap,
      isNull,
    );
    expect(find.byKey(const Key('peak-list-export-status')), findsOneWidget);
    expect(find.text('Exporting peak lists...'), findsOneWidget);

    completer.complete(
      const PeakListCsvExportResult(
        outputDirectoryPath: '/Users/adrian/Documents/Bushwalking/Peak_Lists',
        exportedFileCount: 2,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-list-export-status')), findsOneWidget);
    expect(
      find.text('Exported 2 peak lists. Skipped 0 lists.'),
      findsOneWidget,
    );
    expect(
      tester.widget<ListTile>(tile('export-peak-lists-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('refresh-peak-data-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('reset-map-data-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('export-peak-data-tile')).onTap,
      isNotNull,
    );
  });

  testWidgets('export peak lists shows warning-bearing success summary', (
    tester,
  ) async {
    final settingsScrollable = find.byType(Scrollable).last;
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
          peakListCsvExportRunnerProvider.overrideWithValue(() async {
            return const PeakListCsvExportResult(
              outputDirectoryPath:
                  '/Users/adrian/Documents/Bushwalking/Peak_Lists',
              exportedFileCount: 1,
              skippedMalformedListCount: 1,
              warningEntries: ['warning 1', 'warning 2'],
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-peak-lists-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-list-export-status')),
      200,
      scrollable: settingsScrollable,
    );

    expect(
      find.text(
        'Exported 1 peak list. Skipped 1 list. 2 warnings. Older files may remain for skipped lists.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('export peak lists shows zero-output success state', (
    tester,
  ) async {
    final settingsScrollable = find.byType(Scrollable).last;
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
          peakListCsvExportRunnerProvider.overrideWithValue(() async {
            return const PeakListCsvExportResult(
              outputDirectoryPath:
                  '/Users/adrian/Documents/Bushwalking/Peak_Lists',
              exportedFileCount: 0,
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-peak-lists-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-list-export-status')),
      200,
      scrollable: settingsScrollable,
    );

    expect(
      find.text('Exported 0 peak lists. Skipped 0 lists.'),
      findsOneWidget,
    );
  });

  testWidgets('export peak lists shows failure with path detail', (
    tester,
  ) async {
    Finder tile(String key) => find.byKey(Key(key), skipOffstage: false);
    final settingsScrollable = find.byType(Scrollable).last;

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
          peakListCsvExportRunnerProvider.overrideWithValue(() async {
            throw const PeakListCsvExportException(
              'Peak_Lists directory does not exist at /tmp/Peak_Lists. Create the folder and retry.',
            );
          }),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('export-peak-lists-tile')),
      200,
      scrollable: settingsScrollable,
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-list-export-status')),
      200,
      scrollable: settingsScrollable,
    );

    expect(find.textContaining('Export failed:'), findsOneWidget);
    expect(find.textContaining('/tmp/Peak_Lists'), findsOneWidget);
    expect(find.textContaining('Create the folder and retry'), findsOneWidget);
    expect(
      tester.widget<ListTile>(tile('export-peak-lists-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('refresh-peak-data-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('reset-map-data-tile')).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(tile('export-peak-data-tile')).onTap,
      isNotNull,
    );
  });
}
