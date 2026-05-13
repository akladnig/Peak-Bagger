import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/services/peak_info_content_resolver.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_tasmap_repository.dart';

void main() {
  test('resolves map and list names for a peak', () async {
    final peak = Peak(
      osmId: 42,
      name: 'Alpha Peak',
      latitude: -42.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'EN',
      easting: '12345',
      northing: '67890',
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Abels',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 42, points: 10),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 99, points: 4),
          ]),
        )..peakListId = 2,
      ]),
    );
    final tasmapRepository = await TestTasmapRepository.create(
      maps: [
        Tasmap50k(
          series: 'TS07',
          name: 'Test Map',
          parentSeries: '8211',
          mgrs100kIds: 'EN',
          eastingMin: 10000,
          eastingMax: 20000,
          northingMin: 60000,
          northingMax: 70000,
        ),
      ],
    );

    final content = resolvePeakInfoContent(
      peak: peak,
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
    );

    expect(content.peak, same(peak));
    expect(content.mapName, 'Test Map');
    expect(content.listNames, ['Abels']);
  });
}
