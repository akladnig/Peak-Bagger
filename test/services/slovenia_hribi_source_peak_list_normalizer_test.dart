import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/services/slovenia_hribi_source_peak_list_service.dart';

void main() {
  group('SloveniaHribiSourcePeakListNormalizer', () {
    const normalizer = SloveniaHribiSourcePeakListNormalizer();

    test('exposes the locked Slovenia range configuration in spec order', () {
      expect(sloveniaHribiSourceRangeConfigurations, hasLength(10));
      expect(
        sloveniaHribiSourceRangeConfigurations.map((range) => range.order),
        [1, 2, 3, 4, 5, 6, 7, 8, 9, 10],
      );
      expect(
        sloveniaHribiSourceRangeConfigurations[1].mountainRangeLabel,
        'Julian Alps',
      );
      expect(
        sloveniaHribiSourceRangeConfigurations[3].hribiRangeUrl,
        'https://www.hribi.net/gorovje/karavanke/11',
      );
    });

    test('normalizes country order and removes duplicates', () {
      expect(
        normalizer.normalizeCountry('Hrvaška, Avstrija, Hrvaška'),
        'Croatia, Austria',
      );
    });

    test('normalizes altitude popularity and coordinates', () {
      expect(normalizer.normalizeAltitude('2.753 m'), '2753');
      expect(normalizer.normalizePopularity('95% (5. mesto)'), '95');
      expect(normalizer.normalizeCoordinates('46,37832°N 13,83648°E'), (
        latitude: '46.37832',
        longitude: '13.83648',
      ));
    });

    test('applies Slovenia-only naming and removes duplicate alt names', () {
      expect(
        normalizer.resolveNames(
          hribiName: 'Triglav',
          montiName: 'Monte Triglav',
          normalizedCountry: 'Slovenia',
        ),
        (name: 'Triglav', altName: 'Monte Triglav'),
      );
      expect(
        normalizer.resolveNames(
          hribiName: 'Stol',
          montiName: 'Stol',
          normalizedCountry: 'Slovenia',
        ),
        (name: 'Stol', altName: ''),
      );
    });

    test('applies Italy and multi-country naming', () {
      expect(
        normalizer.resolveNames(
          hribiName: 'Montaž / Jôf di Montasio',
          montiName: 'Jôf di Montasio',
          normalizedCountry: 'Italy',
        ),
        (name: 'Jôf di Montasio', altName: 'Montaž / Jôf di Montasio'),
      );
      expect(
        normalizer.resolveNames(
          hribiName: 'Krn',
          montiName: 'Monte Nero / Krn',
          normalizedCountry: 'Italy, Slovenia',
        ),
        (name: 'Monte Nero / Krn', altName: 'Krn'),
      );
    });

    test('uses vrh to confirm peaks', () {
      expect(normalizer.isPeakType('vrh, bivak'), isTrue);
      expect(normalizer.isPeakType('planinski dom'), isFalse);
    });
  });
}
