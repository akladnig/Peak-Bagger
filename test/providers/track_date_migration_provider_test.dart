import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/local_data_load_outcome_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/track_date_migration_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/services/track_replacement_recovery_issue_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';
import 'package:peak_bagger/services/track_date_migration_repository.dart';
import 'package:peak_bagger/services/track_date_migration_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/mapping_catalog_fixture.dart';
import '../harness/test_tasmap_repository.dart';
import '../harness/track_date_fixtures.dart';
import '../harness/track_date_migration_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(expectTrackDateHostOffsets);

  test(
    'eager Map startup waits before Track/ascent backfills and publishes committed dates with absent installation flags',
    () async {
      SharedPreferences.setMockInitialValues({});
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      final track = fixture.store.box<GpxTrack>().get(7)!..visible = false;
      fixture.store.box<GpxTrack>().put(track);
      final before = fixture.snapshot.fingerprint;
      final entered = Completer<void>();
      final release = Completer<void>();
      final service = fixture.service(
        yieldToUi: () {
          if (!entered.isCompleted) entered.complete();
          return release.future;
        },
      );
      addTearDown(service.dispose);
      final tasmap = await TestTasmapRepository.create();
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          trackDateMigrationServiceProvider.overrideWithValue(service),
          mapProvider.overrideWith(
            () => MapNotifier(
              mappingCatalog: testMappingCatalog,
              peakRepository: PeakRepository.test(InMemoryPeakStorage()),
              tasmapRepository: tasmap,
              gpxTrackRepository: GpxTrackRepository(fixture.store),
              peaksBaggedRepository: PeaksBaggedRepository(fixture.store),
              routeRepository: RouteRepository.test(InMemoryRouteStorage()),
              waypointsRepository: WaypointsRepository.test(
                InMemoryWaypointsStorage(),
              ),
              trackReplacementRecoveryIssueStore:
                  InMemoryTrackReplacementRecoveryIssueStore(),
              loadPositionOnBuild: false,
              loadPeaksOnBuild: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final loaded = Completer<void>();
      container.listen(mapDashboardLoadProvider, (_, next) {
        if (next.hasError && !loaded.isCompleted) {
          loaded.completeError(next.error!, next.stackTrace);
        } else if (!next.isLoading && !loaded.isCompleted) {
          loaded.complete();
        }
      });
      container.read(mapProvider);
      await entered.future;
      expect(container.read(mapDashboardLoadProvider).isLoading, isTrue);
      expect(container.read(mapProvider).tracks, isEmpty);
      expect(fixture.snapshot.fingerprint, before);
      expect(fixture.metadata, isNull);
      release.complete();
      await loaded.future.timeout(const Duration(seconds: 10));
      final projected = container.read(mapProvider).tracks;
      expect(projected.map((track) => track.gpxTrackId), [7, 8, 9, 10, 11]);
      expect(
        projected.singleWhere((track) => track.gpxTrackId == 7).trackDate,
        DateTime.utc(2027),
      );
      expect(
        projected.singleWhere((track) => track.gpxTrackId == 7).visible,
        isTrue,
      );
      expect(
        projected
            .singleWhere((track) => track.gpxTrackId == 11)
            .trackDateStatus,
        3,
      );
      final rows = fixture.snapshot.ascents;
      expect(rows.map((row) => row.baggedId), [70, 80, 90, 100, 110]);
      expect(
        rows.singleWhere((row) => row.gpxId == 7).date,
        DateTime.utc(2027),
      );
      expect(
        rows.singleWhere((row) => row.gpxId == 10).date,
        DateTime.utc(2026, 12, 31, 13),
      );
      expect(rows.singleWhere((row) => row.gpxId == 11).date, isNull);
      expect(fixture.metadata!.completedVersion, 1);
    },
  );

  test(
    'startup protects duplicate retries, publishes progress and success only after durable commit',
    () async {
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      final entered = Completer<void>();
      final release = Completer<void>();
      final service = fixture.service(
        yieldToUi: () {
          if (!entered.isCompleted) entered.complete();
          return release.future;
        },
      );
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          trackDateMigrationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      final states = <TrackDateMigrationState>[];
      container.listen(
        trackDateMigrationProvider,
        (_, next) => states.add(next),
        fireImmediately: true,
      );
      final bootstrap = container.read(
        trackDateMigrationBootstrapProvider.future,
      );
      await entered.future;
      expect(container.read(trackDateMigrationProvider).isReady, isFalse);
      expect(fixture.metadata, isNull);
      final notifier = container.read(trackDateMigrationProvider.notifier);
      final a = notifier.ensureCurrent();
      final b = notifier.ensureCurrent();
      expect(identical(a, b), isTrue);
      release.complete();
      expect(await bootstrap, isTrue);
      expect(await a, isTrue);
      expect(states.last.status, TrackDateMigrationStatus.completed);
      expect(states.last.result!.metadata.skippedCount, 2);
      expect(fixture.metadata!.completedVersion, 1);
      expect(
        states.where(
          (s) => s.progress?.phase == TrackDateMigrationPhase.committing,
        ),
        isNotEmpty,
      );
      expect(await notifier.ensureCurrent(), isTrue);
    },
  );

  test(
    'operational commit failure remains visible and retries safely in the same app scope',
    () async {
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      var fail = true;
      final before = fixture.snapshot.fingerprint;
      final service = fixture.service(
        repository: ObjectBoxTrackDateMigrationRepository(
          fixture.store,
          beforeWriteForTest: (stage) {
            if (stage == TrackDateMigrationWriteStage.completion && fail) {
              throw StateError('Disk failure');
            }
          },
        ),
      );
      addTearDown(service.dispose);
      final container = ProviderContainer(
        overrides: [
          trackDateMigrationServiceProvider.overrideWithValue(service),
        ],
      );
      addTearDown(container.dispose);
      expect(
        await container.read(trackDateMigrationBootstrapProvider.future),
        isFalse,
      );
      expect(
        container.read(trackDateMigrationProvider).status,
        TrackDateMigrationStatus.failed,
      );
      expect(
        container.read(trackDateMigrationProvider).error,
        isA<StateError>(),
      );
      expect(fixture.snapshot.fingerprint, before);
      expect(fixture.metadata, isNull);
      fail = false;
      expect(
        await container
            .read(trackDateMigrationProvider.notifier)
            .ensureCurrent(),
        isTrue,
      );
      expect(container.read(trackDateMigrationProvider).isReady, isTrue);
      expect(fixture.metadata!.updatedCount, 2);
    },
  );

  test(
    'disposing app scope during preparation publishes no stale state and commits nothing',
    () async {
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      final entered = Completer<void>();
      final release = Completer<void>();
      final container = ProviderContainer(
        overrides: [
          trackDateMigrationRepositoryProvider.overrideWithValue(
            ObjectBoxTrackDateMigrationRepository(fixture.store),
          ),
          trackDateMigrationServiceProvider.overrideWith((ref) {
            final service = fixture.service(
              yieldToUi: () {
                if (!entered.isCompleted) entered.complete();
                return release.future;
              },
            );
            ref.onDispose(service.dispose);
            return service;
          }),
        ],
      );
      final attempt = container
          .read(trackDateMigrationProvider.notifier)
          .ensureCurrent();
      await entered.future;
      container.dispose();
      release.complete();
      expect(await attempt, isFalse);
      expect(fixture.metadata, isNull);
    },
  );
}
