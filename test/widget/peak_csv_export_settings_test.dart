import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_csv_export_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_csv_export_service.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('export peak data shows loading state and success', (tester) async {
    final repository = await TestTasmapRepository.create();
    final completer = Completer<PeakCsvExportResult>();
    var exportCalls = 0;
    Future<PeakCsvExportResult> exportRunner() {
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
          peakCsvExportRunnerProvider.overrideWithValue(exportRunner),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
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
      find.byKey(const Key('export-peak-data-tile')),
      200,
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.byKey(const Key('export-peak-data-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-export-status')),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(exportCalls, 1);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('export-peak-data-tile'))).onTap,
      isNull,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('refresh-peak-data-tile'))).onTap,
      isNull,
    );
    expect(find.byKey(const Key('peak-export-status')), findsOneWidget);
    expect(find.text('Exporting peak data...'), findsOneWidget);

    completer.complete(
      const PeakCsvExportResult(
        path: '/Users/adrian/Documents/Bushwalking/Features/peaks.csv',
        exportedCount: 2,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('peak-export-status')), findsOneWidget);
    expect(
      find.text(
        'Exported 2 peaks to /Users/adrian/Documents/Bushwalking/Features/peaks.csv',
      ),
      findsOneWidget,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('export-peak-data-tile'))).onTap,
      isNotNull,
    );
    expect(
      tester.widget<ListTile>(find.byKey(const Key('refresh-peak-data-tile'))).onTap,
      isNotNull,
    );
  });

  testWidgets('export peak data shows failure state', (tester) async {
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
          peakCsvExportRunnerProvider.overrideWithValue(() async {
            throw StateError('boom');
          }),
          tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
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
      find.byKey(const Key('export-peak-data-tile')),
      200,
      scrollable: find.byType(Scrollable),
    );

    await tester.tap(find.byKey(const Key('export-peak-data-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.scrollUntilVisible(
      find.byKey(const Key('peak-export-status')),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.byKey(const Key('peak-export-status')), findsOneWidget);
    expect(find.textContaining('Export failed:'), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(
      tester.widget<ListTile>(find.byKey(const Key('export-peak-data-tile'))).onTap,
      isNotNull,
    );
  });
}
