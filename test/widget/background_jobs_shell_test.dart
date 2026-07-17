import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/background_jobs_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/objectbox_admin_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_delete_guard.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_objectbox_admin_repository.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    router = createRouter();
  });

  testWidgets(
    'app bar entry appears on every shell destination when jobs exist',
    (tester) async {
      await _pumpApp(tester);

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

      for (final navKey in const [
        'nav-dashboard',
        'nav-map',
        'nav-peak-lists',
        'nav-objectbox-admin',
        'nav-settings',
      ]) {
        await tester.tap(find.byKey(Key(navKey)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);
      }
    },
  );

  testWidgets('panel opens as shell overlay and keeps navigation usable', (
    tester,
  ) async {
    await _pumpApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const Key('shared-app-bar'))),
    );
    container
        .read(backgroundJobsProvider.notifier)
        .startJob(
          kind: BackgroundJobKind.importPeakList,
          label: 'Import Peak List',
          progress: BackgroundJobProgress(
            label: 'Rows processed',
            statusText: '10 / 100 rows',
            currentFileName: 'peaks.csv',
            percent: 0.1,
          ),
        );
    await tester.pump();

    await tester.tap(find.byKey(const Key('background-jobs-entry')));
    await tester.pump();

    expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
    expect(find.text('Import Peak List'), findsOneWidget);
    expect(
      find.byKey(const Key('background-jobs-file-background-job-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('nav-settings')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('app-bar-title')),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'running job stays first and finished jobs can be dismissed or cleared',
    (tester) async {
      await _pumpApp(tester);

      final container = ProviderScope.containerOf(
        tester.element(find.byKey(const Key('shared-app-bar'))),
      );
      final notifier = container.read(backgroundJobsProvider.notifier);
      final completed = notifier.startJob(
        kind: BackgroundJobKind.exportPeakData,
        label: 'Export Peak Data',
      );
      notifier.completeRunningJob(
        jobId: completed.job!.id,
        summary: 'Exported 42 rows',
      );
      final failed = notifier.startJob(
        kind: BackgroundJobKind.exportPeakLists,
        label: 'Export Peak Lists',
      );
      notifier.failRunningJob(jobId: failed.job!.id, summary: 'Export failed');
      notifier.startJob(
        kind: BackgroundJobKind.importPeakList,
        label: 'Import Peak List',
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('background-jobs-entry')));
      await tester.pump();

      final runningTop = tester
          .getTopLeft(
            find.byKey(const Key('background-jobs-row-background-job-3')),
          )
          .dy;
      final finishedTop = tester
          .getTopLeft(
            find.byKey(const Key('background-jobs-row-background-job-2')),
          )
          .dy;
      expect(runningTop, lessThan(finishedTop));
      expect(
        find.byKey(const Key('background-jobs-dismiss-background-job-3')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const Key('background-jobs-dismiss-background-job-2')),
      );
      await tester.pump();
      expect(
        find.byKey(const Key('background-jobs-row-background-job-2')),
        findsNothing,
      );

      await tester.tap(find.byKey(const Key('background-jobs-clear-finished')));
      await tester.pump();
      expect(
        find.byKey(const Key('background-jobs-row-background-job-1')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('background-jobs-row-background-job-3')),
        findsOneWidget,
      );
    },
  );

  testWidgets('recovery snackbar does not auto-open panel and can open jobs', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'background_jobs_interrupted_job_v1':
          '{"kind":"importPeakList","label":"Import Peak List","startedAt":"2026-07-12T08:30:00.000"}',
    });
    final prefs = await SharedPreferences.getInstance();

    await _pumpApp(
      tester,
      overrides: [
        bootstrappedBackgroundJobsPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    await tester.pump();

    expect(find.text('Import cancelled when app was closed'), findsOneWidget);
    expect(find.byKey(const Key('background-jobs-panel')), findsNothing);
    expect(find.byKey(const Key('background-jobs-entry')), findsOneWidget);

    tester
        .widget<TextButton>(
          find.byKey(const Key('background-jobs-snackbar-open-jobs')),
        )
        .onPressed!();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('background-jobs-panel')), findsOneWidget);
    expect(find.text('Import Peak List'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, {List overrides = const []}) async {
  final tasmapRepository = await TestTasmapRepository.create();

  await tester.binding.setSurfaceSize(const Size(1280, 900));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        peaksBaggedRepositoryProvider.overrideWithValue(
          PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage()),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        overpassServiceProvider.overrideWithValue(OverpassService()),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        peakListRewritePortProvider.overrideWithValue(
          _NoopPeakListRewritePort(),
        ),
        peakDeleteGuardProvider.overrideWithValue(
          PeakDeleteGuard(_NoopPeakDeleteGuardSource()),
        ),
        objectboxAdminRepositoryProvider.overrideWithValue(
          TestObjectBoxAdminRepository(),
        ),
        ...overrides,
      ],
      child: const App(),
    ),
  );
  await tester.pump();
}

class _NoopPeakListRewritePort implements PeakListRewritePort {
  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    return const PeakListRewriteResult(
      rewrittenCount: 0,
      skippedMalformedCount: 0,
    );
  }

  @override
  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  }) {
    return 0;
  }

  @override
  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  }) {}
}

class _NoopPeakDeleteGuardSource implements PeakDeleteGuardSource {
  @override
  List<GpxTrack> loadGpxTracks() => const [];

  @override
  List<PeakList> loadPeakLists() => const [];

  @override
  List<PeaksBagged> loadPeaksBagged() => const [];
}
