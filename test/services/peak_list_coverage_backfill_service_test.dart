import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/peak_list_coverage_backfill_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('PeakListCoverageBackfillService', () {
    test(
      'migrates legacy memberships, normalizes mixed lists, and marks completion',
      () async {
        SharedPreferences.setMockInitialValues({});
        final peakRepository = PeakRepository.test(
          InMemoryPeakStorage([
            Peak(
              osmId: 101,
              name: 'FVG Peak',
              latitude: 46.4084,
              longitude: 13.0475,
              region: 'fvg',
            ),
            Peak(
              osmId: 202,
              name: 'Veneto Peak',
              latitude: 45.7332,
              longitude: 10.8061,
              region: 'veneto',
            ),
          ]),
        );
        final peakListRepository = PeakListRepository.test(
          InMemoryPeakListStorage([
            PeakList(
              name: 'Italy North East',
              region: Peak.defaultRegion,
              membershipState: PeakList.membershipStatePendingLegacyMigration,
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 101, points: 1),
                const PeakListItem(peakOsmId: 202, points: 1),
              ]),
            )..peakListId = 1,
          ]),
          peakRepository: peakRepository,
        );
        const markerStore = MigrationMarkerStore();

        final changed = await PeakListCoverageBackfillService(
          peakListRepository: peakListRepository,
          migrationMarkerStore: markerStore,
        ).backfillStoredPeakLists();

        final updated = peakListRepository.findById(1)!;
        expect(changed.changed, isTrue);
        expect(changed.unsupportedPeakListIds, isEmpty);
        expect(updated.region, PeakList.mixedRegion);
        expect(updated.minLat, 45.7332);
        expect(updated.maxLat, 46.4084);
        expect(updated.minLng, 10.8061);
        expect(updated.maxLng, 13.0475);
        expect(
          await markerStore.isPeakListMembershipMigrationMarked(),
          isTrue,
        );
      },
    );

    test('runs only once per migration marker', () async {
      SharedPreferences.setMockInitialValues({
        MigrationMarkerStore.peakListMembershipMigrationKey: true,
      });
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(osmId: 101, name: 'Peak', latitude: -41.5, longitude: 146.5),
        ]),
      );
      final peakList = PeakList(
        peakListId: 1,
        name: 'Already Marked',
        peakList: encodePeakListItems([
          const PeakListItem(peakOsmId: 101, points: 1),
        ]),
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([peakList]),
        peakRepository: peakRepository,
        itemStorage: InMemoryPeakListItemEntityStorage([
          PeakListItemEntity(id: 1, points: 1)
            ..peakList.target = peakList
            ..peak.target = peakRepository.findByOsmId(101),
        ]),
      );

      final changed = await PeakListCoverageBackfillService(
        peakListRepository: peakListRepository,
        migrationMarkerStore: MigrationMarkerStore(),
      ).backfillStoredPeakLists();

      expect(changed.changed, isFalse);
      expect(changed.unsupportedPeakListIds, isEmpty);
      expect(peakListRepository.findById(1)?.minLat, isNull);
    });

    test('marks malformed legacy payloads unsupported without partial rows', () async {
      SharedPreferences.setMockInitialValues({});
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          Peak(osmId: 101, name: 'Peak', latitude: -41.5, longitude: 146.5),
        ]),
      );
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Broken',
            membershipState: PeakList.membershipStatePendingLegacyMigration,
            peakList: '{oops}',
          )..peakListId = 1,
        ]),
        peakRepository: peakRepository,
      );

      final result = await PeakListCoverageBackfillService(
        peakListRepository: peakListRepository,
        migrationMarkerStore: const MigrationMarkerStore(),
      ).backfillStoredPeakLists();

      expect(result.changed, isTrue);
      expect(result.unsupportedPeakListIds, [1]);
      expect(peakListRepository.findById(1)?.isUnsupportedLegacy, isTrue);
      expect(() => peakListRepository.getPeakListItemsForList(1), throwsStateError);
    });
  });
}
