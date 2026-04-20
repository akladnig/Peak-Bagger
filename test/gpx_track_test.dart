import 'dart:convert';
import 'dart:math' as math;
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';
import 'package:peak_bagger/services/migration_marker_store.dart';
import 'package:peak_bagger/services/overpass_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness/test_map_notifier.dart';

const _distance = Distance();

void main() {
  group('TrackHoverDetector', () {
    test('returns no match when all segments are outside threshold', () {
      final result = TrackHoverDetector.findHoveredTrack(
        pointerPosition: const Offset(50, 50),
        candidates: const [
          TrackHoverCandidate(
            trackId: 1,
            segments: [
              [Offset(0, 0), Offset(0, 10)],
            ],
          ),
        ],
      );

      expect(result.hoveredTrackId, isNull);
      expect(result.distance, isNull);
    });

    test('returns hovered track when a segment is inside threshold', () {
      final result = TrackHoverDetector.findHoveredTrack(
        pointerPosition: const Offset(5, 6),
        candidates: const [
          TrackHoverCandidate(
            trackId: 7,
            segments: [
              [Offset(0, 0), Offset(10, 0)],
            ],
          ),
        ],
      );

      expect(result.hoveredTrackId, 7);
      expect(result.distance, closeTo(6, 0.001));
    });

    test('ignores one-point segments', () {
      final result = TrackHoverDetector.findHoveredTrack(
        pointerPosition: const Offset(5, 5),
        candidates: const [
          TrackHoverCandidate(
            trackId: 1,
            segments: [
              [Offset(5, 5)],
            ],
          ),
          TrackHoverCandidate(
            trackId: 2,
            segments: [
              [Offset(0, 0), Offset(10, 0)],
            ],
          ),
        ],
      );

      expect(result.hoveredTrackId, 2);
      expect(result.distance, closeTo(5, 0.001));
    });

    test('chooses nearest track and keeps first match on ties', () {
      final nearer = TrackHoverDetector.findHoveredTrack(
        pointerPosition: const Offset(10, 10),
        candidates: const [
          TrackHoverCandidate(
            trackId: 1,
            segments: [
              [Offset(0, 0), Offset(20, 0)],
            ],
          ),
          TrackHoverCandidate(
            trackId: 2,
            segments: [
              [Offset(0, 8), Offset(20, 8)],
            ],
          ),
        ],
      );

      final tie = TrackHoverDetector.findHoveredTrack(
        pointerPosition: const Offset(10, 10),
        candidates: const [
          TrackHoverCandidate(
            trackId: 3,
            segments: [
              [Offset(0, 6), Offset(20, 6)],
            ],
          ),
          TrackHoverCandidate(
            trackId: 4,
            segments: [
              [Offset(0, 14), Offset(20, 14)],
            ],
          ),
        ],
      );

      expect(nearer.hoveredTrackId, 2);
      expect(nearer.distance, closeTo(2, 0.001));
      expect(tie.hoveredTrackId, 3);
      expect(tie.distance, closeTo(4, 0.001));
    });
  });

  group('TrackDisplayCacheBuilder', () {
    test('builds caches for zooms 6 through 18 preserving segments', () {
      final json = TrackDisplayCacheBuilder.buildJson([
        [
          const LatLng(-42.10, 146.10),
          const LatLng(-42.15, 146.15),
          const LatLng(-42.20, 146.20),
        ],
        [const LatLng(-42.30, 146.30)],
      ]);

      final decoded = GpxTrack.decodeDisplayTrackPointsByZoom(json);

      expect(decoded.keys.first, 6);
      expect(decoded.keys.last, 18);
      expect(decoded[6], hasLength(2));
      expect(decoded[18], hasLength(2));
      expect(decoded[6]!.first.first.latitude, -42.10);
      expect(decoded[18]!.first.last.longitude, 146.20);
      expect(decoded[6]!.last.single.latitude, -42.30);
    });

    test('simplifies dense straight segment to endpoints', () {
      final json = TrackDisplayCacheBuilder.buildJson([
        [
          const LatLng(-42.1000, 146.1000),
          const LatLng(-42.1005, 146.1005),
          const LatLng(-42.1010, 146.1010),
          const LatLng(-42.1015, 146.1015),
          const LatLng(-42.1020, 146.1020),
        ],
      ]);

      final decoded = GpxTrack.decodeDisplayTrackPointsByZoom(json);
      final segment = decoded[15]!.single;

      expect(segment, hasLength(2));
      expect(segment.first.latitude, -42.1000);
      expect(segment.last.longitude, 146.1020);
    });

    test('retains more switchback detail at higher zooms', () {
      final json = TrackDisplayCacheBuilder.buildJson([
        [
          const LatLng(-42.1000, 146.1000),
          const LatLng(-42.1006, 146.1002),
          const LatLng(-42.1001, 146.1008),
          const LatLng(-42.1009, 146.1010),
          const LatLng(-42.1002, 146.1016),
          const LatLng(-42.1010, 146.1018),
        ],
      ]);

      final decoded = GpxTrack.decodeDisplayTrackPointsByZoom(json);

      expect(decoded[18]!.single.length, greaterThan(2));
      expect(
        decoded[18]!.single.length,
        greaterThan(decoded[6]!.single.length),
      );
    });
  });

  group('MigrationMarkerStore', () {
    test('marks migration as complete', () async {
      SharedPreferences.setMockInitialValues({});
      const store = MigrationMarkerStore();

      expect(await store.isMarked(), isFalse);

      await store.markComplete();

      expect(await store.isMarked(), isTrue);
    });

    test('decides first startup with legacy rows should wipe then import', () {
      final decision = MigrationMarkerStore.decideStartupAction(
        migrationMarked: false,
        hasPersistedTracks: true,
        hasRecoveryIssue: true,
      );

      expect(decision.action, TrackStartupAction.wipeAndImport);
      expect(decision.markMigrationComplete, isTrue);
    });

    test('decides empty first startup should mark then import', () {
      final decision = MigrationMarkerStore.decideStartupAction(
        migrationMarked: false,
        hasPersistedTracks: false,
        hasRecoveryIssue: false,
      );

      expect(decision.action, TrackStartupAction.importTracks);
      expect(decision.markMigrationComplete, isTrue);
    });

    test('decides later corrupt optimized rows should show recovery', () {
      final decision = MigrationMarkerStore.decideStartupAction(
        migrationMarked: true,
        hasPersistedTracks: true,
        hasRecoveryIssue: true,
      );

      expect(decision.action, TrackStartupAction.showRecovery);
      expect(decision.markMigrationComplete, isFalse);
    });
  });

  group('MapNotifier startup migration', () {
    test(
      'loadTracks branch backfills peaks bagged and marks completion',
      () async {
        final gpxRepository = _FakeGpxTrackRepository([
          _trackWithGeometry(
            id: 7,
            trackDate: DateTime.utc(2024, 1, 15),
            peakIds: [11, 22],
          ),
        ]);
        final peaksRepository = _RecordingPeaksBaggedRepository();
        final markerStore = _FakeMigrationMarkerStore(
          migrationMarked: true,
          peaksBaggedBackfillMarked: false,
        );

        final container = ProviderContainer(
          overrides: [
            mapProvider.overrideWith(
              () => MapNotifier(
                peakRepository: PeakRepository.test(InMemoryPeakStorage()),
                overpassService: OverpassService(),
                tasmapRepository: _NoopTasmapRepository(),
                gpxTrackRepository: gpxRepository,
                peaksBaggedRepository: peaksRepository,
                migrationMarkerStore: markerStore,
                loadPositionOnBuild: false,
                loadPeaksOnBuild: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(mapProvider.notifier);
        await _drainAsync();

        expect(container.read(mapProvider).showTracks, isTrue);
        expect(container.read(mapProvider).hasTrackRecoveryIssue, isFalse);
        expect(peaksRepository.rebuildTrackCounts, [1]);
        expect(await markerStore.isPeaksBaggedBackfillMarked(), isTrue);
        expect(notifier.consumeStartupBackfillWarningMessage(), isNull);
        expect(container.read(mapProvider).trackImportError, isNull);
      },
    );

    test('showRecovery branch still backfills peaks bagged', () async {
      final gpxRepository = _FakeGpxTrackRepository([
        _trackWithGeometry(id: 9, trackDate: null, peakIds: [33]),
      ]);
      final peaksRepository = _RecordingPeaksBaggedRepository();
      final markerStore = _FakeMigrationMarkerStore(
        migrationMarked: true,
        peaksBaggedBackfillMarked: false,
      );

      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(
            () => MapNotifier(
              peakRepository: PeakRepository.test(InMemoryPeakStorage()),
              overpassService: OverpassService(),
              tasmapRepository: _NoopTasmapRepository(),
              gpxTrackRepository: gpxRepository,
              peaksBaggedRepository: peaksRepository,
              migrationMarkerStore: markerStore,
              loadPositionOnBuild: false,
              loadPeaksOnBuild: false,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(mapProvider.notifier);
      await _drainAsync();

      expect(container.read(mapProvider).hasTrackRecoveryIssue, isTrue);
      expect(container.read(mapProvider).showTracks, isFalse);
      expect(peaksRepository.rebuildTrackCounts, [1]);
      expect(await markerStore.isPeaksBaggedBackfillMarked(), isTrue);
    });

    test(
      'startup backfill failure emits one-shot warning and mirrored error',
      () async {
        final gpxRepository = _FakeGpxTrackRepository([
          _trackWithGeometry(
            id: 7,
            trackDate: DateTime.utc(2024, 1, 15),
            peakIds: [11],
          ),
        ]);
        final peaksRepository = _RecordingPeaksBaggedRepository(
          throwOnRebuild: true,
        );
        final markerStore = _FakeMigrationMarkerStore(
          migrationMarked: true,
          peaksBaggedBackfillMarked: false,
        );

        final container = ProviderContainer(
          overrides: [
            mapProvider.overrideWith(
              () => MapNotifier(
                peakRepository: PeakRepository.test(InMemoryPeakStorage()),
                overpassService: OverpassService(),
                tasmapRepository: _NoopTasmapRepository(),
                gpxTrackRepository: gpxRepository,
                peaksBaggedRepository: peaksRepository,
                migrationMarkerStore: markerStore,
                loadPositionOnBuild: false,
                loadPeaksOnBuild: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(mapProvider.notifier);
        await _drainAsync();

        expect(
          container.read(mapProvider).trackImportError,
          contains('Failed to rebuild bagged peak history from stored tracks'),
        );
        expect(await markerStore.isPeaksBaggedBackfillMarked(), isFalse);
        expect(
          notifier.consumeStartupBackfillWarningMessage(),
          'Bagged history is stale. Open Settings to rebuild it.',
        );
        expect(notifier.consumeStartupBackfillWarningMessage(), isNull);
      },
    );

    test(
      'successful recalc sync marks completion and clears startup warning',
      () async {
        final gpxRepository = _FakeGpxTrackRepository([
          GpxTrack(
            gpxTrackId: 7,
            contentHash: 'hash-7',
            trackName: 'Track 7',
            trackDate: DateTime.utc(2024, 1, 15),
            gpxFile: _validRecalcGpx,
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [const LatLng(-42.0, 146.0), const LatLng(-42.1, 146.1)],
            ]),
          ),
        ]);
        final peaksRepository = _RecordingPeaksBaggedRepository(
          throwOnRebuild: true,
        );
        final markerStore = _FakeMigrationMarkerStore(
          migrationMarked: true,
          peaksBaggedBackfillMarked: false,
        );

        final container = ProviderContainer(
          overrides: [
            mapProvider.overrideWith(
              () => MapNotifier(
                peakRepository: PeakRepository.test(InMemoryPeakStorage()),
                overpassService: OverpassService(),
                tasmapRepository: _NoopTasmapRepository(),
                gpxTrackRepository: gpxRepository,
                peaksBaggedRepository: peaksRepository,
                migrationMarkerStore: markerStore,
                loadPositionOnBuild: false,
                loadPeaksOnBuild: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(mapProvider.notifier);
        await _drainAsync();
        expect(notifier.consumeStartupBackfillWarningMessage(), isNotNull);

        peaksRepository.throwOnRebuild = false;
        final result = await notifier.recalculateTrackStatistics();

        expect(result, isNotNull);
        expect(await markerStore.isPeaksBaggedBackfillMarked(), isTrue);
        expect(peaksRepository.syncTrackCounts, [1]);
        expect(notifier.consumeStartupBackfillWarningMessage(), isNull);
        expect(container.read(mapProvider).trackImportError, isNull);
      },
    );

    test(
      'recalc sync failure reloads tracks and reports stale bagged history',
      () async {
        final gpxRepository = _FakeGpxTrackRepository([
          GpxTrack(
            gpxTrackId: 7,
            contentHash: 'hash-7',
            trackName: 'Track 7',
            trackDate: DateTime.utc(2024, 1, 15),
            gpxFile: _validRecalcGpx,
            displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
              [const LatLng(-42.0, 146.0), const LatLng(-42.1, 146.1)],
            ]),
          ),
        ]);
        final peaksRepository = _RecordingPeaksBaggedRepository(
          throwOnSync: true,
        );
        final markerStore = _FakeMigrationMarkerStore(
          migrationMarked: true,
          peaksBaggedBackfillMarked: false,
        );

        final container = ProviderContainer(
          overrides: [
            mapProvider.overrideWith(
              () => MapNotifier(
                peakRepository: PeakRepository.test(InMemoryPeakStorage()),
                overpassService: OverpassService(),
                tasmapRepository: _NoopTasmapRepository(),
                gpxTrackRepository: gpxRepository,
                peaksBaggedRepository: peaksRepository,
                migrationMarkerStore: markerStore,
                loadPositionOnBuild: false,
                loadPeaksOnBuild: false,
                loadTracksOnBuild: false,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        final notifier = container.read(mapProvider.notifier);
        final result = await notifier.recalculateTrackStatistics();

        expect(result, isNull);
        expect(container.read(mapProvider).tracks, hasLength(1));
        expect(
          container.read(mapProvider).trackImportError,
          contains('bagged history is stale'),
        );
        expect(await markerStore.isPeaksBaggedBackfillMarked(), isFalse);
      },
    );
  });

  group('MapNotifier hover state', () {
    test('stores and clears hoveredTrackId without changing selection', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-42.0, 146.0),
        showInfoPopup: true,
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mapProvider.notifier);

      notifier.setHoveredTrackId(7);
      expect(container.read(mapProvider).hoveredTrackId, 7);
      expect(
        container.read(mapProvider).selectedLocation,
        const LatLng(-42.0, 146.0),
      );
      expect(container.read(mapProvider).showInfoPopup, isTrue);

      notifier.clearHoveredTrack();
      expect(container.read(mapProvider).hoveredTrackId, isNull);
      expect(
        container.read(mapProvider).selectedLocation,
        const LatLng(-42.0, 146.0),
      );
      expect(container.read(mapProvider).showInfoPopup, isTrue);
    });

    test('stores, replaces, and clears selectedTrackId', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mapProvider.notifier);

      notifier.selectTrack(3);
      expect(container.read(mapProvider).selectedTrackId, 3);

      notifier.selectTrack(7);
      expect(container.read(mapProvider).selectedTrackId, 7);

      notifier.clearSelectedTrack();
      expect(container.read(mapProvider).selectedTrackId, isNull);
    });

    test('map movement preserves selectedTrackId and hide clears it', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        selectedTrackId: 3,
        tracks: [GpxTrack(contentHash: 'hash', trackName: 'Track 1')],
        showTracks: true,
      );
      final container = ProviderContainer(
        overrides: [
          mapProvider.overrideWith(() => TestMapNotifier(initialState)),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(mapProvider.notifier);

      notifier.updatePosition(const LatLng(-42.0, 146.0), 14);
      expect(container.read(mapProvider).selectedTrackId, 3);

      notifier.toggleTracks();
      expect(container.read(mapProvider).showTracks, isFalse);
      expect(container.read(mapProvider).selectedTrackId, isNull);
    });
  });

  group('MapState copyWith', () {
    test('preserves error and gotoMgrs on unrelated updates', () {
      final initialState = MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        error: 'boom',
        gotoMgrs: '55G\n00000 00000',
      );

      final updated = initialState.copyWith(center: const LatLng(-42.0, 146.0));

      expect(updated.error, 'boom');
      expect(updated.gotoMgrs, '55G\n00000 00000');
    });
  });

  group('GpxTrack', () {
    test('newly imported rows populate identity fields', () {
      final track = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Mt Anne',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
      );

      expect(track.contentHash, 'abc123');
      expect(track.trackName, 'Mt Anne');
      expect(track.trackDate, DateTime(2024, 1, 15));
      expect(track.trackColour, 0xFFa726bc);
      expect(track.distance2d, 0);
      expect(track.distance3d, 0);
      expect(track.distanceToPeak, 0);
      expect(track.distanceFromPeak, 0);
      expect(track.lowestElevation, 0);
      expect(track.highestElevation, 0);
      expect(track.gpxFile, '<gpx></gpx>');
      expect(track.displayTrackPointsByZoom, '{}');
      expect(track.hasMetadataTrackDate, isFalse);
    });

    test('getSegmentsForZoom decodes segmented geometry', () {
      final track = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Seg Track',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          [const LatLng(-42.1, 146.1), const LatLng(-42.2, 146.2)],
          [const LatLng(-42.3, 146.3)],
        ]),
      );

      final segments = track.getSegmentsForZoom(15);

      expect(segments, hasLength(2));
      expect(segments.first, hasLength(2));
      expect(segments.first.first.latitude, -42.1);
      expect(segments.first.first.longitude, 146.1);
      expect(segments.last.single.latitude, -42.3);
    });

    test('fromMap and toMap round-trip new fields', () {
      final map = {
        'gpxTrackId': 1,
        'contentHash': 'hash',
        'trackName': 'Frenchmans Cap',
        'trackDate': '2024-01-15T00:00:00.000',
        'gpxFile': '<gpx></gpx>',
        'displayTrackPointsByZoom': '{"15":[[[-42.0,146.0]]]}',
        'startDateTime': '2024-01-15T08:00:00.000',
        'endDateTime': '2024-01-15T17:00:00.000',
        'distance2d': 10.5,
        'distance3d': 0,
        'distanceToPeak': 3.5,
        'distanceFromPeak': 4.5,
        'lowestElevation': 100.0,
        'highestElevation': 900.0,
        'ascent': 900.0,
        'totalTimeMillis': 3600000,
        'movingTime': 2700000,
        'restingTime': 900000,
        'pausedTime': 600000,
        'trackColour': 0xFFa726bc,
      };

      final track = GpxTrack.fromMap(map);
      final encoded = track.toMap();

      expect(track.gpxTrackId, 1);
      expect(track.contentHash, 'hash');
      expect(track.trackName, 'Frenchmans Cap');
      expect(track.startDateTime, isNotNull);
      expect(track.endDateTime, isNotNull);
      expect(track.distance2d, 10.5);
      expect(track.distance3d, 0);
      expect(track.distanceToPeak, 3.5);
      expect(track.distanceFromPeak, 4.5);
      expect(track.lowestElevation, 100);
      expect(track.highestElevation, 900);
      expect(track.movingTime, 2700000);
      expect(track.restingTime, 900000);
      expect(track.pausedTime, 600000);
      expect(track.gpxFile, '<gpx></gpx>');
      expect(encoded['contentHash'], 'hash');
      expect(encoded['trackName'], 'Frenchmans Cap');
      expect(encoded['trackDate'], isNotNull);
      expect(encoded['endDateTime'], isNotNull);
      expect(encoded['distance2d'], 10.5);
      expect(encoded['distance3d'], 0);
      expect(encoded['distanceToPeak'], 3.5);
      expect(encoded['distanceFromPeak'], 4.5);
      expect(encoded['lowestElevation'], 100);
      expect(encoded['highestElevation'], 900);
      expect(encoded['movingTime'], 2700000);
      expect(encoded['restingTime'], 900000);
      expect(encoded['pausedTime'], 600000);
      expect(encoded['gpxFile'], '<gpx></gpx>');
    });

    test('round-trips elevation profile fields', () {
      final map = {
        'gpxTrackId': 7,
        'contentHash': 'hash-7',
        'trackName': 'Elevation Track',
        'gpxFile': '<gpx></gpx>',
        'descent': 55.5,
        'startElevation': 120.0,
        'endElevation': 180.0,
        'elevationProfile':
            '[{"segmentIndex":0,"pointIndex":0,"distanceMeters":0.0,"elevationMeters":120.0,"timeLocal":null}]',
      };

      final track = GpxTrack.fromMap(map);
      final encoded = track.toMap();

      expect(track.descent, 55.5);
      expect(track.startElevation, 120);
      expect(track.endElevation, 180);
      expect(track.elevationProfile, contains('segmentIndex'));
      expect(encoded['descent'], 55.5);
      expect(encoded['startElevation'], 120);
      expect(encoded['endElevation'], 180);
      expect(encoded['elevationProfile'], contains('pointIndex'));
    });

    test('round-trips peak correlation processed flag', () {
      final map = {
        'gpxTrackId': 9,
        'contentHash': 'hash-9',
        'trackName': 'Correlation Track',
        'gpxFile': '<gpx></gpx>',
        'peakCorrelationProcessed': true,
      };

      final track = GpxTrack.fromMap(map);
      final encoded = track.toMap();

      expect(track.peakCorrelationProcessed, isTrue);
      expect(encoded['peakCorrelationProcessed'], isTrue);
    });

    test('hasValidOptimizedDisplayData requires gpx and full zoom range', () {
      final validTrack = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Valid Track',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
          [const LatLng(-42.1, 146.1), const LatLng(-42.2, 146.2)],
        ]),
      );
      final invalidTrack = GpxTrack(
        contentHash: 'abc123',
        trackName: 'Invalid Track',
        trackDate: DateTime(2024, 1, 15),
        gpxFile: '<gpx></gpx>',
        displayTrackPointsByZoom: '{"15":[[[-42.1,146.1],[-42.2,146.2]]]}',
      );

      expect(validTrack.hasValidOptimizedDisplayData(), isTrue);
      expect(invalidTrack.hasValidOptimizedDisplayData(), isFalse);
    });
  });

  group(
    'GpxTrackRepository',
    () {
      late Directory tempDir;
      late Store store;
      late GpxTrackRepository repository;

      setUp(() async {
        tempDir = await Directory.systemTemp.createTemp('gpx-track-test');
        store = await openStore(directory: tempDir.path);
        repository = GpxTrackRepository(store);
      });

      tearDown(() async {
        store.close();
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      test('findByContentHash finds stored track', () {
        final track = GpxTrack(
          contentHash: 'hash-1',
          trackName: 'Track 1',
          trackDate: DateTime(2024, 1, 15),
        );
        repository.putTrack(track);

        final found = repository.findByContentHash('hash-1');

        expect(found, isNotNull);
        expect(found!.trackName, 'Track 1');
      });

      test('findByTrackNameAndTrackDate uses metadata-date rows only', () {
        repository.putTrack(
          GpxTrack(
            contentHash: 'no-meta',
            trackName: 'Track A',
            trackDate: DateTime(2024, 1, 15),
          ),
        );
        repository.putTrack(
          GpxTrack(
            contentHash: 'meta',
            trackName: 'Track A',
            trackDate: DateTime(2024, 1, 15),
            startDateTime: DateTime(2024, 1, 15, 8),
          ),
        );

        final found = repository.findByTrackNameAndTrackDate(
          'Track A',
          DateTime(2024, 1, 15),
        );

        expect(found, isNotNull);
        expect(found!.contentHash, 'meta');
      });
    },
    skip: 'ObjectBox native library unavailable in flutter test environment',
  );

  group('GpxTrackStatisticsCalculator', () {
    final calculator = GpxTrackStatisticsCalculator();

    test('calculates distance and peak split for a track', () {
      final gpx = _statsGpx('Peak Track', [
        [
          _StatsPoint(-42.0, 146.0, 100),
          _StatsPoint(-42.0, 146.1, 250),
          _StatsPoint(-42.0, 146.2, 200),
        ],
      ]);

      final stats = calculator.calculate(gpx);
      final firstLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.0),
        const LatLng(-42.0, 146.1),
      );
      final secondLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.1),
        const LatLng(-42.0, 146.2),
      );
      final expected3d =
          (math.sqrt(firstLeg * firstLeg + 150 * 150) +
                  math.sqrt(secondLeg * secondLeg + 50 * 50))
              .roundToDouble();

      expect(stats.distance2d, closeTo(firstLeg + secondLeg, 0.01));
      expect(stats.distance3d, expected3d);
      expect(stats.distanceToPeak, closeTo(firstLeg, 0.01));
      expect(stats.distanceFromPeak, closeTo(secondLeg, 0.01));
      expect(stats.lowestElevation, 100);
      expect(stats.highestElevation, 250);
    });

    test('calculates elevation ascent descent and endpoints', () {
      final gpx = _statsGpx('Elevation Track', [
        [
          _StatsPoint(-42.0, 146.0, 100),
          _StatsPoint(-42.0, 146.1, 250),
          _StatsPoint(-42.0, 146.2, 200),
        ],
      ]);

      final stats = calculator.calculate(gpx);

      expect(stats.ascent, 100);
      expect(stats.descent, 0);
      expect(stats.startElevation, 100);
      expect(stats.endElevation, 200);
    });

    test('serializes elevation profile with preserved gaps', () {
      final gpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Profile Track</name>
    <trkseg>
      <trkpt lat="-42.0" lon="146.0">
        <ele>100</ele>
        <time>2024-01-15T08:00:00</time>
      </trkpt>
      <trkpt lat="-42.0" lon="146.1">
        <time>2024-01-15T08:10:00</time>
      </trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="-42.0" lon="146.2">
        <ele>120</ele>
        <time>2024-01-15T08:20:00</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

      final stats = calculator.calculate(gpx);
      final profile = jsonDecode(stats.elevationProfile) as List<dynamic>;

      expect(profile, hasLength(3));
      expect(profile.first['segmentIndex'], 0);
      expect(profile.first['pointIndex'], 0);
      expect(profile.first['distanceMeters'], 0);
      expect(profile.first['elevationMeters'], 100);
      expect(profile.first['timeLocal'], '2024-01-15T08:00:00.000');
      expect(profile[1]['segmentIndex'], 0);
      expect(profile[1]['pointIndex'], 1);
      expect(profile[1]['elevationMeters'], isNull);
      expect(profile[2]['segmentIndex'], 1);
      expect(profile[2]['pointIndex'], 0);
      expect(profile[2]['elevationMeters'], 120);
      expect(profile[2]['timeLocal'], '2024-01-15T08:20:00.000');
      expect(stats.distanceToPeak, 0);
      expect(stats.startElevation, 100);
      expect(stats.endElevation, 120);
    });

    test('uses first highest point when peak elevation ties', () {
      final gpx = _statsGpx('Tie Track', [
        [
          _StatsPoint(-42.0, 146.0, 100),
          _StatsPoint(-42.0, 146.1, 250),
          _StatsPoint(-42.0, 146.2, 250),
          _StatsPoint(-42.0, 146.3, 90),
        ],
      ]);

      final stats = calculator.calculate(gpx);
      final firstLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.0),
        const LatLng(-42.0, 146.1),
      );
      final middleLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.1),
        const LatLng(-42.0, 146.2),
      );
      final finalLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.2),
        const LatLng(-42.0, 146.3),
      );
      final expected3d =
          (math.sqrt(firstLeg * firstLeg + 150 * 150) +
                  math.sqrt(middleLeg * middleLeg) +
                  math.sqrt(finalLeg * finalLeg + 160 * 160))
              .roundToDouble();

      expect(stats.distance2d, closeTo(firstLeg + middleLeg + finalLeg, 0.01));
      expect(stats.distance3d, expected3d);
      expect(stats.distanceToPeak, closeTo(firstLeg, 0.01));
      expect(stats.distanceFromPeak, closeTo(middleLeg + finalLeg, 0.01));
      expect(stats.lowestElevation, 90);
      expect(stats.highestElevation, 250);
    });

    test('still calculates extrema when elevation is partially missing', () {
      final gpx = _statsGpx('Missing Elevation', [
        [
          _StatsPoint(-42.0, 146.0, 100),
          _StatsPoint(-42.0, 146.1, null),
          _StatsPoint(-42.0, 146.2, 200),
        ],
      ]);

      final stats = calculator.calculate(gpx);

      expect(stats.distance2d, greaterThan(0));
      expect(stats.distance3d, stats.distance2d.roundToDouble());
      expect(stats.distanceToPeak, 0);
      expect(stats.distanceFromPeak, 0);
      expect(stats.lowestElevation, 100);
      expect(stats.highestElevation, 200);
    });

    test('matches 2D distance when elevations are unchanged', () {
      final gpx = _statsGpx('Flat Track', [
        [_StatsPoint(-42.0, 146.0, 50), _StatsPoint(-42.0, 146.1, 50)],
      ]);

      final stats = calculator.calculate(gpx);
      final expected2d = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.0),
        const LatLng(-42.0, 146.1),
      );

      expect(stats.distance2d, closeTo(expected2d, 0.01));
      expect(stats.distance3d, expected2d.roundToDouble());
    });

    test('clamps negative elevations to zero', () {
      final gpx = _statsGpx('Below Sea Level', [
        [_StatsPoint(-42.0, 146.0, -50), _StatsPoint(-42.0, 146.1, 20)],
      ]);

      final stats = calculator.calculate(gpx);

      expect(stats.ascent, 20);
      expect(stats.descent, 0);
      expect(stats.startElevation, 0);
      expect(stats.endElevation, 20);
      expect(stats.lowestElevation, 0);
      expect(stats.highestElevation, 20);
    });

    test('rounds elevation summary metrics to the nearest meter', () {
      final gpx = _statsGpx('Rounded Elevation', [
        [
          _StatsPoint(-42.0, 146.0, 100.2),
          _StatsPoint(-42.0, 146.1, 102.2),
          _StatsPoint(-42.0, 146.2, 100.2),
        ],
      ]);

      final stats = calculator.calculate(gpx);

      expect(stats.ascent, 1);
      expect(stats.descent, 1);
      expect(stats.startElevation, 100);
      expect(stats.endElevation, 100);
    });

    test(
      'calculates time stats from filtered XML with rest and pause gaps',
      () {
        final gpx = _statsGpx('Time Track', [
          [
            _StatsPoint(-42.0, 146.0, 100, DateTime.utc(2024, 1, 15, 8, 0, 0)),
            _StatsPoint(
              -42.0,
              146.002,
              120,
              DateTime.utc(2024, 1, 15, 8, 1, 0),
            ),
          ],
          [
            _StatsPoint(
              -42.0,
              146.002,
              120,
              DateTime.utc(2024, 1, 15, 8, 3, 0),
            ),
            _StatsPoint(
              -42.0,
              146.002,
              120,
              DateTime.utc(2024, 1, 15, 8, 4, 0),
            ),
          ],
        ]);

        final stats = calculator.calculate(gpx);

        expect(stats.startDateTime, isNotNull);
        expect(stats.startDateTime!.isUtc, isTrue);
        expect(stats.endDateTime, isNotNull);
        expect(stats.endDateTime!.isUtc, isTrue);
        expect(stats.totalTimeMillis, 120000);
        expect(stats.movingTime, 60000);
        expect(stats.restingTime, 60000);
        expect(stats.pausedTime, 120000);
      },
    );

    test(
      'skips missing timestamps and keeps remaining parseable intervals',
      () {
        final gpx = _statsGpx('Gap Track', [
          [
            _StatsPoint(-42.0, 146.0, 100, DateTime.utc(2024, 1, 15, 8, 0, 0)),
            _StatsPoint(-42.0, 146.001, 110, null),
            _StatsPoint(
              -42.0,
              146.002,
              120,
              DateTime.utc(2024, 1, 15, 8, 2, 0),
            ),
          ],
        ]);

        final stats = calculator.calculate(gpx);

        expect(stats.totalTimeMillis, 120000);
        expect(stats.movingTime, 120000);
        expect(stats.restingTime, 0);
        expect(stats.pausedTime, 0);
      },
    );

    test('treats elevations below zero as zero in distance math', () {
      final gpx = _statsGpx('Invalid Elevation', [
        [
          _StatsPoint(-42.0, 146.0, -120),
          _StatsPoint(-42.0, 146.1, -50),
          _StatsPoint(-42.0, 146.2, 10),
        ],
      ]);

      final stats = calculator.calculate(gpx);
      final firstLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.0),
        const LatLng(-42.0, 146.1),
      );
      final secondLeg = _distance.as(
        LengthUnit.Meter,
        const LatLng(-42.0, 146.1),
        const LatLng(-42.0, 146.2),
      );
      final expected3d = (firstLeg + math.sqrt(secondLeg * secondLeg + 10 * 10))
          .roundToDouble();

      expect(stats.distance3d, expected3d);
      expect(stats.lowestElevation, 0);
      expect(stats.highestElevation, 10);
    });

    test('zeros elevation stats for a single-point track', () {
      final gpx = _statsGpx('Single Point', [
        [_StatsPoint(-42.0, 146.0, 100)],
      ]);

      final stats = calculator.calculate(gpx);

      expect(stats.distance2d, 0);
      expect(stats.distance3d, 0);
      expect(stats.distanceToPeak, 0);
      expect(stats.distanceFromPeak, 0);
      expect(stats.lowestElevation, 0);
      expect(stats.highestElevation, 0);
    });

    test('throws FormatException for malformed GPX XML', () {
      expect(
        () => calculator.calculate('<gpx><trk></gpx>'),
        throwsFormatException,
      );
    });
  });

  group('GpxImporter', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('gpx-importer-test');
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('parseGpxFile uses metadata name/date when available', () async {
      final file = File('${tempDir.path}/track.gpx');
      final gpx = _tasmanianGpx('Mt Anne');
      await file.writeAsString(gpx);

      final importer = GpxImporter();
      final track = importer.parseGpxFile(file.path);

      expect(track, isNotNull);
      expect(track!.trackName, 'Mt Anne');
      expect(track.trackDate, DateTime(2024, 1, 15));
      expect(track.startDateTime, isNotNull);
      expect(track.endDateTime, isNotNull);
      expect(track.contentHash, isNotEmpty);
      expect(track.gpxFile, gpx);
      expect(track.displayTrackPointsByZoom, isNot('{}'));
      expect(track.getSegmentsForZoom(15), isNotEmpty);
    });

    test('parseGpxFile populates elevation analytics', () async {
      final file = File('${tempDir.path}/elevation.gpx');
      await file.writeAsString('''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Elevation Import</name>
    <trkseg>
      <trkpt lat="-42.0" lon="146.0">
        <ele>100</ele>
      </trkpt>
      <trkpt lat="-42.0" lon="146.1">
        <ele>250</ele>
      </trkpt>
      <trkpt lat="-42.0" lon="146.2">
        <ele>200</ele>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''');

      final importer = GpxImporter();
      final track = importer.parseGpxFile(file.path);

      expect(track, isNotNull);
      expect(track!.ascent, 100);
      expect(track.descent, 0);
      expect(track.startElevation, 100);
      expect(track.endElevation, 200);
      expect(track.elevationProfile, contains('segmentIndex'));
    });

    test('isTasmanian includes eastern Tasmania longitudes', () {
      final importer = GpxImporter();

      expect(importer.isTasmanian(-42.14166, 148.299456), isTrue);
      expect(importer.isTasmanian(-40.908926, 148.207244), isTrue);
    });

    test('parseGpxFile supports route GPX files', () async {
      final file = File('${tempDir.path}/route.gpx');
      await file.writeAsString(_tasmanianRouteGpx('Mt Dial & Gnomon'));

      final importer = GpxImporter();
      final track = importer.parseGpxFile(file.path);

      expect(track, isNotNull);
      expect(track!.trackName, 'Mt Dial & Gnomon');
      expect(track.getSegments(), isNotEmpty);
      expect(track.getSegments().single.length, greaterThan(1));
    });

    test(
      'route GPX files are moved to Routes and excluded from counts',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tracksDir.path}/Tasmania')..createSync();
        final routesDir = Directory('${tempDir.path}/Routes')..createSync();
        final source = File('${tracksDir.path}/route.gpx');
        await source.writeAsString(_tasmanianRouteGpx('Mt Dial & Gnomon'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
          routesFolder: routesDir.path,
        );

        final result = await importer.importTracks(
          includeTasmaniaFolder: false,
        );

        expect(result.importedCount, 0);
        expect(result.replacedCount, 0);
        expect(result.unchangedCount, 0);
        expect(result.nonTasmanianCount, 0);
        expect(result.errorSkippedCount, 0);
        expect(result.tracks, isEmpty);
        expect(source.existsSync(), isFalse);
        expect(
          File('${routesDir.path}/route_(29-06-2025).gpx').existsSync(),
          isTrue,
        );
      },
    );

    test('no-point GPX logs no track points found', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tracksDir.path}/Tasmania')..createSync();
      await File(
        '${tracksDir.path}/empty-track.gpx',
      ).writeAsString(_noPointGpx('Lunch Activity'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );

      final result = await importer.importTracks(includeTasmaniaFolder: false);
      final importLog = File(importer.getImportLogPath()).readAsStringSync();

      expect(result.errorSkippedCount, 1);
      expect(importLog, contains('No track points found'));
    });

    test(
      'importTracks reports non-Tasmanian files only in nonTasmanianCount',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tempDir.path}/Tracks/Tasmania')
          ..createSync();
        await File(
          '${tracksDir.path}/tas.gpx',
        ).writeAsString(_tasmanianGpx('Tas Track'));
        await File(
          '${tracksDir.path}/mainland.gpx',
        ).writeAsString(_mainlandGpx('Mainland Track'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );

        final result = await importer.importTracks(
          includeTasmaniaFolder: false,
        );

        expect(result.importedCount, 1);
        expect(result.replacedCount, 0);
        expect(result.unchangedCount, 0);
        expect(result.errorSkippedCount, 0);
        expect(result.nonTasmanianCount, 1);
        expect(result.tracks, hasLength(1));
      },
    );

    test('metadata-date track replaces existing logical match', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tempDir.path}/Tracks/Tasmania')..createSync();
      await File(
        '${tracksDir.path}/tas.gpx',
      ).writeAsString(_tasmanianGpx('Tas Track'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );
      final existing = GpxTrack(
        gpxTrackId: 7,
        contentHash: 'old-hash',
        trackName: 'Tas Track',
        trackDate: DateTime(2024, 1, 15),
        startDateTime: DateTime(2024, 1, 15, 8),
      );

      final result = await importer.importTracks(
        includeTasmaniaFolder: false,
        existingTracks: [existing],
      );

      expect(result.importedCount, 0);
      expect(result.replacedCount, 1);
      expect(result.tracks.single.gpxTrackId, 7);
    });

    test('tasmanian imported file is moved into Tasmania folder', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tracksDir.path}/Tracks/Tasmania')
        ..createSync(recursive: true);
      final source = File('${tracksDir.path}/lake-skinner.gpx');
      await source.writeAsString(_tasmanianGpx('Lake Skinner'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );

      final result = await importer.importTracks(includeTasmaniaFolder: false);

      expect(result.importedCount, 1);
      expect(source.existsSync(), isFalse);
      expect(
        File('${tasDir.path}/lake-skinner_(15-01-2024).gpx').existsSync(),
        isTrue,
      );
    });

    test('reset import reassigns track ids from 1', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tracksDir.path}/Tracks/Tasmania')
        ..createSync(recursive: true);
      await File(
        '${tracksDir.path}/a-first.gpx',
      ).writeAsString(_tasmanianGpx('Tas Track One'));
      await File(
        '${tracksDir.path}/z-second.gpx',
      ).writeAsString(_tasmanianGpxShifted('Tas Track Two'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );

      final result = await importer.importTracks(
        includeTasmaniaFolder: false,
        resetIds: true,
      );

      expect(result.importedCount, 2);
      expect(result.tracks.map((track) => track.gpxTrackId), [1, 2]);
    });

    test(
      'moved filename is canonicalized using filename date override',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tracksDir.path}/Tracks/Tasmania')
          ..createSync(recursive: true);
        final source = File(
          '${tracksDir.path}/Mt. William & Dove, Ridge (2024-02-03 13-30).gpx',
        );
        await source.writeAsString(_tasmanianGpx('Mt William'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );

        await importer.importTracks(includeTasmaniaFolder: false);

        expect(
          File(
            '${tasDir.path}/mt-william-dove-ridge_(03-02-2024).gpx',
          ).existsSync(),
          isTrue,
        );
      },
    );

    test('already canonical filename is preserved', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tracksDir.path}/Tracks/Tasmania')
        ..createSync(recursive: true);
      final source = File(
        '${tracksDir.path}/mt-william-dove-ridge_(03-02-2024).gpx',
      );
      await source.writeAsString(_tasmanianGpx('Mt William'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );

      await importer.importTracks(includeTasmaniaFolder: false);

      expect(
        File(
          '${tasDir.path}/mt-william-dove-ridge_(03-02-2024).gpx',
        ).existsSync(),
        isTrue,
      );
    });

    test('no-date changed track does not replace logical match', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tempDir.path}/Tracks/Tasmania')..createSync();
      final file = File('${tracksDir.path}/tas-no-date.gpx');
      await file.writeAsString(_tasmanianGpxNoDate('Tas Track'));
      await file.setLastModified(DateTime(2024, 2, 1, 12));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );
      final existing = GpxTrack(
        gpxTrackId: 8,
        contentHash: 'old-hash',
        trackName: 'Tas Track',
        trackDate: DateTime(2024, 2, 1),
      );

      final result = await importer.importTracks(
        includeTasmaniaFolder: false,
        existingTracks: [existing],
      );

      expect(result.importedCount, 1);
      expect(result.replacedCount, 0);
      expect(result.tracks.single.gpxTrackId, isZero);
      expect(result.tracks.single.hasMetadataTrackDate, isFalse);
    });

    test(
      'same-operation logical-match conflict keeps first candidate and skips later one',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tempDir.path}/Tracks/Tasmania')
          ..createSync();
        await File(
          '${tracksDir.path}/a-first.gpx',
        ).writeAsString(_tasmanianGpx('Tas Track'));
        await File(
          '${tracksDir.path}/z-second.gpx',
        ).writeAsString(_tasmanianGpxShifted('Tas Track'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );
        final existing = GpxTrack(
          gpxTrackId: 12,
          contentHash: 'old-hash',
          trackName: 'Tas Track',
          trackDate: DateTime(2024, 1, 15),
          startDateTime: DateTime(2024, 1, 15, 8),
        );

        final result = await importer.importTracks(
          includeTasmaniaFolder: false,
          existingTracks: [existing],
        );

        expect(result.replacedCount, 1);
        expect(result.errorSkippedCount, 1);
        expect(result.tracks, hasLength(1));
        expect(
          result.tracks.single.getSegmentsForZoom(18).first.first.latitude,
          -42.1234,
        );
        expect(result.warning, contains('import.log'));
      },
    );

    test('startup import keeps manual-review warnings silent', () async {
      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasDir = Directory('${tempDir.path}/Tracks/Tasmania')..createSync();
      await File(
        '${tracksDir.path}/a-first.gpx',
      ).writeAsString(_tasmanianGpx('Tas Track'));
      await File(
        '${tracksDir.path}/z-second.gpx',
      ).writeAsString(_tasmanianGpxShifted('Tas Track'));

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasDir.path,
      );
      final existing = GpxTrack(
        gpxTrackId: 12,
        contentHash: 'old-hash',
        trackName: 'Tas Track',
        trackDate: DateTime(2024, 1, 15),
        startDateTime: DateTime(2024, 1, 15, 8),
      );

      final result = await importer.importTracks(
        includeTasmaniaFolder: false,
        existingTracks: [existing],
        surfaceWarnings: false,
      );

      expect(result.errorSkippedCount, 1);
      expect(result.warning, isNull);
    });

    test(
      'moveReplacementFile restores files when database replacement fails',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tracksDir.path}/Tasmania')..createSync();
        final source = File('${tracksDir.path}/track.gpx');
        final destination = File('${tasDir.path}/track_(15-01-2024).gpx');
        await source.writeAsString(_tasmanianGpx('Tas Track'));
        await destination.writeAsString(_tasmanianGpx('Tas Track'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );
        final replacementTrack = importer.parseGpxFile(source.path)!;

        final moved = await importer.moveReplacementFile(
          sourcePath: source.path,
          replacementTrack: replacementTrack,
          applyDatabaseReplacement: () async {
            throw Exception('db failure');
          },
        );

        expect(moved, isFalse);
        expect(source.existsSync(), isTrue);
        expect(destination.existsSync(), isTrue);
      },
    );

    test(
      'moveReplacementFile blocks overwrite when destination is different logical match',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tracksDir.path}/Tasmania')..createSync();
        final source = File('${tracksDir.path}/track.gpx');
        final destination = File('${tasDir.path}/track_(15-01-2024).gpx');
        await source.writeAsString(_tasmanianGpx('Tas Track'));
        await destination.writeAsString(_tasmanianGpx('Other Track'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );
        final replacementTrack = importer.parseGpxFile(source.path)!;

        final moved = await importer.moveReplacementFile(
          sourcePath: source.path,
          replacementTrack: replacementTrack,
          applyDatabaseReplacement: () async {},
        );

        expect(moved, isFalse);
        expect(source.existsSync(), isTrue);
        expect(destination.existsSync(), isTrue);
      },
    );

    test(
      'moveReplacementFile preserves existing organized filename for logical match',
      () async {
        final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
        final tasDir = Directory('${tracksDir.path}/Tasmania')..createSync();
        final source = File('${tracksDir.path}/Mt. William Alternate.gpx');
        final destination = File('${tasDir.path}/mt-william_(15-01-2024).gpx');
        await source.writeAsString(_tasmanianGpx('Mt William'));
        await destination.writeAsString(_tasmanianGpx('Mt William'));

        final importer = GpxImporter(
          tracksFolder: tracksDir.path,
          tasmaniaFolder: tasDir.path,
        );
        final replacementTrack = importer.parseGpxFile(source.path)!;

        final moved = await importer.moveReplacementFile(
          sourcePath: source.path,
          replacementTrack: replacementTrack,
          applyDatabaseReplacement: () async {},
        );

        expect(moved, isTrue);
        expect(destination.existsSync(), isTrue);
        expect(source.existsSync(), isFalse);
        expect(
          File(
            '${tasDir.path}/mt-william-alternate_(15-01-2024).gpx',
          ).existsSync(),
          isFalse,
        );
      },
    );
  });
}

Future<void> _drainAsync() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

GpxTrack _trackWithGeometry({
  required int id,
  required DateTime? trackDate,
  required List<int> peakIds,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: trackDate,
    gpxFile: '<gpx></gpx>',
    displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
      [const LatLng(-42.0, 146.0), const LatLng(-42.1, 146.1)],
    ]),
  );
  track.peaks.addAll(
    peakIds.map(
      (peakId) => Peak(
        osmId: peakId,
        name: 'Peak $peakId',
        latitude: -42,
        longitude: 146,
      ),
    ),
  );
  return track;
}

class _FakeGpxTrackRepository implements GpxTrackRepository {
  _FakeGpxTrackRepository(List<GpxTrack> tracks)
    : _tracks = List<GpxTrack>.from(tracks);

  List<GpxTrack> _tracks;

  @override
  List<GpxTrack> getAllTracks() => List<GpxTrack>.from(_tracks);

  @override
  void deleteAll() {
    _tracks = const [];
  }

  @override
  int putTrack(GpxTrack track) {
    _tracks = [
      ..._tracks.where((entry) => entry.gpxTrackId != track.gpxTrackId),
      track,
    ];
    return track.gpxTrackId;
  }

  @override
  int replaceTrack({
    required GpxTrack existing,
    required GpxTrack replacement,
  }) {
    replacement.gpxTrackId = existing.gpxTrackId;
    _tracks = _tracks
        .map(
          (entry) =>
              entry.gpxTrackId == existing.gpxTrackId ? replacement : entry,
        )
        .toList(growable: false);
    return replacement.gpxTrackId;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingPeaksBaggedRepository implements PeaksBaggedRepository {
  _RecordingPeaksBaggedRepository({
    this.throwOnRebuild = false,
    this.throwOnSync = false,
  });

  bool throwOnRebuild;
  bool throwOnSync;
  final List<int> rebuildTrackCounts = [];
  final List<int> syncTrackCounts = [];

  @override
  Future<void> rebuildFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforePutManyForTest,
  }) async {
    if (throwOnRebuild) {
      throw StateError('boom');
    }
    rebuildTrackCounts.add(tracks.length);
  }

  @override
  Future<void> syncFromTracks(
    Iterable<GpxTrack> tracks, {
    void Function()? beforeWriteForTest,
  }) async {
    if (throwOnSync) {
      throw StateError('boom');
    }
    syncTrackCounts.add(tracks.length);
  }

  @override
  List<PeaksBagged> getAll() => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeMigrationMarkerStore implements MigrationMarkerStore {
  _FakeMigrationMarkerStore({
    required bool migrationMarked,
    required bool peaksBaggedBackfillMarked,
  }) : _migrationMarked = migrationMarked,
       _peaksBaggedBackfillMarked = peaksBaggedBackfillMarked;

  bool _migrationMarked;
  bool _peaksBaggedBackfillMarked;

  @override
  Future<bool> isMarked() async => _migrationMarked;

  @override
  Future<void> markComplete() async {
    _migrationMarked = true;
  }

  @override
  Future<bool> isPeaksBaggedBackfillMarked() async {
    return _peaksBaggedBackfillMarked;
  }

  @override
  Future<void> markPeaksBaggedBackfillComplete() async {
    _peaksBaggedBackfillMarked = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoopTasmapRepository implements TasmapRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _validRecalcGpx = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Track 7</name>
    <trkseg>
      <trkpt lat="-42.0" lon="146.0"><time>2024-01-15T08:00:00Z</time></trkpt>
      <trkpt lat="-42.1" lon="146.1"><time>2024-01-15T09:00:00Z</time></trkpt>
    </trkseg>
  </trk>
</gpx>
''';

String _tasmanianGpx(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>$name</name>
    <trkseg>
      <trkpt lat="-42.1234" lon="146.1234">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.2234" lon="146.2234">
        <time>2024-01-15T09:00:00Z</time>
      </trkpt>
    </trkseg>
    <trkseg>
      <trkpt lat="-42.3234" lon="146.3234">
        <time>2024-01-15T10:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

String _mainlandGpx(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>$name</name>
    <trkseg>
      <trkpt lat="-37.8136" lon="144.9631">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

String _tasmanianGpxNoDate(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>$name</name>
    <trkseg>
      <trkpt lat="-42.1234" lon="146.1234" />
      <trkpt lat="-42.2234" lon="146.2234" />
    </trkseg>
  </trk>
</gpx>
''';

String _tasmanianRouteGpx(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <rte>
    <name>$name</name>
    <rtept lat="-41.177239" lon="146.027882">
      <time>2025-06-28T23:05:54Z</time>
    </rtept>
    <rtept lat="-41.177389" lon="146.027849">
      <time>2025-06-28T23:06:54Z</time>
    </rtept>
  </rte>
</gpx>
''';

String _noPointGpx(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>$name</name>
  </trk>
</gpx>
''';

String _tasmanianGpxShifted(String name) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>$name</name>
    <trkseg>
      <trkpt lat="-42.5234" lon="146.5234">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.6234" lon="146.6234">
        <time>2024-01-15T09:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';

class _StatsPoint {
  const _StatsPoint(this.lat, this.lon, this.elevation, [this.timeUtc]);

  final double lat;
  final double lon;
  final double? elevation;
  final DateTime? timeUtc;
}

String _statsGpx(String name, List<List<_StatsPoint>> segments) {
  final buffer = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="test">')
    ..writeln('  <trk>')
    ..writeln('    <name>$name</name>');

  for (final segment in segments) {
    buffer.writeln('    <trkseg>');
    for (final point in segment) {
      buffer.writeln('      <trkpt lat="${point.lat}" lon="${point.lon}">');
      if (point.elevation != null) {
        buffer.writeln('        <ele>${point.elevation}</ele>');
      }
      if (point.timeUtc != null) {
        buffer.writeln(
          '        <time>${point.timeUtc!.toUtc().toIso8601String()}</time>',
        );
      }
      buffer.writeln('      </trkpt>');
    }
    buffer.writeln('    </trkseg>');
  }

  buffer
    ..writeln('  </trk>')
    ..writeln('</gpx>');
  return buffer.toString();
}
