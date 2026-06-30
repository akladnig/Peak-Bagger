import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/map_search_service.dart';
import 'package:peak_bagger/services/peak_repository.dart';

void main() {
  test('empty query returns no peak results', () {
    final service = MapSearchService(
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([_peak(1, 'Alpha'), _peak(2, 'Beta')]),
      ),
    );

    expect(service.searchPeaks(''), isEmpty);
    expect(service.searchPeaks('   '), isEmpty);
  });

  test('peak search is case-insensitive and capped', () {
    final service = MapSearchService(
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage(
          List.generate(25, (index) => _peak(index + 1, 'Peak $index')),
        ),
      ),
    );

    final results = service.searchPeaks('peak');

    expect(results, hasLength(20));
    expect(results.first.name, 'Peak 0');
  });
}

Peak _peak(int osmId, String name) {
  return Peak(osmId: osmId, name: name, latitude: -42, longitude: 147);
}
