import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/objectbox.g.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/services/track_hover_detector.dart';
import 'package:peak_bagger/services/track_migration_marker_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'harness/test_map_notifier.dart';

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

  group('TrackMigrationMarkerStore', () {
    test('marks migration as complete', () async {
      SharedPreferences.setMockInitialValues({});
      const store = TrackMigrationMarkerStore();

      expect(await store.isMarked(), isFalse);

      await store.markComplete();

      expect(await store.isMarked(), isTrue);
    });

    test('decides first startup with legacy rows should wipe then import', () {
      final decision = TrackMigrationMarkerStore.decideStartupAction(
        migrationMarked: false,
        hasPersistedTracks: true,
        hasRecoveryIssue: true,
      );

      expect(decision.action, TrackStartupAction.wipeAndImport);
      expect(decision.markMigrationComplete, isTrue);
    });

    test('decides empty first startup should mark then import', () {
      final decision = TrackMigrationMarkerStore.decideStartupAction(
        migrationMarked: false,
        hasPersistedTracks: false,
        hasRecoveryIssue: false,
      );

      expect(decision.action, TrackStartupAction.importTracks);
      expect(decision.markMigrationComplete, isTrue);
    });

    test('decides later corrupt optimized rows should show recovery', () {
      final decision = TrackMigrationMarkerStore.decideStartupAction(
        migrationMarked: true,
        hasPersistedTracks: true,
        hasRecoveryIssue: true,
      );

      expect(decision.action, TrackStartupAction.showRecovery);
      expect(decision.markMigrationComplete, isFalse);
    });
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
        'distance': 10.5,
        'ascent': 900.0,
        'totalTimeMillis': 3600000,
        'trackColour': 0xFFa726bc,
      };

      final track = GpxTrack.fromMap(map);
      final encoded = track.toMap();

      expect(track.gpxTrackId, 1);
      expect(track.contentHash, 'hash');
      expect(track.trackName, 'Frenchmans Cap');
      expect(track.startDateTime, isNotNull);
      expect(track.endDateTime, isNotNull);
      expect(track.gpxFile, '<gpx></gpx>');
      expect(encoded['contentHash'], 'hash');
      expect(encoded['trackName'], 'Frenchmans Cap');
      expect(encoded['trackDate'], isNotNull);
      expect(encoded['endDateTime'], isNotNull);
      expect(encoded['gpxFile'], '<gpx></gpx>');
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
        repository.addTrack(track);

        final found = repository.findByContentHash('hash-1');

        expect(found, isNotNull);
        expect(found!.trackName, 'Track 1');
      });

      test('findByTrackNameAndTrackDate uses metadata-date rows only', () {
        repository.addTrack(
          GpxTrack(
            contentHash: 'no-meta',
            trackName: 'Track A',
            trackDate: DateTime(2024, 1, 15),
          ),
        );
        repository.addTrack(
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
