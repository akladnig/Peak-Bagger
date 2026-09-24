import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/natural_feature.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/natural_feature_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/natural_feature_refresh_service.dart';
import 'package:peak_bagger/services/natural_feature_repository.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  setUp(() {
    router = createRouter();
  });

  testWidgets('places the tile below peak refresh and hands off immediately', (
    tester,
  ) async {
    final completer = Completer<NaturalFeatureRefreshResult>();
    var calls = 0;
    await _pumpSettings(
      tester,
      runner: () {
        calls += 1;
        return completer.future;
      },
    );
    await _scrollNaturalFeatureTileIntoView(tester);

    final peakTop = tester
        .getTopLeft(find.byKey(const Key('refresh-peak-data-tile')))
        .dy;
    final naturalFeatureTop = tester
        .getTopLeft(find.byKey(const Key('refresh-natural-features-tile')))
        .dy;
    expect(naturalFeatureTop, greaterThan(peakTop));
    expect(
      find.text('Import Tasmanian natural features from the local source file'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('refresh-natural-features-tile')));
    await tester.pump();

    expect(calls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);
    expect(
      tester
          .widget<ListTile>(
            find.byKey(const Key('refresh-natural-features-tile')),
          )
          .onTap,
      isNull,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('refresh-natural-features-tile')),
        matching: find.byType(CircularProgressIndicator),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<ListTile>(find.byKey(const Key('refresh-route-graph-tile')))
          .onTap,
      isNull,
    );

    await tester.tap(find.byKey(const Key('nav-dashboard')));
    await tester.pump();
    expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);

    completer.complete(
      const NaturalFeatureRefreshResult(
        createdCount: 2,
        updatedCount: 3,
        protectedCount: 4,
        skippedCount: 5,
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('background-jobs-expand-background-job-1')),
    );
    await tester.pump();
    expect(
      find.text(
        'Natural features refreshed: 2 created, 3 updated, 4 protected, 5 skipped.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('refuses a natural feature refresh while another job runs', (
    tester,
  ) async {
    var calls = 0;
    final repository = NaturalFeatureRepository.test(
      InMemoryNaturalFeatureStorage([
        NaturalFeature(
          name: 'Stored feature',
          tag: 'lake',
          latitude: -42,
          longitude: 146,
          osmId: 1,
          osmType: 'node',
        ),
      ]),
    );
    await _pumpSettings(
      tester,
      repository: repository,
      runner: () async {
        calls += 1;
        return const NaturalFeatureRefreshResult(
          createdCount: 0,
          updatedCount: 0,
          protectedCount: 0,
          skippedCount: 0,
        );
      },
    );
    await _scrollNaturalFeatureTileIntoView(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    container
        .read(backgroundJobsProvider.notifier)
        .startJob(
          kind: BackgroundJobKind.importPeakList,
          label: 'Import Peak List',
        );
    await tester.pump();

    await tester.tap(find.byKey(const Key('refresh-natural-features-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(calls, 0);
    expect(repository.getAllNaturalFeatures().single.name, 'Stored feature');
    expect(find.text('Import Peak List is already running.'), findsOneWidget);
  });

  testWidgets('shows an error dialog and status when refresh fails', (
    tester,
  ) async {
    await _pumpSettings(
      tester,
      runner: () async => throw StateError('source invalid'),
    );
    await _scrollNaturalFeatureTileIntoView(tester);

    await tester.tap(find.byKey(const Key('refresh-natural-features-tile')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text('Error refreshing natural features: Bad state: source invalid'),
      findsWidgets,
    );
    expect(find.text('Natural Feature Refresh Failed'), findsOneWidget);
    expect(
      find.byKey(const Key('natural-feature-refresh-error-close')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required NaturalFeatureRefreshRunner runner,
  NaturalFeatureRepository? repository,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  final peakNotifier = TestPeakNotifier(
    MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
    ),
  );
  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => peakNotifier),
        naturalFeatureRefreshRunnerProvider.overrideWithValue(runner),
        if (repository != null)
          naturalFeatureRepositoryProvider.overrideWithValue(repository),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/settings');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  expect(find.byKey(const Key('settings-scrollable')), findsOneWidget);
}

Future<void> _scrollNaturalFeatureTileIntoView(WidgetTester tester) async {
  final tile = find.byKey(const Key('refresh-natural-features-tile'));
  final settings = find.byKey(const Key('settings-scrollable'));
  for (var index = 0; index < 4 && tile.evaluate().isEmpty; index++) {
    await tester.drag(settings, const Offset(0, -300));
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(tile, findsOneWidget);
}
