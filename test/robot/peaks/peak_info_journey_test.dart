import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../../harness/test_tasmap_repository.dart';
import 'peak_info_robot.dart';

void main() {
  testWidgets('peak info journey hover shows click cursor and halo', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    r.expectPeakMarkerSelectors(6406);
    await r.hoverPeak(6406);

    r.expectPeakHover(6406);
  });

  testWidgets('peak info journey click opens popup content and close button', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    await r.clickPeak(6406);
    r.expectPeakPopupWithContent('Bonnet Hill');

    await r.closePeakPopup();
    r.expectNoPeakPopup();
  });

  testWidgets('peak info journey shows seeded MGRS and singular list', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: ' Abels ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
      ]),
    );
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            elevation: 1234,
            latitude: -43.0,
            longitude: 147.0,
            gridZoneDesignator: '55G',
            mgrs100kId: 'DM',
            easting: '80000',
            northing: '95000',
          ),
        ],
      ),
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
    );

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1234m',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
      'List: Abels',
    ]);
  });

  testWidgets('peak info journey shows seeded MGRS and plural lists', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'HWC  ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 1),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Abels  ',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 6406, points: 2),
          ]),
        )..peakListId = 2,
      ]),
    );
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            elevation: 1234,
            latitude: -43.0,
            longitude: 147.0,
            gridZoneDesignator: '55G',
            mgrs100kId: 'DM',
            easting: '80000',
            northing: '95000',
          ),
        ],
      ),
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
    );

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1234m',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
      'Lists: Abels, HWC',
    ]);
  });

  testWidgets(
    'peak info journey background click closes popup and selects map',
    (tester) async {
      final r = PeakInfoRobot(tester);
      addTearDown(r.dispose);

      await r.pumpMap();

      await r.clickPeak(6406);
      r.expectPeakPopupWithContent('Bonnet Hill');

      await r.clickMapBackground();

      r.expectNoPeakPopup();
      r.expectSelectedLocation();
    },
  );
}
