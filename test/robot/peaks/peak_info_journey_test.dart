import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';

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
      'Height: 1,234m',
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
      'Height: 1,234m',
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

  testWidgets('peak info journey drop marker keeps popup open and updates selection', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peakListRepository = PeakListRepository.test(InMemoryPeakListStorage());
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage([
        PeaksBagged(baggedId: 1, peakId: 6406, gpxId: 10, date: DateTime.utc(2026, 5, 16)),
        PeaksBagged(baggedId: 2, peakId: 6406, gpxId: 11, date: DateTime.utc(2026, 5, 15)),
      ]),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Alpha Loop',
          trackDate: DateTime.utc(2026, 5, 16),
        ),
        GpxTrack(
          gpxTrackId: 11,
          contentHash: 'hash-11',
          trackName: 'Beta Loop',
          trackDate: DateTime.utc(2026, 5, 15),
        ),
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
      peaksBaggedRepository: peaksBaggedRepository,
      gpxTrackRepository: gpxTrackRepository,
      tasmapRepository: tasmapRepository,
    );

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1,234m',
      'My Ascents:',
      'Alpha Loop (16 May 2026)',
      'Beta Loop (15 May 2026)',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
    ]);

    await r.dropMarkerFromPeakPopup();

    final state = ProviderScope.containerOf(
      tester.element(r.peakInfoPopup),
    ).read(mapProvider);
    expect(state.selectedLocation, isNotNull);
    expect(state.selectedLocation!.latitude, closeTo(-43.0, 0.000001));
    expect(state.selectedLocation!.longitude, closeTo(147.0, 0.000001));
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1,234m',
      'My Ascents:',
      'Alpha Loop (16 May 2026)',
      'Beta Loop (15 May 2026)',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
    ]);
  });
}
