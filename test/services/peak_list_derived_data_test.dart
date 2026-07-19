import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/peak_list_derived_data.dart';

void main() {
  group('derivePeakListDerivedData', () {
    test('computes multi-point bounds and mixed classification', () {
      final peakList = PeakList(name: 'Mixed List');
      const items = [
        PeakListItem(peakOsmId: 101, points: 1),
        PeakListItem(peakOsmId: 202, points: 1),
      ];
      final peaksByOsmId = {
        101: Peak(
          osmId: 101,
          name: 'FVG Peak',
          latitude: 46.4084,
          longitude: 13.0475,
          region: 'fvg',
        ),
        202: Peak(
          osmId: 202,
          name: 'Veneto Peak',
          latitude: 45.7332,
          longitude: 10.8061,
          region: 'veneto',
        ),
      };

      final derived = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (peakOsmId) => peaksByOsmId[peakOsmId],
      );

      expect(derived.region, PeakList.mixedRegion);
      expect(derived.minLat, 45.7332);
      expect(derived.maxLat, 46.4084);
      expect(derived.minLng, 10.8061);
      expect(derived.maxLng, 13.0475);
    });

    test('leaves bounds null when no member peak coordinates resolve', () {
      final peakList = PeakList(name: 'Broken', region: 'veneto');
      const items = [PeakListItem(peakOsmId: 999, points: 1)];

      final derived = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (_) => null,
      );

      expect(derived.region, 'veneto');
      expect(derived.minLat, isNull);
      expect(derived.maxLat, isNull);
      expect(derived.minLng, isNull);
      expect(derived.maxLng, isNull);
    });

    test('preserves collapsed single-point bounds', () {
      final peakList = PeakList(name: 'Single Point');
      const items = [PeakListItem(peakOsmId: 101, points: 1)];
      final peak = Peak(
        osmId: 101,
        name: 'Single Peak',
        latitude: -41.5,
        longitude: 146.5,
      );

      final derived = derivePeakListDerivedData(
        peakList: peakList,
        items: items,
        peakResolver: (_) => peak,
      );

      expect(derived.region, Peak.defaultRegion);
      expect(derived.minLat, -41.5);
      expect(derived.maxLat, -41.5);
      expect(derived.minLng, 146.5);
      expect(derived.maxLng, 146.5);
    });
  });
}
