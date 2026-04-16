import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/tasmap50k.dart';

void main() {
  group('Tasmap50k', () {
    test('mgrs100kIdList parses single code', () {
      final map = Tasmap50k(
        series: 'TQ08',
        name: 'Wellington',
        parentSeries: '8312',
        mgrs100kIds: 'EN',
        eastingMin: 0,
        eastingMax: 40,
        northingMin: 40,
        northingMax: 70,
      );

      expect(map.mgrs100kIdList, ['EN']);
    });

    test('mgrs100kIdList parses multiple codes', () {
      final map = Tasmap50k(
        series: 'TK05',
        name: 'Black Bluff',
        parentSeries: '7914',
        mgrs100kIds: 'CP DP CQ DQ',
        eastingMin: 80,
        eastingMax: 20,
        northingMin: 90,
        northingMax: 20,
      );

      expect(map.mgrs100kIdList, ['CP', 'DP', 'CQ', 'DQ']);
    });

    test('mgrs100kIdList handles whitespace-padded codes', () {
      final map = Tasmap50k(
        series: 'TK05',
        name: 'Black Bluff',
        parentSeries: '7914',
        mgrs100kIds: 'CP DP CQ DQ',
        eastingMin: 80,
        eastingMax: 20,
        northingMin: 90,
        northingMax: 20,
      );

      expect(map.mgrs100kIdList.length, 4);
    });

    test('polygonPoints returns sequential non-empty points', () {
      final map = Tasmap50k(
        series: 'TS07',
        name: 'Adamsons',
        parentSeries: '8211',
        p1: 'DN6000009999',
        p2: 'DN9999909999',
        p3: 'DM6000080000',
        p4: 'DM9999980000',
      );

      expect(map.polygonPoints, [
        'DN6000009999',
        'DN9999909999',
        'DM6000080000',
        'DM9999980000',
      ]);
      expect(map.hasValidPolygonPointCount, isTrue);
    });
  });
}
