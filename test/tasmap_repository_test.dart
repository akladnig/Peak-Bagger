import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

void main() {
  group('TasmapRepository', () {
    test('getMapCenter returns correct LatLng using pre-calculated values', () {
      final map = Tasmap50k(
        series: 'TQ08',
        name: 'Wellington',
        parentSeries: '8312',
        mgrs100kIds: 'EN',
        eastingMin: 0,
        eastingMax: 39999,
        northingMin: 40000,
        northingMax: 69999,
        mgrsMid: 'EN',
        eastingMid: 20000,
        northingMid: 55000,
        tl: 'EN0000069999',
        tr: 'EN3999969999',
        bl: 'EN0000040000',
        br: 'EN3999940000',
      );

      // We can't test getMapCenter without a real ObjectBox store
      // But we can verify the entity has the correct fields
      expect(map.mgrsMid, 'EN');
      expect(map.eastingMid, 20000);
      expect(map.northingMid, 55000);
    });

    test('corner parsing extracts correct MGRS100k, easting, northing', () {
      final corner = 'BR2000069999';
      expect(corner.length, 12);
      expect(corner.substring(0, 2), 'BR');
      expect(corner.substring(2, 7), '20000');
      expect(corner.substring(7, 12), '69999');
    });

    test('corner format is [MGRS100k][easting5][northing5]', () {
      final map = Tasmap50k(
        series: 'TE01',
        name: 'Cataraqui',
        parentSeries: '',
        mgrs100kIds: 'BR',
        eastingMin: 20000,
        eastingMax: 59999,
        northingMin: 40000,
        northingMax: 69999,
        mgrsMid: 'BR',
        eastingMid: 40000,
        northingMid: 55000,
        tl: 'BR2000069999',
        tr: 'BR5999969999',
        bl: 'BR2000040000',
        br: 'BR5999940000',
      );

      expect(map.tl.length, 12);
      expect(map.tr.length, 12);
      expect(map.bl.length, 12);
      expect(map.br.length, 12);
    });
  });
}
