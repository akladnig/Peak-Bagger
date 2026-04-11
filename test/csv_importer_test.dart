import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/csv_importer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CsvImporter', () {
    test('importFromCsv returns 75 maps', () async {
      final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      expect(maps.length, 75);
    });

    test('importFromCsv populates new fields correctly', () async {
      final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      final wellington = maps.firstWhere((m) => m.name == 'Wellington');

      expect(wellington.mgrsMid, 'EN');
      expect(wellington.eastingMid, 20000);
      expect(wellington.northingMid, 55000);
      expect(wellington.tl, 'EN0000069999');
      expect(wellington.tr, 'EN3999969999');
      expect(wellington.bl, 'EN0000040000');
      expect(wellington.br, 'EN3999940000');
    });

    test(
      'importFromCsv uses correct column names (eastingMin not Xmin)',
      () async {
        final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
        final wellington = maps.firstWhere((m) => m.name == 'Wellington');

        expect(wellington.eastingMin, 0);
        expect(wellington.eastingMax, 39999);
        expect(wellington.northingMin, 40000);
        expect(wellington.northingMax, 69999);
      },
    );

    test('importFromCsv handles wrap-around ranges', () async {
      final maps = await CsvImporter.importFromCsv('assets/tasmap50k.csv');
      final blackBluff = maps.firstWhere((m) => m.name == 'Black Bluff');

      expect(blackBluff.eastingMin, 80000);
      expect(blackBluff.eastingMax, 19999);
      expect(blackBluff.northingMin, 90000);
      expect(blackBluff.northingMax, 19999);
    });
  });
}
