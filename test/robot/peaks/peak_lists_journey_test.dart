import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../../harness/test_peak_list_file_picker.dart';
import 'peak_lists_robot.dart';

void main() {
  testWidgets('peak lists journey adds peaks to an existing list', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Journey List', peakList: '[]')..peakListId = 1,
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          osmId: 300,
          name: 'Zulu Peak',
          elevation: 1350,
          latitude: -41.0,
          longitude: 146.0,
        ),
        _buildPeak(
          osmId: 100,
          name: 'Alpha Peak',
          elevation: 1250,
          latitude: -41.1,
          longitude: 146.1,
        ),
        _buildPeak(
          osmId: 200,
          name: 'Mike Peak',
          elevation: 1300,
          latitude: -41.2,
          longitude: 146.2,
        ),
      ]),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
    );

    expect(tester.widget<Text>(robot.selectedTitle).data, 'Journey List');

    await robot.openAddPeakDialog();
    await tester.pumpAndSettle();

    expect(robot.addPeakDialog, findsOneWidget);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Journey List');

    await robot.toggleAddPeak(300);
    await robot.toggleAddPeak(100);
    await robot.toggleAddPeak(200);
    await robot.enterAddPeakPoints(300, '7');
    await robot.enterAddPeakPoints(100, '3');
    await robot.enterAddPeakPoints(200, '5');
    await robot.submitAddPeakDialog();

    final journeyList = peakListRepository.findByName('Journey List')!;
    expect(
      decodePeakListItems(
        journeyList.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(100, 3), (200, 5), (300, 7)],
    );
    expect(peakListRepository.findByName('Tassy Full'), isNull);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Journey List');
  });

  testWidgets('peak lists journey preserves selection on cluster expand', (
    tester,
  ) async {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});

    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Journey List',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 100, points: 3),
            const PeakListItem(peakOsmId: 200, points: 5),
          ]),
        )..peakListId = 1,
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          osmId: 100,
          name: 'Alpha Peak',
          elevation: 1250,
          latitude: -42.0,
          longitude: 146.0,
        ),
        _buildPeak(
          osmId: 200,
          name: 'Beta Peak',
          elevation: 1300,
          latitude: -42.00005,
          longitude: 146.00005,
        ),
      ]),
    );

    await robot.pumpJourneyApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
    );

    tester
        .widget<InkWell>(
          find
              .descendant(
                of: find.byKey(const Key('peak-lists-details-row-100')),
                matching: find.byType(InkWell),
              )
              .first,
        )
        .onTap!();
    await tester.pumpAndSettle();

    expect(robot.selectedPeakCircle, findsOneWidget);

    await robot.tapMiniMapCluster(0);

    expect(robot.selectedPeakCircle, findsOneWidget);
  });

  testWidgets(
    'peak lists desktop journey replays interactive mini-map history and resets on list change',
    (tester) async {
      SharedPreferences.resetStatic();
      SharedPreferences.setMockInitialValues({});

      final robot = PeakListsRobot(tester);
      final peakListRepository = PeakListRepository.test(
        InMemoryPeakListStorage([
          PeakList(
            name: 'Tas Peaks',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 100, points: 3),
              const PeakListItem(peakOsmId: 200, points: 5),
            ]),
          )..peakListId = 1,
          PeakList(
            name: 'Alps Peaks',
            peakList: encodePeakListItems([
              const PeakListItem(peakOsmId: 300, points: 8),
            ]),
          )..peakListId = 2,
        ]),
      );
      final peakRepository = PeakRepository.test(
        InMemoryPeakStorage([
          _buildPeak(
            osmId: 100,
            name: 'Alpha Peak',
            elevation: 1250,
            latitude: -42.0,
            longitude: 146.0,
          ),
          _buildPeak(
            osmId: 200,
            name: 'Beta Peak',
            elevation: 1300,
            latitude: -42.1,
            longitude: 146.1,
          ),
          _buildPeak(
            osmId: 300,
            name: 'Monte Journey',
            elevation: 2400,
            latitude: 46.2,
            longitude: 13.0,
          ),
        ]),
      );

      await robot.pumpJourneyApp(
        filePicker: TestPeakListFilePicker(),
        repository: peakListRepository,
        peakRepository: peakRepository,
        surfaceSize: const Size(1600, 900),
      );

      final initialState = robot.miniMapDebugState();

      await robot.zoomMiniMapWithTrackpad(verticalDelta: 120);
      final firstZoomState = robot.miniMapDebugState();
      expect(firstZoomState.zoom, greaterThan(initialState.zoom));

      await robot.zoomMiniMapWithTrackpad(verticalDelta: 120);
      final secondZoomState = robot.miniMapDebugState();
      expect(secondZoomState.zoom, greaterThan(firstZoomState.zoom));
      expect(secondZoomState.center.longitude, firstZoomState.center.longitude);

      await robot.zoomMiniMapWithTrackpad(verticalDelta: 120);
      final thirdZoomState = robot.miniMapDebugState();
      expect(thirdZoomState.zoom, greaterThan(secondZoomState.zoom));
      expect(thirdZoomState.canGoPrevious, isTrue);
      expect(thirdZoomState.canGoNext, isFalse);

      await robot.replayMiniMapHistoryBack();
      final rewoundState = robot.miniMapDebugState();
      expect(rewoundState.zoom, secondZoomState.zoom);
      expect(rewoundState.center.longitude, secondZoomState.center.longitude);
      expect(rewoundState.canGoPrevious, isTrue);
      expect(rewoundState.canGoNext, isTrue);

      await robot.replayMiniMapHistoryForward();
      final replayedState = robot.miniMapDebugState();
      expect(replayedState.zoom, thirdZoomState.zoom);
      expect(replayedState.center.longitude, thirdZoomState.center.longitude);
      expect(replayedState.canGoPrevious, isTrue);
      expect(replayedState.canGoNext, isFalse);

      await robot.replayMiniMapHistoryBack();
      await robot.zoomMiniMapWithTrackpad(verticalDelta: -120);
      final branchedState = robot.miniMapDebugState();
      expect(branchedState.zoom, lessThan(rewoundState.zoom));
      expect(branchedState.center.longitude, rewoundState.center.longitude);
      expect(branchedState.canGoNext, isFalse);

      await robot.replayMiniMapHistoryForward();
      final noForwardState = robot.miniMapDebugState();
      expect(noForwardState.zoom, branchedState.zoom);
      expect(noForwardState.center.longitude, branchedState.center.longitude);
      expect(noForwardState.canGoNext, isFalse);

      await robot.selectPeakListRow(1);
      final resetState = robot.miniMapDebugState();
      expect(tester.widget<Text>(robot.selectedTitle).data, 'Tas Peaks');
      expect(resetState.canGoPrevious, isFalse);
      expect(resetState.canGoNext, isFalse);
      expect(resetState.center.latitude, lessThan(-40));
      expect(resetState.center.longitude, greaterThan(100));
    },
  );

  testWidgets('peak lists journey refreshes selected title after rename', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Abels', peakList: '[]')..peakListId = 1,
      ]),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
    );

    expect(tester.widget<Text>(robot.selectedTitle).data, 'Abels');

    await peakListRepository.save(
      PeakList(peakListId: 1, name: 'Abels Renamed', peakList: '[]'),
    );
    ProviderScope.containerOf(
      tester.element(robot.summaryPane),
    ).read(peakListRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(robot.selectedTitle).data, 'Abels Renamed');
    expect(
      find.descendant(
        of: find.byKey(const Key('peak-lists-row-1')),
        matching: find.text('Abels Renamed'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('peak lists journey keeps negative peak ids climbed', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(
          name: 'Tas Peaks',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: -1, points: 4),
          ]),
        )..peakListId = 1,
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          osmId: -1,
          name: 'Tinderbox Hill',
          elevation: 300,
          latitude: -42.0,
          longitude: 146.0,
        ),
      ]),
    );
    final peaksBaggedRepository = PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
      peaksBaggedRepository: peaksBaggedRepository,
    );

    await peaksBaggedRepository.rebuildFromTracks([
      GpxTrack(
          gpxTrackId: 10,
          contentHash: 'hash-10',
          trackName: 'Track 10',
          trackDate: DateTime.utc(2026, 5, 15),
        )
        ..peaks.add(
          _buildPeak(
            osmId: -1,
            name: 'Tinderbox Hill',
            elevation: 300,
            latitude: -42.0,
            longitude: 146.0,
          ),
        ),
    ]);
    ProviderScope.containerOf(
      tester.element(find.byKey(const Key('peak-lists-summary-pane'))),
    ).read(peaksBaggedRevisionProvider.notifier).increment();
    await tester.pumpAndSettle();

    expect(
      tester.widget<Text>(find.byKey(const Key('peak-lists-climbed-1'))).data,
      '1',
    );
    expect(find.byKey(const Key('peak-lists-details-row--1')), findsOneWidget);
    expect(find.text('Tinderbox Hill'), findsWidgets);
  });

  testWidgets('peak lists journey creates and updates via dialog flow', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);

    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount Achilles',
      elevation: 1363,
      latitude: -41.85916,
      longitude: 145.97754,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage(),
      peakRepository: peakRepository,
    );
    final adminRowsByEntity = <String, List<ObjectBoxAdminRow>>{
      'Peak': const [],
      'PeakList': const [],
      'Tasmap50k': const [],
      'GpxTrack': const [],
    };
    final importService = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: peakListRepository,
      csvLoader: (_) async =>
          'Name,Height,Zone,Easting,Northing,Latitude,Longitude,Points\nWrong Name,1363,55G,4 15 135,53 65 355,-41.85916,145.97754,3\n',
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
      clock: () => DateTime.utc(2024, 1, 2, 3, 4, 5),
    );
    Future<PeakListImportPresentationResult> importRunner({
      required String listName,
      required String csvPath,
    }) async {
      final result = await importService.importPeakList(
        listName: listName,
        csvPath: csvPath,
      );
      await peakListRepository.refreshTassyFullPeakList();
      ProviderScope.containerOf(
        tester.element(robot.summaryPane),
      ).read(peakListRevisionProvider.notifier).increment();
      adminRowsByEntity['PeakList'] = peakListRepository
          .getAllPeakLists()
          .map(peakListToAdminRow)
          .toList(growable: false);
      return PeakListImportPresentationResult(
        updated: result.updated,
        importedCount: result.importedCount,
        skippedCount: result.skippedCount,
        warningCount: result.warningEntries.length,
        warningMessage: result.warningMessage,
        peakListId: result.peakListId,
        listName: listName,
      );
    }

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/peaks.csv'),
      repository: peakListRepository,
      peakRepository: peakRepository,
      duplicateNameChecker: (name) async {
        return peakListRepository.findByName(name) != null;
      },
      importRunner: importRunner,
    );

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('Journey List');
    await robot.submitImport();
    await tester.pumpAndSettle();

    expect(robot.importDialog, findsNothing);

    final createdId = peakListRepository.findByName('Journey List')!.peakListId;

    expect(tester.widget<Text>(robot.selectedTitle).data, 'Journey List');

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('Journey List');
    await robot.submitImport();

    expect(
      find.text(
        'This list already exists - do you want to update the existing list?',
      ),
      findsOneWidget,
    );

    await tester.tap(robot.updateConfirm);
    await tester.pumpAndSettle();

    expect(robot.importDialog, findsNothing);
    expect(
      peakListRepository.findByName('Journey List')!.peakListId,
      createdId,
    );
    expect(peakListRepository.findByName('Tassy Full'), isNotNull);

    final peakListRows = adminRowsByEntity['PeakList']!;
    expect(peakListRows, hasLength(2));
    expect(
      peakListRows.map((row) => row.values['name']),
      containsAll(['Journey List', 'Tassy Full']),
    );
    expect(
      peakListRows
          .firstWhere((row) => row.values['name'] == 'Journey List')
          .values['peakList'],
      contains('peakOsmId'),
    );
  });

  testWidgets('peak lists journey imports a ranked csv through the dialog', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peak = _buildPeak(
      osmId: 101,
      name: 'Monte Old',
      elevation: 900,
      latitude: 46.2001,
      longitude: 13.1001,
    ).copyWith(sourceOfTruth: Peak.sourceOfTruthHwc, region: 'italy-nord-est');
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage(),
    );
    final importService = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: peakListRepository,
      csvLoader: (_) async =>
          'name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes\n'
          'Monte Amariana,101,4.35,1906,544,46.4084,13.0475,Italy,Friuli Venezia Giulia,Carnic Alps,Udine,EE,Optional,Ridge scramble\n',
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
    );

    Future<PeakListImportPresentationResult> importRunner({
      required String listName,
      required String csvPath,
    }) async {
      final result = await importService.importPeakList(
        listName: listName,
        csvPath: csvPath,
      );
      await peakListRepository.refreshTassyFullPeakList();
      ProviderScope.containerOf(
        tester.element(robot.summaryPane),
      ).read(peakListRevisionProvider.notifier).increment();
      return PeakListImportPresentationResult(
        updated: result.updated,
        importedCount: result.importedCount,
        skippedCount: result.skippedCount,
        warningCount: result.warningEntries.length,
        warningMessage: result.warningMessage,
        peakListId: result.peakListId,
        listName: listName,
      );
    }

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/ranked.csv'),
      repository: peakListRepository,
      peakRepository: peakRepository,
      importRunner: importRunner,
      duplicateNameChecker: (name) async => false,
    );

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('FVG Ranked');
    await robot.submitImport();
    await tester.pumpAndSettle();

    expect(robot.importDialog, findsNothing);

    expect(tester.widget<Text>(robot.selectedTitle).data, 'FVG Ranked');
    expect(
      peakRepository.findByOsmId(101)?.sourceOfTruth,
      Peak.sourceOfTruthFvg,
    );
    expect(peakRepository.findByOsmId(101)?.region, 'fvg');
    expect(
      peakListRepository.findByName('FVG Ranked')?.region,
      'italy-nord-est',
    );
    expect(
      peakListRepository.findByName('FVG Ranked')?.peakList,
      encodePeakListItems([const PeakListItem(peakOsmId: 101, points: 1)]),
    );
  });

  testWidgets('peak lists journey imports an app-owned export csv', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final existingPeak = _buildPeak(
      osmId: 101,
      name: 'Old Peak',
      elevation: 1200,
      latitude: -41.85916,
      longitude: 145.97754,
    ).copyWith(sourceOfTruth: Peak.sourceOfTruthOsm);
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([existingPeak]),
    );
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage(),
    );
    final importService = PeakListImportService(
      peakRepository: peakRepository,
      peakListRepository: peakListRepository,
      csvLoader: (_) async => _appOwnedCsv([
        _appOwnedCsvRowForPeak(
          existingPeak.copyWith(
            name: 'Imported Peak',
            altName: 'Imported Alt',
            elevation: 1363,
            country: 'Australia',
            county: 'Central Highlands',
            range: 'Du Cane',
            region: 'tasmania',
            sourceOfTruth: Peak.sourceOfTruthHwc,
          ),
          points: 3,
        ),
        _appOwnedCsvRowForPeak(
          _buildPeak(
            osmId: 202,
            name: 'Created Peak',
            elevation: 1400,
            latitude: -41.9000,
            longitude: 145.9500,
          ).copyWith(
            country: 'Australia',
            county: 'Kentish',
            range: 'Great Western Tiers',
            region: 'tasmania',
            sourceOfTruth: Peak.sourceOfTruthPeakBagger,
          ),
          points: 7,
        ),
      ]),
      importRootLoader: () async => '/tmp/Bushwalking',
      logWriter: (logPath, entries) async {},
    );

    Future<PeakListImportPresentationResult> importRunner({
      required String listName,
      required String csvPath,
    }) async {
      final result = await importService.importPeakList(
        listName: listName,
        csvPath: csvPath,
      );
      await peakListRepository.refreshTassyFullPeakList();
      ProviderScope.containerOf(
        tester.element(robot.summaryPane),
      ).read(peakListRevisionProvider.notifier).increment();
      return PeakListImportPresentationResult(
        updated: result.updated,
        importedCount: result.importedCount,
        skippedCount: result.skippedCount,
        warningCount: result.warningEntries.length,
        warningMessage: result.warningMessage,
        peakListId: result.peakListId,
        listName: listName,
      );
    }

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/export.csv'),
      repository: peakListRepository,
      peakRepository: peakRepository,
      importRunner: importRunner,
      duplicateNameChecker: (name) async => false,
    );

    await robot.openImportDialog();
    await robot.chooseFile();
    await robot.enterName('Round Trip Journey');
    await robot.submitImport();
    await tester.pumpAndSettle();

    expect(robot.importDialog, findsNothing);

    expect(tester.widget<Text>(robot.selectedTitle).data, 'Round Trip Journey');
    expect(peakRepository.findByOsmId(101)?.name, 'Imported Peak');
    expect(peakRepository.findByOsmId(202)?.name, 'Created Peak');
    expect(
      peakListRepository.findByName('Round Trip Journey')?.peakList,
      encodePeakListItems([
        const PeakListItem(peakOsmId: 101, points: 3),
        const PeakListItem(peakOsmId: 202, points: 7),
      ]),
    );
  });

  testWidgets('peak lists journey selects and deletes targeted row', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final repository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Abels', peakList: '[]')..peakListId = 1,
        PeakList(name: 'Connoisseurs', peakList: '[]')..peakListId = 2,
      ]),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: repository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-2'))).onTap!();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Connoisseurs');

    await robot.deleteRow(2);
    await tester.tap(robot.deleteConfirm);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('peak-lists-row-2')), findsNothing);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Abels');
  });

  testWidgets('peak lists journey adds multiple peaks alphabetically', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([
        PeakList(name: 'Tasmania', peakList: '[]')..peakListId = 1,
      ]),
    );
    final peakRepository = PeakRepository.test(
      InMemoryPeakStorage([
        _buildPeak(
          osmId: 300,
          name: 'Zulu Peak',
          elevation: 1350,
          latitude: -41.0,
          longitude: 146.0,
        ),
        _buildPeak(
          osmId: 100,
          name: 'Alpha Peak',
          elevation: 1250,
          latitude: -41.1,
          longitude: 146.1,
        ),
        _buildPeak(
          osmId: 200,
          name: 'Mike Peak',
          elevation: 1300,
          latitude: -41.2,
          longitude: 146.2,
        ),
      ]),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    await robot.openAddPeakDialog();
    expect(robot.addPeakDialog, findsOneWidget);

    await robot.toggleAddPeak(300);
    await robot.toggleAddPeak(100);
    await robot.toggleAddPeak(200);

    expect(robot.addRow(100), findsOneWidget);
    expect(tester.widget<Checkbox>(robot.addCheckbox(100)).value, isTrue);
    expect(robot.addSelectedRow(100), findsOneWidget);

    await robot.enterAddPeakPoints(300, '7');
    await robot.enterAddPeakPoints(100, '3');
    await robot.enterAddPeakPoints(200, '5');

    await robot.submitAddPeakDialog();

    final tasmania = peakListRepository.findByName('Tasmania')!;
    expect(
      decodePeakListItems(
        tasmania.peakList,
      ).map((item) => (item.peakOsmId, item.points)).toList(),
      [(100, 3), (200, 5), (300, 7)],
    );
    expect(peakListRepository.findByName('Tassy Full'), isNull);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Tasmania');
    expect(find.byKey(const Key('peak-lists-details-row-100')), findsOneWidget);
  });

  testWidgets('peak lists journey shows all memberships in peak dialog', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peak = _buildPeak(
      osmId: 101,
      name: 'Mount Achilles',
      elevation: 1363,
      latitude: -41.85916,
      longitude: 145.97754,
    );
    final peakRepository = PeakRepository.test(InMemoryPeakStorage([peak]));
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
            const PeakListItem(peakOsmId: 101, points: 6),
          ]),
        )..peakListId = 2,
      ]),
    );

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(),
      repository: peakListRepository,
      peakRepository: peakRepository,
    );

    tester.widget<InkWell>(find.byKey(const Key('peak-lists-row-1'))).onTap!();
    await tester.pumpAndSettle();

    await robot.openPeakDialog(101);

    expect(robot.addPeakDialog, findsOneWidget);
    expect(tester.widget<Text>(robot.peakMemberships).data, 'Alpha, Zeta');
  });
}

Peak _buildPeak({
  required int osmId,
  required String name,
  required double elevation,
  required double latitude,
  required double longitude,
}) {
  final mgrs = PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
  return Peak(
    osmId: osmId,
    name: name,
    elevation: elevation,
    latitude: latitude,
    longitude: longitude,
    gridZoneDesignator: mgrs.gridZoneDesignator,
    mgrs100kId: mgrs.mgrs100kId,
    easting: mgrs.easting,
    northing: mgrs.northing,
  );
}

String _appOwnedCsv(List<Map<String, String>> rows) {
  final lines = [
    PeakListCsvExportService.csvHeaders.join(','),
    for (final row in rows)
      PeakListCsvExportService.csvHeaders
          .map((header) => _csvCell(row[header] ?? ''))
          .join(','),
  ];
  return '${lines.join('\n')}\n';
}

Map<String, String> _appOwnedCsvRowForPeak(Peak peak, {required int points}) {
  return {
    'name': peak.name,
    'altName': peak.altName,
    'elevation': peak.elevation?.toString() ?? '',
    'gridZoneDesignator': peak.gridZoneDesignator,
    'mgrs100kId': peak.mgrs100kId,
    'easting': peak.easting,
    'northing': peak.northing,
    'Points': '$points',
    'osmId': '${peak.osmId}',
    'country': peak.country,
    'region': peak.region ?? '',
    'county': peak.county,
    'range': peak.range,
    'sourceOfTruth': peak.sourceOfTruth,
  };
}

String _csvCell(String value) {
  if (!value.contains(',') && !value.contains('"') && !value.contains('\n')) {
    return value;
  }
  final escaped = value.replaceAll('"', '""');
  return '"$escaped"';
}
