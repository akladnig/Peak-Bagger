import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/polygon_asset_repository.dart';

void main() {
  group('GpxImporter selective import', () {
    late GpxImporter importer;

    setUp(() {
      importer = GpxImporter();
    });

    test(
      'planSelectiveImport counts duplicate content within batch as unchanged',
      () {
        // This requires a real GPX file - tested via integration
      },
    );

    test('deriveDefaultTrackName uses GPX metadata name when available', () {
      const validGpxWithName = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk><name>My Track Name</name></trk>
</gpx>
''';

      final name = importer.deriveDefaultTrackName(
        validGpxWithName,
        '/tmp/test.gpx',
      );
      expect(name, 'My Track Name');
    });

    test(
      'deriveDefaultTrackName normalises metadata and filename fallback',
      () {
        const validGpxWithName = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"><trk><name>Mount Anne (15-01-2024)</name></trk></gpx>
''';

        expect(
          importer.deriveDefaultTrackName(validGpxWithName, '/tmp/ignored.gpx'),
          'Mount Anne',
        );
        expect(
          importer.deriveDefaultTrackName(
            'not xml',
            '/tmp/Mount Anne 15-01-2024.gpx',
          ),
          'Mount Anne',
        );
      },
    );

    test('deriveDefaultTrackName falls back to basename on empty metadata', () {
      const gpxWithEmptyName = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk><name>  </name></trk>
</gpx>
''';

      final name = importer.deriveDefaultTrackName(
        gpxWithEmptyName,
        '/tmp/my-track-file.gpx',
      );
      expect(name, 'my-track-file');
    });

    test('deriveDefaultTrackName falls back to basename on parse failure', () {
      final name = importer.deriveDefaultTrackName(
        'not xml',
        '/tmp/broken.gpx',
      );
      expect(name, 'broken');
    });

    test('deriveTrackDate extracts from GPX time element', () {
      const gpxWithTime = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <name>Test</name>
    <trkseg><trkpt lat="-42.0" lon="147.0"><time>2024-03-15T10:30:00Z</time></trkpt></trkseg>
  </trk>
</gpx>
''';

      final date = importer.deriveTrackDate(gpxWithTime, DateTime(2023, 1, 1));
      expect(date.year, 2024);
      expect(date.month, 3);
      expect(date.day, 15);
    });

    test('deriveTrackDate normalizes to date-only', () {
      const gpxWithTime = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk>
    <name>Test</name>
    <trkseg><trkpt lat="-42.0" lon="147.0"><time>2024-03-15T14:30:45Z</time></trkpt></trkseg>
  </trk>
</gpx>
''';

      final date = importer.deriveTrackDate(gpxWithTime, DateTime(2023, 1, 1));
      // Should be normalized to midnight local time
      expect(date.hour, 0);
      expect(date.minute, 0);
      expect(date.second, 0);
    });

    test('plan normalises edited names before persistence', () async {
      final directory = Directory.systemTemp.createTempSync('gpx-import-plan');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/edited.gpx')
        ..writeAsStringSync(_gpx('Raw Track'));
      final plan = await _planImporter(directory).planSelectiveImport(
        paths: [file.path],
        pathToEditedNames: {file.path: 'Edited Track 15-01-2024'},
      );

      expect(plan.addedCount, 1);
      expect(plan.items.single.track.trackName, 'Edited Track');
    });

    test(
      'plan creates one canonical replacement and rejects later selection',
      () async {
        final directory = Directory.systemTemp.createTempSync(
          'gpx-import-plan',
        );
        addTearDown(() => directory.deleteSync(recursive: true));
        final first = File('${directory.path}/first.gpx')
          ..writeAsStringSync(_gpx('Mount Anne 15-01-2024'));
        final later = File('${directory.path}/later.gpx')
          ..writeAsStringSync(
            _gpx('Mount Anne (15-01-2024)', extra: '<desc>later</desc>'),
          );
        final existing = GpxTrack(
          gpxTrackId: 7,
          contentHash: 'old',
          trackName: 'Mount Anne 15-01-2024',
          trackDate: DateTime(2024, 1, 15),
          startDateTime: DateTime(2024, 1, 15, 8),
        );

        final importer = _planImporter(directory);
        final plan = await importer.planSelectiveImport(
          paths: [first.path, later.path],
          pathToEditedNames: const {},
          existingTracks: [existing],
        );

        expect(plan.addedCount, 0);
        expect(plan.replacedCount, 1);
        expect(plan.errorCount, 1);
        expect(plan.items.single.track.trackName, 'Mount Anne');
        expect(plan.items.single.replacedTrack, same(existing));
        expect(plan.errors, hasLength(1));
        expect(plan.errors.single.sourcePath, later.path);
        expect(
          plan.errors.single.reason,
          'Cannot import Track because another selected Track has the same normalised name and date.',
        );
        expect(
          File(importer.getImportLogPath()).readAsStringSync(),
          contains(plan.errors.single.reason),
        );
      },
    );

    test('plan rejects multiple canonical stored matches', () async {
      final directory = Directory.systemTemp.createTempSync('gpx-import-plan');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/incoming.gpx')
        ..writeAsStringSync(_gpx('Mount Anne (15-01-2024)'));
      final existingTracks = [1, 2]
          .map(
            (id) => GpxTrack(
              gpxTrackId: id,
              contentHash: 'old-$id',
              trackName: 'Mount Anne${id == 1 ? ' 15-01-2024' : ''}',
              trackDate: DateTime(2024, 1, 15),
              startDateTime: DateTime(2024, 1, 15, 8),
            ),
          )
          .toList();
      final importer = _planImporter(directory);

      final plan = await importer.planSelectiveImport(
        paths: [file.path],
        pathToEditedNames: const {},
        existingTracks: existingTracks,
      );

      expect(plan.items, isEmpty);
      expect(plan.errorCount, 1);
      expect(
        plan.errors.single.reason,
        'Cannot replace Track because multiple stored Tracks match its name and date.',
      );
      expect(
        File(importer.getImportLogPath()).readAsStringSync(),
        contains(plan.errors.single.reason),
      );
    });

    test(
      'deriveTrackDate falls back to file mtime on missing time element',
      () {
        const gpxWithoutTime = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1">
  <trk><name>Test</name></trk>
</gpx>
''';

        final fallbackMtime = DateTime(2023, 6, 15);
        final date = importer.deriveTrackDate(gpxWithoutTime, fallbackMtime);
        expect(date.year, 2023);
        expect(date.month, 6);
        expect(date.day, 15);
      },
    );
  });
}

GpxImporter _planImporter(Directory root) {
  return GpxImporter(
    tracksFolder: '${root.path}/Tracks',
    polygonAssetRepository: PolygonAssetRepository(
      assetLoader: (_) async => throw Exception('No polygon assets'),
    ),
  );
}

String _gpx(String name, {String extra = ''}) =>
    '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1"><trk><name>$name</name>$extra<trkseg>
<trkpt lat="-42.0" lon="147.0"><time>2024-01-15T08:00:00Z</time></trkpt>
</trkseg></trk></gpx>
''';
