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
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.byKey(const Key('export-peak-lists-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-list-export-status')),
      200,
      scrollable: find.byType(Scrollable),
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
}
