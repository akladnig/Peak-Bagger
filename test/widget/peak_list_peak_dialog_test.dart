import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/models/peaks_bagged.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';
import 'package:peak_bagger/widgets/peak_list_peak_dialog.dart';

import '../harness/test_tasmap_repository.dart';
import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('view mode shows metadata and history', (tester) async {
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: 1234,
    );
    final tasmapRepository = await TestTasmapRepository.create(
      maps: [
        Tasmap50k(
          series: 'TS01',
          name: 'Resolved Map',
          parentSeries: 'P1',
          mgrs100kIds: 'AB',
          eastingMin: 12000,
          eastingMax: 13000,
          northingMin: 54000,
          northingMax: 55000,
          mgrsMid: 'AB',
          eastingMid: 12500,
          northingMid: 54500,
        ),
      ],
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Zeta',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 4),
          ]),
        )..peakListId = 1,
        PeakList(
          name: 'Alpha',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 7),
          ]),
        )..peakListId = 2,
      ]),
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: peakListRepository,
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: [
          PeaksBagged(
            baggedId: 1,
            peakId: 101,
            gpxId: 10,
            date: DateTime.utc(2024, 3, 2),
          ),
        ],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: tasmapRepository,
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          GpxTrack(gpxTrackId: 10, contentHash: 'abc', trackName: 'Ridge Walk'),
        ]),
      ),
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
        ),
      ),
    );

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsOneWidget);
    expect(find.text('Mount View'), findsWidgets);
    expect(
      find.byKey(const Key('peak-list-peak-memberships')),
      findsOneWidget,
    );
    expect(
      tester.widget<Text>(
        find.byKey(const Key('peak-list-peak-memberships')),
      ).data,
      'Alpha, Zeta',
    );
    expect(
      find.text('55G AB 12345 54321 (-41.00000, 146.00000)'),
      findsOneWidget,
    );
    expect(find.byKey(const Key('peak-list-peak-map-link')), findsOneWidget);
    expect(find.text('Resolved Map'), findsOneWidget);
    expect(find.byKey(const Key('peak-list-peak-track-10')), findsOneWidget);
    expect(find.text('Sat, Mar 2 2024'), findsOneWidget);
    expect(find.text('Ridge Walk'), findsOneWidget);

    final titleText = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('peak-list-peak-name')),
        matching: find.byType(Text),
      ),
    );
    expect(
      titleText.style?.fontSize,
      Theme.of(
        tester.element(find.byKey(const Key('peak-list-peak-name'))),
      ).textTheme.titleLarge!.fontSize,
    );

    final titleInkWell = tester.widget<InkWell>(
      find.byKey(const Key('peak-list-peak-name')),
    );
    expect(
      titleInkWell.hoverColor,
      Theme.of(
        tester.element(find.byKey(const Key('peak-list-peak-name'))),
      ).colorScheme.primary.withValues(alpha: 0.08),
    );
  });

  testWidgets('view mode shows a dash for unknown height', (tester) async {
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: null,
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: const [],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == '—' && widget.key == null,
      ),
      findsOneWidget,
    );
  });

  testWidgets('dialog opens bottom-right and can be dragged', (tester) async {
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: 1234,
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: const [],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
        ),
      ),
      settle: false,
    );

    final dialogFinder = find.byKey(const Key('peak-list-peak-dialog'));
    await tester.pump();
    final initialRect = tester.getRect(dialogFinder);
    final screenSize = tester.view.physicalSize / tester.view.devicePixelRatio;

    expect(initialRect.right, closeTo(screenSize.width - 24, 8));
    expect(initialRect.bottom, closeTo(screenSize.height - 24, 8));

     await tester.drag(
       find.byKey(const Key('peak-list-peak-dialog-drag-handle')),
       const Offset(-180, -120),
       warnIfMissed: false,
     );
     await tester.pump();

     expect(find.byKey(const Key('peak-list-peak-dialog-drag-handle')), findsOneWidget);
  });

  testWidgets('tapping map name selects the map for navigation', (
    tester,
  ) async {
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: 1234,
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: const [],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(
        maps: [
          Tasmap50k(
            series: 'TS01',
            name: 'Resolved Map',
            parentSeries: 'P1',
            mgrs100kIds: 'AB',
            eastingMin: 12000,
            eastingMax: 13000,
            northingMin: 54000,
            northingMax: 55000,
            mgrsMid: 'AB',
            eastingMid: 12500,
            northingMid: 54500,
          ),
        ],
      ),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      mapNotifier: mapNotifier,
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-map-link')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
    expect(mapNotifier.state.selectedMap?.name, 'Resolved Map');
    expect(mapNotifier.state.tasmapDisplayMode, TasmapDisplayMode.selectedMap);
  });

  testWidgets('tapping gpx link updates the selected location to the peak', (
    tester,
  ) async {
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: 1234,
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-42.0, 147.0),
      ),
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: [
          PeaksBagged(
            baggedId: 1,
            peakId: 101,
            gpxId: 10,
            date: DateTime.utc(2024, 3, 2),
          ),
        ],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(
        maps: [
          Tasmap50k(
            series: 'TS01',
            name: 'Resolved Map',
            parentSeries: 'P1',
            mgrs100kIds: 'AB',
            eastingMin: 12000,
            eastingMax: 13000,
            northingMin: 54000,
            northingMax: 55000,
            mgrsMid: 'AB',
            eastingMid: 12500,
            northingMid: 54500,
          ),
        ],
      ),
      gpxTrackRepository: GpxTrackRepository.test(
        InMemoryGpxTrackStorage([
          GpxTrack(gpxTrackId: 10, contentHash: 'abc', trackName: 'Ridge Walk'),
        ]),
      ),
      mapNotifier: mapNotifier,
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-track-10')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
    expect(mapNotifier.state.selectedLocation, isNotNull);
    expect(mapNotifier.state.selectedLocation!.latitude, closeTo(-41.0, 0.001));
    expect(
      mapNotifier.state.selectedLocation!.longitude,
      closeTo(146.0, 0.001),
    );
    expect(mapNotifier.state.selectedTrackId, 10);
    expect(mapNotifier.state.showTracks, isTrue);
  });

  testWidgets('tapping a different gpx link updates the peak marker', (
    tester,
  ) async {
    final peakOne = _buildPeak(
      osmId: 101,
      name: 'Mount View',
      latitude: -41.0,
      longitude: 146.0,
    );
    final peakTwo = _buildPeak(
      osmId: 202,
      name: 'Second Peak',
      latitude: -42.5,
      longitude: 147.5,
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 10,
        basemap: Basemap.tracestrack,
      ),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([
        GpxTrack(gpxTrackId: 10, contentHash: 'abc', trackName: 'Ridge Walk'),
        GpxTrack(gpxTrackId: 20, contentHash: 'def', trackName: 'Ridge Walk 2'),
      ]),
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: [
          PeaksBagged(
            baggedId: 1,
            peakId: 101,
            gpxId: 10,
            date: DateTime.utc(2024, 3, 2),
          ),
        ],
        peak: peakOne,
        points: 4,
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([peakOne, peakTwo]),
      ),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: gpxTrackRepository,
      mapNotifier: mapNotifier,
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-track-10')));
    await tester.pumpAndSettle();

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: [const PeakListItem(peakOsmId: 202, points: 4)],
        ascentRows: [
          PeaksBagged(
            baggedId: 2,
            peakId: 202,
            gpxId: 20,
            date: DateTime.utc(2024, 3, 3),
          ),
        ],
        peak: peakTwo,
        points: 4,
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([peakOne, peakTwo]),
      ),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: gpxTrackRepository,
      mapNotifier: mapNotifier,
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-track-20')));
    await tester.pumpAndSettle();

    expect(mapNotifier.state.selectedTrackId, 20);
    expect(mapNotifier.state.selectedLocation, isNotNull);
    expect(mapNotifier.state.selectedLocation!.latitude, closeTo(-42.5, 0.001));
    expect(
      mapNotifier.state.selectedLocation!.longitude,
      closeTo(147.5, 0.001),
    );
    expect(mapNotifier.state.selectedTrackFocusSerial, 2);
  });

  testWidgets('add mode autofocuses and renders inline points', (
    tester,
  ) async {
    final peak = _buildPeak(
      osmId: 202,
      name: 'New Peak',
      latitude: -42.0,
      longitude: 147.0,
      gridZoneDesignator: '55G',
      mgrs100kId: 'AB',
      easting: '12345',
      northing: '54321',
      elevation: 1200,
    );

    await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.add,
        peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
        peakListRepository: PeakListRepository.test(InMemoryPeakListStorage()),
        peakItems: const [],
        ascentRows: const [],
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(
        maps: [
          Tasmap50k(
            series: 'TS01',
            name: 'Resolved Map',
            parentSeries: 'P1',
            mgrs100kIds: 'AB',
            eastingMin: 12000,
            eastingMax: 13000,
            northingMin: 54000,
            northingMax: 55000,
            mgrsMid: 'AB',
            eastingMid: 12500,
            northingMid: 54500,
          ),
        ],
      ),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    expect(tester.testTextInput.hasAnyClients, isTrue);

    await tester.enterText(
      find.byKey(const Key('peak-list-peak-search-input')),
      'New',
    );
    await tester.pump();

    expect(find.byKey(const Key('peak-multi-select-row-202')), findsOneWidget);
    expect(find.byKey(const Key('peak-multi-select-checkbox-202')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-202')));
    await tester.pump();

    expect(find.byKey(const Key('peak-selected-row-202')), findsOneWidget);
    expect(find.byKey(const Key('peak-selected-checkbox-202')), findsOneWidget);
    expect(find.byKey(const Key('peak-selected-points-202')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-selected-row-202')),
        matching: find.text('1200m'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-selected-row-202')),
        matching: find.text('Resolved Map'),
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const Key('peak-selected-points-202')),
          )
          .controller!
          .text,
      '1',
    );
  });

  testWidgets('add mode shows existing peaks as checked and saves new ones', (
    tester,
  ) async {
    final listRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          peakListId: 1,
          name: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 4),
          ]),
        ),
      ]),
    );
    final peakA = _buildPeak(
      osmId: 101,
      name: 'Existing Peak',
      latitude: -41,
      longitude: 146,
    );
    final peakB = _buildPeak(
      osmId: 202,
      name: 'New Peak',
      latitude: -42,
      longitude: 147,
    );

    final completer = await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.add,
        peakList: listRepository.getAllPeakLists().single,
        peakListRepository: listRepository,
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: const [],
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peakA, peakB])),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    await tester.enterText(
      find.byKey(const Key('peak-list-peak-search-input')),
      'Peak',
    );
    await tester.pump();

    expect(find.byKey(const Key('peak-multi-select-row-101')), findsOneWidget);
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('peak-multi-select-checkbox-101'))).value,
      isTrue,
    );
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('peak-multi-select-checkbox-101'))).onChanged,
      isNull,
    );
    expect(find.byKey(const Key('peak-multi-select-row-202')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-202')));
    await tester.pump();

    expect(find.byKey(const Key('peak-selected-row-202')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('peak-selected-points-202')),
      '12',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result?.deleted, isFalse);
    expect(result?.selectedPeakIds, [202]);
    expect(
      decodePeakListItems(
        listRepository.getAllPeakLists().single.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(101, 4), (202, 10)],
    );
  });

  testWidgets('add mode saves multiple peaks in alphabetical order', (
    tester,
  ) async {
    final listRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
      ]),
    );
    final peakZulu = _buildPeak(
      osmId: 300,
      name: 'Zulu Peak',
      latitude: -41,
      longitude: 146,
    );
    final peakAlpha = _buildPeak(
      osmId: 100,
      name: 'Alpha Peak',
      latitude: -41.1,
      longitude: 146.1,
    );
    final peakMike = _buildPeak(
      osmId: 200,
      name: 'Mike Peak',
      latitude: -41.2,
      longitude: 146.2,
    );

    final completer = await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.add,
        peakList: listRepository.getAllPeakLists().single,
        peakListRepository: listRepository,
        peakItems: const [],
        ascentRows: const [],
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([peakZulu, peakAlpha, peakMike]),
      ),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-300')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-100')));
    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-200')));
    await tester.pump();

    expect(find.byKey(const Key('peak-multi-select-row-100')), findsOneWidget);
    expect(
      tester.widget<Checkbox>(find.byKey(const Key('peak-multi-select-checkbox-100'))).value,
      isTrue,
    );
    expect(find.byKey(const Key('peak-selected-row-100')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('peak-selected-points-300')),
      '7',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-100')),
      '3',
    );
    await tester.enterText(
      find.byKey(const Key('peak-selected-points-200')),
      '5',
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result?.selectedPeakIds, [100, 200, 300]);
    expect(
      decodePeakListItems(
        listRepository.getAllPeakLists().single.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(100, 3), (200, 5), (300, 7)],
    );
  });

  testWidgets('add mode splits search and selected panes evenly', (tester) async {
    final listRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
      ]),
    );

    final completer = await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.add,
        peakList: listRepository.getAllPeakLists().single,
        peakListRepository: listRepository,
        peakItems: const [],
        ascentRows: const [],
      ),
      peakRepository: PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(osmId: 300, name: 'Zulu Peak', latitude: -41, longitude: 146),
          _buildPeak(osmId: 100, name: 'Alpha Peak', latitude: -41.1, longitude: 146.1),
          _buildPeak(osmId: 200, name: 'Mike Peak', latitude: -41.2, longitude: 146.2),
        ]),
      ),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    );

    await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-100')));
    await tester.pump();

    final resultsPanelHeight = tester.getSize(
      find.byKey(const Key('peak-list-peak-results-panel')),
    ).height;
    final selectedPanelHeight = tester.getSize(
      find.byKey(const Key('peak-list-peak-selected-panel')),
    ).height;

    expect(resultsPanelHeight, closeTo(selectedPanelHeight, 0.1));
    expect(find.byKey(const Key('peak-selected-row-100')), findsOneWidget);

    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    expect(await completer.future, isNotNull);
  });

  testWidgets('edit mode updates points only', (tester) async {
    final listRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          peakListId: 1,
          name: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 4),
          ]),
        ),
      ]),
    );
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount Edit',
      latitude: -41,
      longitude: 146,
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListId: 1,
      ),
    );

    final completer = await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.edit,
        peakList: listRepository.getAllPeakLists().single,
        peakListRepository: listRepository,
        peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
        ascentRows: const [],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      mapNotifier: mapNotifier,
      peakListRepository: listRepository,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-points')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-peak-save')));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result?.selectedPeakId, 101);
    expect(result?.deleted, isFalse);
    expect(
      decodePeakListItems(
        listRepository.getAllPeakLists().single.peakList,
      ).single.points,
      7,
    );
    expect(container.read(peakListRevisionProvider), 1);
  });

  testWidgets('delete mode removes membership and selects next row', (
    tester,
  ) async {
    final listRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          peakListId: 1,
          name: 'Tasmania',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 101, points: 4),
            const PeakListItem(peakOsmId: 202, points: 5),
          ]),
        ),
      ]),
    );
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount Delete',
      latitude: -41,
      longitude: 146,
    );
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListId: 1,
      ),
    );

    final completer = await _pumpDialog(
      tester,
      dialog: PeakListPeakDialog(
        mode: PeakListPeakDialogMode.view,
        peakList: listRepository.getAllPeakLists().single,
        peakListRepository: listRepository,
        peakItems: const [
          PeakListItem(peakOsmId: 101, points: 4),
          PeakListItem(peakOsmId: 202, points: 5),
        ],
        ascentRows: const [],
        peak: peak,
        points: 4,
      ),
      peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
      tasmapRepository: await TestTasmapRepository.create(),
      gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
      mapNotifier: mapNotifier,
      peakListRepository: listRepository,
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );

    await tester.tap(find.byKey(const Key('peak-list-peak-delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('peak-list-peak-delete-confirm')));
    await tester.pumpAndSettle();

    final result = await completer.future;
    expect(result?.deleted, isTrue);
    expect(result?.selectedPeakId, 202);
    expect(
      decodePeakListItems(
        listRepository.getAllPeakLists().single.peakList,
      ).map((item) => item.peakOsmId).toList(),
      [202],
    );
    expect(container.read(peakListRevisionProvider), 1);
  });

  testWidgets(
    'partial-success multi-add increments revision once when any add succeeds',
    (tester) async {
      final listRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            peakListId: 1,
            name: 'Tasmania',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 101, points: 4),
            ]),
          ),
        ]),
      );
      final existingPeak = _buildPeak(
        osmId: 101,
        name: 'Existing Peak',
        latitude: -41,
        longitude: 146,
      );
      final newPeak = _buildPeak(
        osmId: 202,
        name: 'New Peak',
        latitude: -42,
        longitude: 147,
      );
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15,
          basemap: Basemap.tracestrack,
          peakListSelectionMode: PeakListSelectionMode.specificList,
          selectedPeakListId: 1,
        ),
      );

      await _pumpDialog(
        tester,
        dialog: PeakListPeakDialog(
          mode: PeakListPeakDialogMode.add,
          peakList: listRepository.getAllPeakLists().single,
          peakListRepository: listRepository,
          peakItems: const [],
          ascentRows: const [],
        ),
        peakRepository: PeakRepository.test(
          InMemoryPeakStorage([existingPeak, newPeak]),
        ),
        tasmapRepository: await TestTasmapRepository.create(),
        gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        mapNotifier: mapNotifier,
        peakListRepository: listRepository,
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MaterialApp)),
      );

      await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-101')));
      await tester.tap(find.byKey(const Key('peak-multi-select-checkbox-202')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('peak-list-peak-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Failed to add:'), findsOneWidget);
      expect(container.read(peakListRevisionProvider), 1);
      expect(
        decodePeakListItems(listRepository.getAllPeakLists().single.peakList)
            .map((item) => item.peakOsmId)
            .toList(),
        [101, 202],
      );
    },
  );

  testWidgets(
    'tapping peak name navigates to map centered on peak at zoom 15',
    (tester) async {
      final peak = _buildPeak(
        osmId: 101,
        name: 'Mount View',
        latitude: -41.0,
        longitude: 146.0,
        gridZoneDesignator: '55G',
        mgrs100kId: 'AB',
        easting: '12345',
        northing: '54321',
        elevation: 1234,
      );
      final mapNotifier = TestMapNotifier(
        MapState(
          center: const LatLng(-42.5, 147.5),
          zoom: 10,
          basemap: Basemap.tracestrack,
          selectedPeaks: [
            Peak(
              osmId: 202,
              name: 'Existing Peak',
              latitude: -41.2,
              longitude: 146.2,
            ),
          ],
        ),
      );

      await _pumpDialog(
        tester,
        dialog: PeakListPeakDialog(
          mode: PeakListPeakDialogMode.view,
          peakList: PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
          peakListRepository: PeakListRepository.test(
            InMemoryPeakListStorage(),
          ),
          peakItems: [const PeakListItem(peakOsmId: 101, points: 4)],
          ascentRows: const [],
          peak: peak,
          points: 4,
        ),
        peakRepository: PeakRepository.test(InMemoryPeakStorage([peak])),
        tasmapRepository: await TestTasmapRepository.create(),
        gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        mapNotifier: mapNotifier,
      );

      await tester.tap(find.byKey(const Key('peak-list-peak-name')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('peak-list-peak-dialog')), findsNothing);
      expect(mapNotifier.state.center.latitude, closeTo(-42.5, 0.001));
      expect(mapNotifier.state.center.longitude, closeTo(147.5, 0.001));
      expect(mapNotifier.state.zoom, 10);
      expect(
        mapNotifier.state.cameraRequestCenter,
        const LatLng(-41.0, 146.0),
      );
      expect(mapNotifier.state.cameraRequestZoom, MapConstants.defaultZoom);
      expect(mapNotifier.state.selectedLocation, isNull);
      expect(mapNotifier.state.selectedPeaks.map((peak) => peak.osmId), [202]);
    },
  );
}

Future<Completer<PeakListPeakDialogOutcome?>> _pumpDialog(
  WidgetTester tester, {
  required Widget dialog,
  required PeakRepository peakRepository,
  required TasmapRepository tasmapRepository,
  required GpxTrackRepository gpxTrackRepository,
  TestMapNotifier? mapNotifier,
  PeakListRepository? peakListRepository,
  bool settle = true,
}) async {
  final completer = Completer<PeakListPeakDialogOutcome?>();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              mapNotifier ??
              TestMapNotifier(
                MapState(
                  center: const LatLng(-41.5, 146.5),
                  zoom: 10,
                  basemap: Basemap.tracestrack,
                ),
              ),
        ),
        peakRepositoryProvider.overrideWithValue(peakRepository),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ?? PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showGeneralDialog<PeakListPeakDialogOutcome>(
                context: context,
                barrierDismissible: true,
                barrierLabel: MaterialLocalizations.of(
                  context,
                ).modalBarrierDismissLabel,
                barrierColor: Colors.black54,
                transitionDuration: const Duration(milliseconds: 120),
                pageBuilder: (_, animation, secondaryAnimation) => dialog,
                transitionBuilder:
                    (context, animation, secondaryAnimation, child) {
                      final fadeAnimation = CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      );
                      return FadeTransition(
                        opacity: fadeAnimation,
                        child: child,
                      );
                    },
              ).then(completer.complete);
            });
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  }
  return completer;
}

Peak _buildPeak({
  required int osmId,
  required String name,
  required double latitude,
  required double longitude,
  String gridZoneDesignator = '',
  String mgrs100kId = '',
  String easting = '',
  String northing = '',
  double? elevation,
}) {
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: latitude,
    longitude: longitude,
    gridZoneDesignator: gridZoneDesignator,
    mgrs100kId: mgrs100kId,
    easting: easting,
    northing: northing,
  );
}
