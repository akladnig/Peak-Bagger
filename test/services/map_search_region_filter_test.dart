import 'package:flutter_test/flutter_test.dart';
import '../harness/mapping_catalog_fixture.dart';
import 'package:peak_bagger/services/map_search_region_filter.dart';

void main() {
  test(
    'search region options come only from manifest showInPeakList regions',
    () {
      final options = buildMapSearchRegionOptions(testMappingCatalog);

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
    expect(
      mapSearchRegionLabel('tasmania', catalog: testMappingCatalog),
      'Tas',
    );
    expect(
      mapSearchRegionLabel('italy-nord-est', catalog: testMappingCatalog),
      'Italy NE',
    );
    expect(mapSearchRegionLabel('fvg', catalog: testMappingCatalog), 'FVG');
    expect(
      mapSearchRegionLabel('slovenia', catalog: testMappingCatalog),
      'Slovenia',
    );
  });

  test(
    'aggregate region filters match child stored peak regions via aliases',
    () {
      expect(
        peakMatchesSearchRegion(
          catalog: testMappingCatalog,
          storedPeakRegionKey: 'fvg',
          resolvedRegionKey: 'italy-nord-est',
          filterRegionKey: 'italy-nord-est',
        ),
        isTrue,
      );
      expect(
        peakMatchesSearchRegion(
          catalog: testMappingCatalog,
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
        catalog: testMappingCatalog,
        storedPeakRegionKey: 'fvg',
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isTrue,
    );
    expect(
      peakMatchesSearchRegion(
        catalog: testMappingCatalog,
        storedPeakRegionKey: 'veneto',
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isFalse,
    );
    expect(
      peakMatchesSearchRegion(
        catalog: testMappingCatalog,
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
        catalog: testMappingCatalog,
        resolvedRegionKey: 'italy-nord-est',
        filterRegionKey: 'fvg',
      ),
      isTrue,
    );
    expect(
      nonPeakMatchesSearchRegion(
        catalog: testMappingCatalog,
        resolvedRegionKey: 'slovenia',
        filterRegionKey: 'fvg',
      ),
      isFalse,
    );
  });
}
