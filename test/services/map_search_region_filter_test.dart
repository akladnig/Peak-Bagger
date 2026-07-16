import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';

void main() {
  test(
    'search region options come only from manifest showInPeakList regions',
    () {
      final options = buildMapSearchRegionOptions();

      expect(
        options.map((option) => option.key).toList(growable: false),
        const ['tasmania', 'italy-nord-est', 'italy-nord-ovest', 'slovenia'],
      );
      expect(options.any((option) => option.key == 'fvg'), isFalse);
      expect(options.any((option) => option.key == 'italy'), isFalse);
      expect(options.any((option) => option.key == 'new-south-wales'), isFalse);
    },
  );

  test('search region labels use manifest compact names', () {
    expect(mapSearchRegionLabel('tasmania'), 'Tas');
    expect(mapSearchRegionLabel('italy-nord-est'), 'Italy NE');
    expect(mapSearchRegionLabel('fvg'), 'FVG');
    expect(mapSearchRegionLabel('slovenia'), 'Slovenia');
  });

  test(
    'aggregate region filters match child stored peak regions via aliases',
    () {
      expect(
        peakMatchesSearchRegion(
          storedPeakRegionKey: 'fvg',
          resolvedRegionKey: 'italy-nord-est',
          filterRegionKey: 'italy-nord-est',
        ),
        isTrue,
      );
      expect(
        peakMatchesSearchRegion(
          storedPeakRegionKey: 'veneto',
          resolvedRegionKey: 'italy-nord-est',
          filterRegionKey: 'italy-nord-est',
        ),
        isTrue,
      );
    },
  );

  test('child region filters stay exact for peaks', () {
    expect(
      peakMatchesSearchRegion(
        storedPeakRegionKey: 'fvg',
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isTrue,
    );
    expect(
      peakMatchesSearchRegion(
        storedPeakRegionKey: 'veneto',
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isFalse,
    );
    expect(
      peakMatchesSearchRegion(
        storedPeakRegionKey: 'italy-nord-est',
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isFalse,
    );
  });

  test('non-peak child filters roll up through manifest aliases', () {
    expect(
      nonPeakMatchesSearchRegion(
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isTrue,
    );
    expect(
      nonPeakMatchesSearchRegion(
        resolvedRegionKey: 'slovenia',
        filterRegionKey: 'fvg',
      ),
      isFalse,
    );
  });
}
