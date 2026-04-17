import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('refresh peak data cancel is a no-op', (tester) async {
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
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('refresh-peak-data-tile')));
    await tester.pump();

    expect(find.text('Refresh Peak Data?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-refresh-cancel')));
    await tester.pump();

    expect(notifier.refreshCallCount, 0);
    expect(find.byKey(const Key('peak-refresh-status')), findsNothing);
    expect(find.text('Peak Data Refreshed'), findsNothing);
  });

  testWidgets('refresh peak data shows loading state', (tester) async {
    final repository = await TestTasmapRepository.create();
    final completer = Completer<PeakRefreshResult>();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      refreshHandler: () => completer.future,
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
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('refresh-peak-data-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final tile = tester.widget<ListTile>(
      find.byKey(const Key('refresh-peak-data-tile')),
    );
    expect(tile.onTap, isNull);
    expect(notifier.refreshCallCount, 1);

    completer.complete(
      const PeakRefreshResult(importedCount: 2, skippedCount: 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('2 Peaks imported'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('refresh peak data shows result dialog with warning', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      refreshHandler: () async => const PeakRefreshResult(
        importedCount: 3,
        skippedCount: 1,
        warning: '1 peaks skipped',
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
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('refresh-peak-data-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final resultDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('Peak Data Refreshed'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: resultDialog,
        matching: find.text('3 Peaks imported'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: resultDialog, matching: find.text('1 peaks skipped')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-refresh-result-close')), findsOneWidget);
  });

  testWidgets('refresh peak data shows failure dialog', (tester) async {
    final repository = await TestTasmapRepository.create();
    final notifier = TestPeakNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      refreshHandler: () async {
        throw StateError('boom');
      },
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
        child: const App(),
      ),
    );
    await tester.pump();

    router.go('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('refresh-peak-data-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('peak-refresh-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final failureDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: failureDialog,
        matching: find.text('Peak Data Refresh Failed'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: failureDialog, matching: find.textContaining('boom')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-refresh-error-close')), findsOneWidget);
  });
}
