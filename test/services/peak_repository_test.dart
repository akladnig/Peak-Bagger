import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/map_search_result.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/route.dart';
import 'package:peak_bagger/models/route_waypoint.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/services/peak_list_derived_data.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  group('PeakRepository', () {
    late InMemoryPeakStorage storage;
    late PeakRepository repository;

    setUp(() {
      storage = InMemoryPeakStorage();
      repository = PeakRepository.test(
        storage,
        peakListRewritePort: _NoopPeakListRewritePort(),
      );
    });

    test('replaceAll swaps stored peaks', () async {
      await repository.addPeaks([
        Peak(name: 'Old Peak', latitude: -41, longitude: 146),
      ]);

      await repository.replaceAll([
        Peak(name: 'New Peak', latitude: -42, longitude: 147),
      ]);

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.name, 'New Peak');
    });

    test('replaceAll preserves ids for matching osmId', () async {
      await repository.addPeaks([
        Peak(
          id: 7,
          osmId: 123,
          name: 'Old Peak',
          latitude: -41,
          longitude: 146,
        ),
      ]);

      await repository.replaceAll([
        Peak(osmId: 123, name: 'New Peak', latitude: -42, longitude: 147),
      ]);

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.id, 7);
      expect(peaks.single.name, 'New Peak');
    });

    test(
      'replaceAll preserves user-owned metadata for matching osmId',
      () async {
        await repository.addPeaks([
          Peak(
            id: 7,
            osmId: 123,
            name: 'Old Peak',
            altName: 'Manual alternate',
            verified: true,
            latitude: -41,
            longitude: 146,
          ),
        ]);

        await repository.replaceAll([
          Peak(osmId: 123, name: 'New Peak', latitude: -42, longitude: 147),
        ]);

        final peak = repository.getAllPeaks().single;

        expect(peak.id, 7);
        expect(peak.name, 'New Peak');
        expect(peak.altName, 'Manual alternate');
        expect(peak.verified, isTrue);
      },
    );

    test('replaceAll rolls back on failure', () async {
      await repository.addPeaks([
        Peak(name: 'Old Peak', latitude: -41, longitude: 146),
      ]);

      expect(
        () => repository.replaceAll(
          [Peak(name: 'New Peak', latitude: -42, longitude: 147)],
          beforePutManyForTest: () {
            throw StateError('boom');
          },
        ),
        throwsStateError,
      );

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(1));
      expect(peaks.single.name, 'Old Peak');
    });

    test('findByOsmId returns the matching peak', () async {
      await repository.addPeaks([
        Peak(osmId: 123, name: 'Cradle', latitude: -41, longitude: 146),
        Peak(osmId: 456, name: 'Ossa', latitude: -42, longitude: 147),
      ]);

      final peak = repository.findByOsmId(456);

      expect(peak, isNotNull);
      expect(peak?.name, 'Ossa');
    });

    test('nextSyntheticOsmId returns the next negative id', () async {
      expect(repository.nextSyntheticOsmId(), -1);

      await repository.addPeaks([
        Peak(osmId: -1, name: 'Synthetic 1', latitude: -41, longitude: 146),
        Peak(osmId: -3, name: 'Synthetic 3', latitude: -42, longitude: 147),
        Peak(osmId: 101, name: 'Cradle', latitude: -41.5, longitude: 146.5),
      ]);

      expect(repository.nextSyntheticOsmId(), -4);
    });

    test(
      'searchPopupPeakCandidates merges name and elevation matches then deduplicates',
      () async {
        await repository.addPeaks([
          Peak(
            osmId: 1,
            name: '12er',
            latitude: -43,
            longitude: 147,
            elevation: 512,
          ),
          Peak(
            osmId: 2,
            name: 'Alpha Peak',
            latitude: -43,
            longitude: 147.1,
            elevation: 1200,
          ),
          Peak(
            osmId: 3,
            name: 'Beta Peak',
            latitude: -43,
            longitude: 147.2,
            elevation: 812,
          ),
        ]);

        final results = repository.searchPopupPeakCandidates(
          query: '12',
          sort: MapSearchSort.nameAscending,
          offset: 0,
          limit: 10,
        );

        expect(results.map((peak) => peak.osmId), [1, 2, 3]);
      },
    );

    test(
      'searchPopupPeakCandidates applies popup ordering tie-breaks before paging',
      () async {
        await repository.addPeaks([
          Peak(osmId: 2, name: 'Alpha Peak', latitude: -43, longitude: 147),
          Peak(osmId: 10, name: 'Alpha Peak', latitude: -43, longitude: 148),
          Peak(osmId: 1, name: 'Alpha Peak', latitude: -43, longitude: 149),
        ]);

        final results = repository.searchPopupPeakCandidates(
          query: 'alpha',
          sort: MapSearchSort.nameDescending,
          offset: 1,
          limit: 1,
        );

        expect(results.single.osmId, 10);
      },
    );

    test(
      'searchPopupPeakCandidates applies popup region filtering before paging',
      () async {
        await repository.addPeaks([
          Peak(
            osmId: 1,
            name: 'FVG Peak',
            latitude: 46.4084,
            longitude: 13.0475,
            elevation: 1906,
            region: 'fvg',
          ),
          Peak(
            osmId: 2,
            name: 'Veneto Peak',
            latitude: 45.7332,
            longitude: 10.8061,
            elevation: 2218,
            region: 'veneto',
          ),
          Peak(
            osmId: 3,
            name: 'Legacy North East Peak',
            latitude: 46.3,
            longitude: 12.9,
            elevation: 1800,
            region: 'italy-nord-est',
          ),
        ]);

        final results = repository.searchPopupPeakCandidates(
          query: 'peak',
          sort: MapSearchSort.nameAscending,
          regionKey: 'fvg',
          offset: 0,
          limit: 10,
        );

        expect(results.map((peak) => peak.name), ['FVG Peak']);
      },
    );

    test('save persists corrected peak fields', () async {
      final original = Peak(
        id: 7,
        osmId: 123,
        name: 'Cradle',
        altName: 'Manual Cradle',
        latitude: -41,
        longitude: 146,
        easting: '10000',
        northing: '20000',
        verified: true,
      );
      await repository.addPeaks([original]);

      await repository.save(
        original.copyWith(
          latitude: -41.2,
          longitude: 146.3,
          elevation: 1545,
          easting: '10123',
          northing: '20123',
          sourceOfTruth: Peak.sourceOfTruthHwc,
        ),
      );

      final peak = repository.findByOsmId(123);

      expect(peak, isNotNull);
      expect(peak?.latitude, -41.2);
      expect(peak?.longitude, 146.3);
      expect(peak?.elevation, 1545);
      expect(peak?.easting, '10123');
      expect(peak?.northing, '20123');
      expect(peak?.altName, 'Manual Cradle');
      expect(peak?.verified, isTrue);
      expect(peak?.sourceOfTruth, Peak.sourceOfTruthHwc);
    });

    test(
      'saveDetailed refreshes cached peak-list bounds after coordinate edits',
      () async {
        final rewritePort = _RecordingPeakListRewritePort(
          peakLists: [
            PeakList(
              name: 'Abels',
              peakList: encodePeakListItems([
                const PeakListItem(peakOsmId: 123, points: 2),
              ]),
            ),
          ],
          peaksBagged: const [],
          peakStorage: storage,
        );
        final detailedRepository = PeakRepository.test(
          storage,
          peakListRewritePort: rewritePort,
        );
        await detailedRepository.addPeaks([
          Peak(
            id: 7,
            osmId: 123,
            name: 'Cradle',
            latitude: -41.0,
            longitude: 146.0,
          ),
        ]);
        rewritePort.peakLists.single
          ..minLat = -41.0
          ..maxLat = -41.0
          ..minLng = 146.0
          ..maxLng = 146.0;

        await detailedRepository.saveDetailed(
          Peak(
            id: 7,
            osmId: 123,
            name: 'Cradle',
            latitude: -42.0,
            longitude: 147.0,
          ),
        );

        expect(rewritePort.peakLists.single.minLat, -42.0);
        expect(rewritePort.peakLists.single.maxLat, -42.0);
        expect(rewritePort.peakLists.single.minLng, 147.0);
        expect(rewritePort.peakLists.single.maxLng, 147.0);
      },
    );

    test('backfillRegion sets all stored peaks to tasmania', () async {
      await repository.addPeaks([
        Peak(
          id: 7,
          osmId: 123,
          name: 'Cradle',
          latitude: -41,
          longitude: 146,
          region: null,
        ),
        Peak(
          id: 8,
          osmId: 456,
          name: 'Ossa',
          latitude: -42,
          longitude: 147,
          region: 'Old Area',
        ),
      ]);

      await repository.backfillRegion(Peak.defaultRegion);

      final peaks = repository.getAllPeaks();

      expect(peaks, hasLength(2));
      expect(peaks.every((peak) => peak.region == Peak.defaultRegion), isTrue);
    });

    test('delete removes the targeted peak', () async {
      await repository.addPeaks([
        Peak(id: 7, osmId: 123, name: 'Cradle', latitude: -41, longitude: 146),
        Peak(id: 8, osmId: 456, name: 'Ossa', latitude: -42, longitude: 147),
      ]);

      await repository.delete(7);

      expect(repository.findById(7), isNull);
      expect(repository.findById(8)?.name, 'Ossa');
    });

    test(
      'resolveDuplicate rewrites supported references and deletes the duplicate peak',
      () async {
        final duplicatePeak = Peak(
          id: 7,
          osmId: 123,
          name: 'Duplicate Peak',
          latitude: -41,
          longitude: 146,
        );
        final survivingPeak = Peak(
          id: 8,
          osmId: 456,
          name: 'Surviving Peak',
          latitude: -41.1,
          longitude: 146.1,
        );
        final otherPeak = Peak(
          id: 9,
          osmId: 999,
          name: 'Other Peak',
          latitude: -42,
          longitude: 147,
        );
        final duplicateTrack =
            GpxTrack(contentHash: 'track-1', trackName: 'Duplicate Track')
              ..gpxTrackId = 21
              ..peaks.addAll([duplicatePeak, otherPeak]);
        final tracks = [duplicateTrack];
        final route = Route(
          id: 31,
          name: 'Duplicate Route',
          routeWaypoints: const [
            RouteWaypoint(
              latitude: -41,
              longitude: 146,
              label: 'Peak stop',
              sequence: 1,
              isPeakDerived: true,
              peakOsmId: 123,
              peakName: 'Old label',
            ),
          ],
        );
        final routes = [route];
        final peakLists = [
          PeakList(
            name: 'Repair List',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 123, points: 4),
              const PeakListItem(peakOsmId: 999, points: 2),
            ]),
          ),
        ];
        final peaksBagged = [
          PeaksBagged(baggedId: 1, peakId: 123, gpxId: 21),
          PeaksBagged(baggedId: 2, peakId: 999, gpxId: 22),
        ];
        final rewritePort = InMemoryPeakListRewritePort(
          peakLists: peakLists,
          peaksBagged: peaksBagged,
          tracks: tracks,
          routes: routes,
          peakStorage: storage,
        );
        final detailedRepository = PeakRepository.test(
          storage,
          peakListRewritePort: rewritePort,
        );
        await detailedRepository.addPeaks([
          duplicatePeak,
          survivingPeak,
          otherPeak,
        ]);

        final result = await detailedRepository.resolveDuplicate(
          duplicatePeak: duplicatePeak,
          survivingPeak: survivingPeak,
        );

        expect(result.isSuccess, isTrue);
        expect(result.survivingPeak?.id, survivingPeak.id);
        expect(detailedRepository.findById(duplicatePeak.id), isNull);
        expect(detailedRepository.findById(survivingPeak.id)?.osmId, 456);
        expect(
          decodePeakListItems(
            peakLists.single.peakList,
          ).map((item) => item.peakOsmId).toList(),
          [456, 999],
        );
        expect(peaksBagged.map((row) => row.peakId).toList(), [456, 999]);
        expect(tracks.single.peaks.map((peak) => peak.osmId).toList(), [
          456,
          999,
        ]);
        expect(routes.single.routeWaypoints.single.peakOsmId, 456);
        expect(routes.single.routeWaypoints.single.peakName, 'Old label');
      },
    );

    test(
      'resolveDuplicate normalizes peak-list, ascent, track, and route collisions',
      () async {
        final duplicatePeak = Peak(
          id: 7,
          osmId: 123,
          name: 'Duplicate Peak',
          latitude: -41,
          longitude: 146,
        );
        final survivingPeak = Peak(
          id: 8,
          osmId: 456,
          name: 'Surviving Peak',
          latitude: -41.1,
          longitude: 146.1,
        );
        final otherPeak = Peak(
          id: 9,
          osmId: 999,
          name: 'Other Peak',
          latitude: -42,
          longitude: 147,
        );
        final track = GpxTrack(contentHash: 'track-2', trackName: 'Collision')
          ..gpxTrackId = 41
          ..peaks.addAll([duplicatePeak, survivingPeak, otherPeak]);
        final tracks = [track];
        final route = Route(
          id: 51,
          name: 'Waypoint Collisions',
          routeWaypoints: const [
            RouteWaypoint(
              latitude: -41,
              longitude: 146,
              label: 'Shared',
              sequence: 1,
              isPeakDerived: true,
              peakOsmId: 123,
              peakName: 'Duplicate label',
            ),
            RouteWaypoint(
              latitude: -41,
              longitude: 146,
              label: 'Shared',
              sequence: 1,
              isPeakDerived: true,
              peakOsmId: 456,
              peakName: 'Duplicate label',
            ),
            RouteWaypoint(
              latitude: -41.2,
              longitude: 146.2,
              label: 'Distinct',
              sequence: 2,
              isPeakDerived: true,
              peakOsmId: 123,
              peakName: 'Distinct label',
            ),
          ],
        );
        final routes = [route];
        final peakLists = [
          PeakList(
            name: 'Collision List',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 123, points: 7),
              const PeakListItem(peakOsmId: 456, points: 9),
              const PeakListItem(peakOsmId: 999, points: 2),
            ]),
          ),
        ];
        final peaksBagged = [
          PeaksBagged(baggedId: 1, peakId: 123, gpxId: 41),
          PeaksBagged(baggedId: 2, peakId: 456, gpxId: 41),
        ];
        final rewritePort = InMemoryPeakListRewritePort(
          peakLists: peakLists,
          peaksBagged: peaksBagged,
          tracks: tracks,
          routes: routes,
          peakStorage: storage,
        );
        final detailedRepository = PeakRepository.test(
          storage,
          peakListRewritePort: rewritePort,
        );
        await detailedRepository.addPeaks([
          duplicatePeak,
          survivingPeak,
          otherPeak,
        ]);

        final result = await detailedRepository.resolveDuplicate(
          duplicatePeak: duplicatePeak,
          survivingPeak: survivingPeak,
        );

        expect(result.isSuccess, isTrue);
        expect(
          decodePeakListItems(
            peakLists.single.peakList,
          ).map((item) => (item.peakOsmId, item.points)).toList(),
          [(456, 7), (999, 2)],
        );
        expect(peaksBagged.map((row) => row.baggedId).toList(), [2]);
        expect(peaksBagged.single.peakId, 456);
        expect(tracks.single.peaks.map((peak) => peak.osmId).toList(), [
          456,
          999,
        ]);
        expect(routes.single.routeWaypoints, hasLength(2));
        expect(
          routes.single.routeWaypoints
              .map((waypoint) => waypoint.label)
              .toList(),
          ['Shared', 'Distinct'],
        );
        expect(
          routes.single.routeWaypoints
              .map((waypoint) => waypoint.peakOsmId)
              .toList(),
          [456, 456],
        );
      },
    );

    test(
      'resolveDuplicate rolls back earlier rewrites when a later write fails',
      () async {
        final duplicatePeak = Peak(
          id: 7,
          osmId: 123,
          name: 'Duplicate Peak',
          latitude: -41,
          longitude: 146,
        );
        final survivingPeak = Peak(
          id: 8,
          osmId: 456,
          name: 'Surviving Peak',
          latitude: -41.1,
          longitude: 146.1,
        );
        final track = GpxTrack(contentHash: 'track-3', trackName: 'Rollback')
          ..gpxTrackId = 61
          ..peaks.add(duplicatePeak);
        final tracks = [track];
        final route = Route(
          id: 71,
          name: 'Rollback Route',
          routeWaypoints: const [
            RouteWaypoint(
              latitude: -41,
              longitude: 146,
              label: 'Rollback',
              sequence: 1,
              isPeakDerived: true,
              peakOsmId: 123,
            ),
          ],
        );
        final routes = [route];
        final peakLists = [
          PeakList(
            name: 'Rollback List',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 123, points: 5),
            ]),
          ),
        ];
        final peaksBagged = [PeaksBagged(baggedId: 1, peakId: 123, gpxId: 61)];
        final rewritePort = InMemoryPeakListRewritePort(
          peakLists: peakLists,
          peaksBagged: peaksBagged,
          tracks: tracks,
          routes: routes,
          peakStorage: storage,
          beforeApplyTrackWritesForTest: () {
            throw StateError('boom');
          },
        );
        final detailedRepository = PeakRepository.test(
          storage,
          peakListRewritePort: rewritePort,
        );
        await detailedRepository.addPeaks([duplicatePeak, survivingPeak]);

        final result = await detailedRepository.resolveDuplicate(
          duplicatePeak: duplicatePeak,
          survivingPeak: survivingPeak,
        );

        expect(result.isSuccess, isFalse);
        expect(result.failureMessage, contains('boom'));
        expect(detailedRepository.findById(duplicatePeak.id), isNotNull);
        expect(
          decodePeakListItems(
            peakLists.single.peakList,
          ).map((item) => item.peakOsmId).toList(),
          [123],
        );
        expect(peaksBagged.single.peakId, 123);
        expect(tracks.single.peaks.map((peak) => peak.osmId).toList(), [123]);
        expect(routes.single.routeWaypoints.single.peakOsmId, 123);
      },
    );

    test(
      'saveDetailed rewrites dependent PeakList and PeaksBagged rows',
      () async {
        final peakLists = [
          PeakList(
            name: 'Abels',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 123, points: 2),
              const PeakListItem(peakOsmId: 999, points: 4),
            ]),
          ),
          PeakList(name: 'Broken', peakList: '{not json'),
        ];
        final peaksBagged = [
          PeaksBagged(baggedId: 1, peakId: 123, gpxId: 7),
          PeaksBagged(baggedId: 2, peakId: 999, gpxId: 8),
        ];
        final detailedStorage = InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 123,
            name: 'Cradle',
            latitude: -41,
            longitude: 146,
          ),
        ]);
        final rewritePort = _RecordingPeakListRewritePort(
          peakLists: peakLists,
          peaksBagged: peaksBagged,
          peakStorage: detailedStorage,
        );
        final detailedRepository = PeakRepository.test(
          detailedStorage,
          peakListRewritePort: rewritePort,
        );

        final result = await detailedRepository.saveDetailed(
          Peak(
            id: 7,
            osmId: 456,
            name: 'Cradle',
            latitude: -41.2,
            longitude: 146.3,
          ),
        );

        expect(result.peak.osmId, 456);
        expect(result.peak.latitude, -41.2);
        expect(result.peakListRewriteResult?.rewrittenCount, 1);
        expect(result.peakListRewriteResult?.skippedMalformedCount, 1);
        expect(
          result.peakListRewriteResult?.warningMessage,
          "1 PeakList has been skipped as it's malformed.",
        );
        expect(
          decodePeakListItems(
            peakLists.first.peakList,
          ).map((item) => item.peakOsmId).toList(),
          [456, 999],
        );
        expect(peaksBagged.first.peakId, 456);
        expect(peaksBagged.last.peakId, 999);
      },
    );

    test(
      'saveDetailed rewrites relational peak-list memberships without updating stale legacy payloads',
      () async {
        final peakList = PeakList(
          peakListId: 1,
          name: 'Relational',
          peakList: '[]',
        );
        final detailedStorage = InMemoryPeakStorage([
          Peak(
            id: 7,
            osmId: 123,
            name: 'Cradle',
            latitude: -41,
            longitude: 146,
          ),
        ]);
        final peakListItems = [
          PeakListItemEntity(id: 1, points: 2)
            ..peakList.target = peakList
            ..peak.target = Peak(
              id: 7,
              osmId: 123,
              name: 'Cradle',
              latitude: -41,
              longitude: 146,
            ),
        ];
        final rewritePort = InMemoryPeakListRewritePort(
          peakLists: [peakList],
          peakListItems: peakListItems,
          peaksBagged: [PeaksBagged(baggedId: 1, peakId: 123, gpxId: 7)],
          tracks: const [],
          routes: const [],
          peakStorage: detailedStorage,
        );
        final detailedRepository = PeakRepository.test(
          detailedStorage,
          peakListRewritePort: rewritePort,
        );

        final result = await detailedRepository.saveDetailed(
          Peak(
            id: 7,
            osmId: 456,
            name: 'Cradle',
            latitude: -41.2,
            longitude: 146.3,
          ),
        );

        expect(result.peak.osmId, 456);
        expect(peakList.peakList, '[]');
        expect(peakListItems.single.peak.target?.osmId, 456);
      },
    );

    test(
      'searchPopupPeakCandidates stays deterministic across storage implementations',
      () async {
        final peaks = [
          Peak(
            osmId: 2,
            name: 'Alpha Peak',
            latitude: -33.7,
            longitude: 149.0,
            elevation: 1200,
            region: 'new-south-wales',
          ),
          Peak(
            osmId: 10,
            name: 'Alpha Peak',
            latitude: -33.8,
            longitude: 149.1,
            elevation: 912,
            region: 'new-south-wales',
          ),
          Peak(
            osmId: 3,
            name: 'Zeta Peak',
            latitude: -43,
            longitude: 147,
            elevation: 812,
          ),
        ];
        final tempDir = await Directory.systemTemp.createTemp('peak-popup');
        addTearDown(() async {
          if (tempDir.existsSync()) {
            await tempDir.delete(recursive: true);
          }
        });
        final store = await openStore(directory: tempDir.path);
        addTearDown(store.close);

        final objectBoxRepository = PeakRepository.test(
          ObjectBoxPeakStorage(store),
          peakListRewritePort: _NoopPeakListRewritePort(),
        );
        final inMemoryRepository = PeakRepository.test(
          InMemoryPeakStorage(peaks),
          peakListRewritePort: _NoopPeakListRewritePort(),
        );
        await objectBoxRepository.addPeaks(peaks);

        final objectBoxResults = objectBoxRepository.searchPopupPeakCandidates(
          query: '12',
          sort: MapSearchSort.nameAscending,
          regionKey: 'new-south-wales',
          offset: 0,
          limit: 10,
        );
        final inMemoryResults = inMemoryRepository.searchPopupPeakCandidates(
          query: '12',
          sort: MapSearchSort.nameAscending,
          regionKey: 'new-south-wales',
          offset: 0,
          limit: 10,
        );

        expect(
          objectBoxResults.map((peak) => peak.osmId).toList(),
          inMemoryResults.map((peak) => peak.osmId).toList(),
        );
      },
      skip: 'ObjectBox native library unavailable in flutter test environment',
    );
  });
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

class _RecordingPeakListRewritePort implements PeakListRewritePort {
  _RecordingPeakListRewritePort({
    required this.peakLists,
    required this.peaksBagged,
    required this.peakStorage,
  });

  final List<PeakList> peakLists;
  final List<PeaksBagged> peaksBagged;
  final InMemoryPeakStorage peakStorage;

  @override
  PeakListRewriteResult rewriteOsmIdReferences({
    required int oldOsmId,
    required int newOsmId,
  }) {
    var rewrittenCount = 0;
    var skippedMalformedCount = 0;

    for (final peakList in peakLists) {
      try {
        final items = decodePeakListItems(peakList.peakList);
        var changed = false;
        final updatedItems = <PeakListItem>[];
        for (final item in items) {
          if (item.peakOsmId == oldOsmId) {
            updatedItems.add(
              PeakListItem(peakOsmId: newOsmId, points: item.points),
            );
            changed = true;
          } else {
            updatedItems.add(item);
          }
        }
        if (changed) {
          rewrittenCount += 1;
          peakList.peakList = encodePeakListItems(updatedItems);
        }
      } catch (_) {
        skippedMalformedCount += 1;
      }
    }

    for (final row in peaksBagged) {
      if (row.peakId == oldOsmId) {
        row.peakId = newOsmId;
      }
    }

    return PeakListRewriteResult(
      rewrittenCount: rewrittenCount,
      skippedMalformedCount: skippedMalformedCount,
    );
  }

  @override
  int refreshDerivedDataForPeakReferences({
    required Peak previousPeak,
    required Peak updatedPeak,
  }) {
    final peaksByOsmId = {
      for (final peak in peakStorage.getAll()) peak.osmId: peak,
    };
    final refreshedOsmIds = {previousPeak.osmId, updatedPeak.osmId};
    var refreshedCount = 0;

    for (var index = 0; index < peakLists.length; index++) {
      final peakList = peakLists[index];
      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        continue;
      }
      if (!items.any((item) => refreshedOsmIds.contains(item.peakOsmId))) {
        continue;
      }

      final derivedData = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (peakOsmId) => peaksByOsmId[peakOsmId],
      );
      peakLists[index] = derivedData.applyTo(peakList);
      refreshedCount += 1;
    }

    return refreshedCount;
  }

  @override
  void resolvePeakDuplicate({
    required Peak duplicatePeak,
    required Peak survivingPeak,
    required PeakStorage peakStorage,
  }) {
    throw UnimplementedError();
  }
}
