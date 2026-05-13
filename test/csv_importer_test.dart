import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/csv_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CsvImporter', () {
    test('importFromCsv returns 75 maps', () async {
      final result = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      expect(result.importedCount, 75);
      expect(result.maps, hasLength(75));
    });

    test('importFromCsv populates new fields correctly', () async {
      final result = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      final wellington = result.maps.firstWhere((m) => m.name == 'Wellington');

      expect(wellington.mgrsMid, 'EN');
      expect(wellington.eastingMid, 20000);
      expect(wellington.northingMid, 55000);
      expect(wellington.p1, 'EN0000069999');
      expect(wellington.p2, 'EN3999969999');
      expect(wellington.p3, 'EN3999940000');
      expect(wellington.p4, 'EN0000040000');
      expect(wellington.p5, isEmpty);
      expect(wellington.p6, isEmpty);
      expect(wellington.p7, isEmpty);
      expect(wellington.p8, isEmpty);
    });

    test(
      'importFromCsv uses correct column names (eastingMin not Xmin)',
      () async {
        final result = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
        final wellington = result.maps.firstWhere(
          (m) => m.name == 'Wellington',
        );

        expect(wellington.eastingMin, 0);
        expect(wellington.eastingMax, 39999);
        expect(wellington.northingMin, 40000);
        expect(wellington.northingMax, 69999);
      },
    );

    test('importFromCsv handles wrap-around ranges', () async {
      final result = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      final blackBluff = result.maps.firstWhere((m) => m.name == 'Black Bluff');

      expect(blackBluff.eastingMin, 80000);
      expect(blackBluff.eastingMax, 19999);
      expect(blackBluff.northingMin, 90000);
      expect(blackBluff.northingMax, 19999);
    });

    test('importFromCsv prefers a filesystem csv when present', () async {
      final tempDir = await Directory.systemTemp.createTemp('tasmap-csv-test');
      addTearDown(() => tempDir.delete(recursive: true));

      final csvFile = File('${tempDir.path}/tasmap50k.csv');
      final sourceContents = await File('assets/tasmap50k.csv').readAsString();
      final modifiedContents = sourceContents.replaceFirst(
        'TQ08,Wellington,8312,EN   ,0,39999,40000,69999,EN,20000,55000,EN0000069999,EN3999969999,EN3999940000,EN0000040000,,,,',
        'TQ08,Wellington Test,8312,EN   ,0,39999,40000,69999,EN,20000,55000,EN0000069999,EN3999969999,EN3999940000,EN0000040000,,,,',
      );
      await csvFile.writeAsString(modifiedContents);

      final result = await CsvImporter.importFromCsv(csvFile.path);
      final wellington = result.maps.firstWhere(
        (map) => map.name == 'Wellington Test',
      );

      expect(result.importedCount, 75);
      expect(wellington.name, 'Wellington Test');
      expect(wellington.p4, 'EN0000040000');
    });

    test('normalizePointValue removes spaces and uppercases', () {
      expect(CsvImporter.normalizePointValue('en 00000 69999'), 'EN0000069999');
    });

    test('parseRow accepts 12 sequential point columns', () {
      final headers = [
        'Series',
        'Name',
        'Parent',
        'MGRS',
        'eastingMin',
        'eastingMax',
        'northingMin',
        'northingMax',
        'mgrsMid',
        'eastingMid',
        'northingMid',
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
        'p9',
        'p10',
        'p11',
        'p12',
      ];
      final row = [
        'TS07',
        'Adamsons',
        '8211',
        'DM DN',
        60000,
        99999,
        80000,
        9999,
        'DM',
        80000,
        95000,
        'DN6000009999',
        'DN6999909999',
        'DN6999940000',
        'DN6000040000',
        'DM6000080000',
        'DM6999980000',
        'DM7999980000',
        'DM7999889999',
        'DN7999889999',
        'DN7999940000',
        'DN6999940000',
        'DN6000040000',
      ];

      final result = CsvImporter.parseRow(headers, row, rowNumber: 2);

      expect(result.map, isNotNull);
      expect(result.map!.polygonPoints, hasLength(12));
      expect(result.map!.polygonPoints.first, 'DN6000009999');
      expect(result.map!.polygonPoints.last, 'DN6000040000');
    });

    test('parseRow accepts 10 sequential point columns', () {
      final headers = [
        'Series',
        'Name',
        'Parent',
        'MGRS',
        'eastingMin',
        'eastingMax',
        'northingMin',
        'northingMax',
        'mgrsMid',
        'eastingMid',
        'northingMid',
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
        'p9',
        'p10',
      ];
      final row = [
        'TS07',
        'Adamsons',
        '8211',
        'DM DN',
        60000,
        99999,
        80000,
        9999,
        'DM',
        80000,
        95000,
        'DN6000009999',
        'DN6999909999',
        'DN6999940000',
        'DN6000040000',
        'DM6000080000',
        'DM6999980000',
        'DM7999980000',
        'DM7999889999',
        'DN7999889999',
        'DN7999940000',
      ];

      final result = CsvImporter.parseRow(headers, row, rowNumber: 2);

      expect(result.map, isNotNull);
      expect(result.map!.polygonPoints, hasLength(10));
      expect(result.map!.hasValidPolygonPointCount, isTrue);
    });

    test('parseRow rejects non-sequential and short point runs', () {
      final headers = [
        'Series',
        'Name',
        'Parent',
        'MGRS',
        'eastingMin',
        'eastingMax',
        'northingMin',
        'northingMax',
        'mgrsMid',
        'eastingMid',
        'northingMid',
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
      ];
      final row = [
        'TS07',
        'Adamsons',
        '8211',
        'DM DN',
        60000,
        99999,
        80000,
        9999,
        'DM',
        80000,
        95000,
        'DN6000009999',
        'DN9999909999',
        'DM6000080000',
        'DM9999980000',
        'DN6000040000',
        '',
        '',
        '',
      ];

      final result = CsvImporter.parseRow(headers, row, rowNumber: 2);

      expect(result.map, isNull);
      expect(result.error, contains('expected 4, 6, or 8 points'));
    });

    test('parseRow rejects populated point columns beyond p12', () {
      final headers = [
        'Series',
        'Name',
        'Parent',
        'MGRS',
        'eastingMin',
        'eastingMax',
        'northingMin',
        'northingMax',
        'mgrsMid',
        'eastingMid',
        'northingMid',
        'p1',
        'p2',
        'p3',
        'p4',
        'p5',
        'p6',
        'p7',
        'p8',
        'p9',
        'p10',
        'p11',
        'p12',
        'p13',
      ];
      final row = [
        'TS07',
        'Adamsons',
        '8211',
        'DM DN',
        60000,
        99999,
        80000,
        9999,
        'DM',
        80000,
        95000,
        'DN6000009999',
        'DN6999909999',
        'DN6999940000',
        'DN6000040000',
        'DM6000080000',
        'DM6999980000',
        'DM7999980000',
        'DM7999889999',
        'DN7999889999',
        'DN7999940000',
        'DN6999940000',
        'DN6000040000',
        'DN5000040000',
      ];

      final result = CsvImporter.parseRow(headers, row, rowNumber: 3);

      expect(result.map, isNull);
      expect(result.error, contains('p13'));
    });
  });
}
