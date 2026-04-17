import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/providers/gpx_filter_settings_provider.dart';
import 'package:peak_bagger/services/gpx_importer.dart';

void main() {
  test('importTracks stores filteredTrack for hiking tracks', () async {
    final tempDir = await Directory.systemTemp.createTemp('gpx-import-filter');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
    final tasmaniaDir = Directory('${tracksDir.path}/Tasmania')..createSync();
    final source = File('${tracksDir.path}/test-track.gpx');
    const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Test Track</name>
    <trkseg>
      <trkpt lat="-42.0000" lon="146.0000">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.0001" lon="146.0001">
        <ele>123</ele>
      </trkpt>
      <trkpt lat="-42.0002" lon="146.0002">
        <time>2024-01-15T08:10:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
    await source.writeAsString(rawXml);

    final importer = GpxImporter(
      tracksFolder: tracksDir.path,
      tasmaniaFolder: tasmaniaDir.path,
    );

    final result = await importer.importTracks(
      includeTasmaniaFolder: false,
      filterConfig: GpxFilterConfig.defaults,
    );

    expect(result.importedCount, 1);
    expect(result.warning, isNull);
    expect(result.tracks, hasLength(1));

    final track = result.tracks.single;
    expect(track.gpxFile, rawXml);
    expect(track.filteredTrack, isNotEmpty);
    expect(track.filteredTrack, isNot(rawXml));
    expect(track.filteredTrack, contains('<trkpt'));
    expect(track.startDateTime, isNotNull);
    expect(track.startDateTime!.isUtc, isTrue);
    expect(track.endDateTime, isNotNull);
    expect(track.endDateTime!.isUtc, isTrue);
    expect(track.totalTimeMillis, 600000);
    expect(track.movingTime, 600000);
    expect(track.restingTime, 0);
    expect(track.pausedTime, 0);
    expect(track.displayTrackPointsByZoom, isNot('{}'));
    expect(track.getSegmentsForZoom(15), hasLength(1));
    expect(track.getSegmentsForZoom(15).single, hasLength(2));
  });

  test(
    'importTracks falls back to raw GPX when filtering removes too much',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'gpx-import-fallback',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasmaniaDir = Directory('${tracksDir.path}/Tasmania')..createSync();
      final source = File('${tracksDir.path}/fallback-track.gpx');
      const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Fallback Track</name>
    <trkseg>
      <trkpt lat="-42.0000" lon="146.0000">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      await source.writeAsString(rawXml);

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasmaniaDir.path,
      );

      final result = await importer.importTracks(
        includeTasmaniaFolder: false,
        filterConfig: GpxFilterConfig.defaults,
      );

      expect(result.importedCount, 1);
      expect(result.warning, contains('raw GPX fallback'));
      expect(result.tracks.single.filteredTrack, isEmpty);
      expect(result.tracks.single.totalTimeMillis, 0);
      expect(result.tracks.single.movingTime, 0);
      expect(result.tracks.single.restingTime, 0);
      expect(result.tracks.single.pausedTime, 0);
    },
  );

  test(
    'refreshExistingTracks replaces existing rows with filtered output',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'gpx-import-refresh',
      );
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });

      final tracksDir = Directory('${tempDir.path}/Tracks')..createSync();
      final tasmaniaDir = Directory('${tracksDir.path}/Tasmania')..createSync();
      final source = File('${tracksDir.path}/refresh-track.gpx');
      const rawXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="test">
  <trk>
    <name>Refresh Track</name>
    <trkseg>
      <trkpt lat="-42.1000" lon="146.1000">
        <time>2024-01-15T08:00:00Z</time>
      </trkpt>
      <trkpt lat="-42.1001" lon="146.1001">
        <ele>123</ele>
      </trkpt>
      <trkpt lat="-42.1002" lon="146.1002">
        <time>2024-01-15T08:10:00Z</time>
      </trkpt>
    </trkseg>
  </trk>
</gpx>
''';
      await source.writeAsString(rawXml);

      final importer = GpxImporter(
        tracksFolder: tracksDir.path,
        tasmaniaFolder: tasmaniaDir.path,
      );

      final firstResult = await importer.importTracks(
        includeTasmaniaFolder: false,
        filterConfig: GpxFilterConfig.defaults,
      );

      final secondResult = await importer.importTracks(
        includeTasmaniaFolder: true,
        existingTracks: firstResult.tracks,
        refreshExistingTracks: true,
        filterConfig: GpxFilterConfig.defaults,
      );

      expect(secondResult.replacedCount, 1);
      expect(secondResult.unchangedCount, 0);
      expect(secondResult.tracks.single.filteredTrack, isNotEmpty);
      expect(secondResult.tracks.single.startDateTime, isNotNull);
      expect(secondResult.tracks.single.startDateTime!.isUtc, isTrue);
      expect(secondResult.tracks.single.endDateTime, isNotNull);
      expect(secondResult.tracks.single.endDateTime!.isUtc, isTrue);
      expect(secondResult.tracks.single.totalTimeMillis, 600000);
      expect(secondResult.tracks.single.movingTime, 600000);
      expect(secondResult.tracks.single.restingTime, 0);
      expect(secondResult.tracks.single.pausedTime, 0);
      expect(
        secondResult.tracks.single.getSegmentsForZoom(15).single,
        hasLength(2),
      );
    },
  );
}
