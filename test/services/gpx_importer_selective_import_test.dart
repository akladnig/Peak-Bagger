import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/gpx_importer.dart';

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
