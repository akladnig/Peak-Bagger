import 'package:flutter/material.dart';
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
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/waypoints_repository.dart';

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
    r.expectPeakPopupWithContent('Bonnet Hill');
  });

  testWidgets('peak info journey popup stays open while hovered', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    await r.hoverPeak(6406);
    await r.hoverPopup();

    r.expectPeakPopupWithContent('Bonnet Hill');
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

  testWidgets('peak info journey click pins hovered popup', (tester) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    await r.hoverPeak(6406);
    await r.clickPeak(6406);
    await r.hoverAwayFromPeak();

    final container = ProviderScope.containerOf(
      tester.element(r.mapInteractionRegion),
    );
    expect(container.read(mapProvider).isPeakInfoPinned, isTrue);
    r.expectPeakPopupWithContent('Bonnet Hill');
  });

  testWidgets('peak info journey edit saves popup changes in place', (
    tester,
  ) async {
    final peak = Peak(
      id: 1,
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [peak],
      ),
      peakRepository: peakRepository,
    );

    await r.clickPeak(6406);
    await r.startEditingPeakPopup();
    await r.enterPeakName('Bonnet Hill Summit');
    await r.enterPeakElevation('1234');
    await r.savePeakPopupEdit();

    r.expectPeakPopupWithLines([
      'Bonnet Hill Summit',
      'Height: 1234 m',
      'Region: Tasmanian',
    ]);
    expect(r.container().read(mapProvider).isPeakInfoPinned, isTrue);

    final saved = peakRepository.findById(1)!;
    expect(saved.name, 'Bonnet Hill Summit');
    expect(saved.elevation, 1234);
    expect(saved.sourceOfTruth, Peak.sourceOfTruthHwc);
    expect(saved.verified, isTrue);
  });

  testWidgets('peak info journey move to marker updates popup draft', (
    tester,
  ) async {
    final markerLocation = const LatLng(-42.9995, 147.0005);
    final waypointsRepository = WaypointsRepository.test(
      InMemoryWaypointsStorage(),
    );
    await waypointsRepository.saveMarker(
      location: markerLocation,
      name: 'Saved',
    );
    final marker = waypointsRepository.getCurrentMarker()!;
    final expected = PeakMgrsConverter.fromLatLng(
      LatLng(marker.latitude, marker.longitude),
    );
    final peak = Peak(
      id: 1,
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: [peak],
      ),
      peakRepository: peakRepository,
      waypointsRepository: waypointsRepository,
    );

    await r.clickPeak(6406);
    await r.startEditingPeakPopup();
    await r.movePeakToMarker();
    await r.savePeakPopupEdit();

    expect(r.peakInfoPopup, findsOneWidget);
    expect(find.text('Bonnet Hill'), findsOneWidget);
    expect(find.text('Height: —'), findsOneWidget);
    expect(
      find.text(
        'MGRS: ${expected.gridZoneDesignator} ${expected.mgrs100kId} ${expected.easting} ${expected.northing}',
      ),
      findsOneWidget,
    );
  });

  testWidgets('peak info journey hover away closes transient popup', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    await r.hoverPeak(6406);
    await r.hoverAwayFromPeak();

    r.expectNoPeakPopup();
  });

  testWidgets('peak info journey shows seeded MGRS and singular list', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peaks = [
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
    ];
    final peakListRepository = await _peakListRepository(
      peaks: peaks,
      definitions: [
        (
          peakList: PeakList(peakListId: 1, name: ' Abels '),
          items: const [PeakListItem(peakOsmId: 6406, points: 1)],
        ),
      ],
    );
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: peaks,
      ),
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
    );

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1234 m',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
      'List: Abels',
    ]);
  });

  testWidgets('peak info journey shows seeded MGRS and plural lists', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create();
    final peaks = [
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
    ];
    final peakListRepository = await _peakListRepository(
      peaks: peaks,
      definitions: [
        (
          peakList: PeakList(peakListId: 1, name: 'HWC  '),
          items: const [PeakListItem(peakOsmId: 6406, points: 1)],
        ),
        (
          peakList: PeakList(peakListId: 2, name: 'Abels  '),
          items: const [PeakListItem(peakOsmId: 6406, points: 2)],
        ),
      ],
    );
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(
      initialState: MapState(
        center: const LatLng(-43.0, 147.0),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peaks: peaks,
      ),
      peakListRepository: peakListRepository,
      tasmapRepository: tasmapRepository,
    );

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: 1234 m',
      'Map: Adamsons',
      'MGRS: 55G DM 80000 95000',
      'Lists: Abels, HWC',
    ]);
  });

  testWidgets('peak info journey falls back to region without sheet coverage', (
    tester,
  ) async {
    final tasmapRepository = await TestTasmapRepository.create(maps: []);
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap(tasmapRepository: tasmapRepository);

    await r.clickPeak(6406);
    r.expectPeakPopupWithLines([
      'Bonnet Hill',
      'Height: —',
      'Region: Tasmanian',
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
      expect(find.byKey(const Key('map-tap-action-popup')), findsOneWidget);
      expect(
        ProviderScope.containerOf(
          tester.element(r.mapInteractionRegion),
        ).read(mapProvider).selectedLocation,
        isNull,
      );
    },
  );

  testWidgets(
    'peak info journey drop marker closes popup and updates selection',
    (tester) async {
      final tasmapRepository = await TestTasmapRepository.create();
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage(),
      );
      final peaksBaggedRepository = PeaksBaggedRepository.test(
        InMemoryPeaksBaggedStorage([
          PeaksBagged(
            baggedId: 1,
            peakId: 6406,
            gpxId: 10,
            date: DateTime.utc(2026, 5, 16),
          ),
          PeaksBagged(
            baggedId: 2,
            peakId: 6406,
            gpxId: 11,
            date: DateTime.utc(2026, 5, 15),
          ),
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
        'Height: 1234 m',
        'My Ascents:',
        'Alpha Loop (16 May 2026)',
        'Beta Loop (15 May 2026)',
        'Map: Adamsons',
        'MGRS: 55G DM 80000 95000',
      ]);

      await r.dropMarkerFromPeakPopup();

      final state = ProviderScope.containerOf(
        tester.element(r.mapInteractionRegion),
      ).read(mapProvider);
      expect(state.selectedLocation, isNotNull);
      expect(state.selectedLocation!.latitude, closeTo(-43.0, 0.000001));
      expect(state.selectedLocation!.longitude, closeTo(147.0, 0.000001));
      r.expectNoPeakPopup();
    },
  );
}

Future<PeakListRepository> _peakListRepository({
  required List<Peak> peaks,
  required List<({PeakList peakList, List<PeakListItem> items})> definitions,
}) async {
  final peakRepository = PeakRepository.test(InMemoryPeakStorage(peaks));
  final repository = PeakListRepository.test(
    InMemoryPeakListStorage(),
    peakRepository: peakRepository,
  );
  for (final definition in definitions) {
    await repository.save(definition.peakList, items: definition.items);
  }
  return repository;
}
