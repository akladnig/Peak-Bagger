import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/track_date_migration_metadata.dart';
import 'package:peak_bagger/services/track_date_migration_service.dart';

import '../harness/track_date_fixtures.dart';
import '../harness/track_date_migration_fixture.dart';

void main() {
  setUpAll(expectTrackDateHostOffsets);

  test(
    'preparation progresses outside transactions; interrupted run leaves no writes and next launch retries',
    () async {
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      final before = fixture.snapshot.fingerprint;
      final progress = <TrackDateMigrationProgress>[];
      var yields = 0;
      final service = fixture.service(
        yieldToUi: () async {
          if (++yields == 3) throw StateError('Interrupted during preparation');
          // A separate read is usable while preparation yields; no writes yet.
          expect(fixture.snapshot.fingerprint, before);
        },
      );
      await expectLater(
        service.run(onProgress: progress.add),
        throwsStateError,
      );
      expect(fixture.metadata, isNull);
      expect(fixture.snapshot.fingerprint, before);
      expect(progress.last.processed, 2);
      final resumed = <TrackDateMigrationProgress>[];
      final result = await fixture.service().run(onProgress: resumed.add);
      expect(result.alreadyCompleted, isFalse);
      expect(resumed.map((p) => p.processed), [0, 1, 2, 3, 4, 5, 5]);
      expect(resumed.last.phase, TrackDateMigrationPhase.committing);
      expect(fixture.metadata!.completedVersion, 1);
    },
  );

  test(
    'completed database reopens without scanning; removing marker models older backup independent of installation',
    () async {
      final fixture = await TrackDateMigrationFixture.create();
      addTearDown(fixture.dispose);
      await fixture.service().run();
      var scans = 0;
      final result = await fixture
          .service(
            derivation: () {
              scans++;
              throw StateError('Must not scan');
            },
          )
          .run();
      expect(result.alreadyCompleted, isTrue);
      expect(scans, 0);
      fixture.store.box<TrackDateMigrationMetadata>().removeAll();
      final restored = await fixture.service().run();
      expect(restored.alreadyCompleted, isFalse);
      expect(
        (
          restored.metadata.updatedCount,
          restored.metadata.unchangedCount,
          restored.metadata.skippedCount,
        ),
        (0, 3, 2),
      );
    },
  );

  test(
    'empty database marks zero counts without initializing geographic data',
    () async {
      final fixture = await TrackDateMigrationFixture.create(seed: false);
      addTearDown(fixture.dispose);
      final result = await fixture
          .service(derivation: () => throw StateError('No data to resolve'))
          .run();
      expect(
        (
          result.metadata.updatedCount,
          result.metadata.unchangedCount,
          result.metadata.skippedCount,
        ),
        (0, 0, 0),
      );
      expect(fixture.metadata!.completedVersion, 1);
      expect((await fixture.service().run()).alreadyCompleted, isTrue);
    },
  );

  test(
    'duplicate starts share attempt; application-owner disposal prevents commit after pending preparation',
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
      final first = service.run();
      final second = service.run();
      expect(identical(first, second), isTrue);
      await entered.future;
      service.dispose();
      final assertion = expectLater(first, throwsStateError);
      release.complete();
      await assertion;
      expect(fixture.metadata, isNull);
      await fixture.service().run();
      expect(fixture.metadata!.completedVersion, 1);
    },
  );
}
