import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../../harness/test_peak_list_file_picker.dart';
import 'peak_lists_robot.dart';

void main() {
  testWidgets('peak lists journey creates a list and adds peaks', (
    tester,
  ) async {
    final robot = PeakListsRobot(tester);
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage(),
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

    await robot.openCreateDialog();
    expect(robot.createDialog, findsOneWidget);

    await robot.enterCreateName('  Journey List  ');
    await robot.submitCreate();
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

    final savedItems = decodePeakListItems(
      peakListRepository.getAllPeakLists().single.peakList,
    ).map((item) => (item.peakOsmId, item.points)).toList();
    expect(savedItems, [(100, 3), (200, 5), (300, 7)]);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Journey List');
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

    expect(find.text('Peak List Created'), findsOneWidget);
    expect(find.text('1 Peaks imported'), findsOneWidget);
    expect(find.text('0 peaks skipped'), findsOneWidget);
    expect(find.textContaining('warnings. See import.log'), findsOneWidget);

    final createdId = peakListRepository.getAllPeakLists().single.peakListId;

    await robot.closeResultDialog();

    expect(
      tester.widget<Text>(robot.selectedTitle).data,
      'Journey List',
    );

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

    expect(find.text('Peak List Updated'), findsOneWidget);
    expect(peakListRepository.getAllPeakLists().single.peakListId, createdId);

    await robot.closeResultDialog();

    final peakListRows = adminRowsByEntity['PeakList']!;
    expect(peakListRows, hasLength(1));
    expect(peakListRows.single.values['name'], 'Journey List');
    expect(peakListRows.single.values['peakList'], contains('peakOsmId'));
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

    expect(robot.addSelectedRow(100), findsOneWidget);

    await robot.enterAddPeakPoints(300, '7');
    await robot.enterAddPeakPoints(100, '3');
    await robot.enterAddPeakPoints(200, '5');

    await robot.submitAddPeakDialog();

    final savedItems = decodePeakListItems(
      peakListRepository.getAllPeakLists().single.peakList,
    ).map((item) => (item.peakOsmId, item.points)).toList();
    expect(savedItems, [(100, 3), (200, 5), (300, 7)]);
    expect(tester.widget<Text>(robot.selectedTitle).data, 'Tasmania');
    expect(find.byKey(const Key('peak-lists-details-row-100')), findsOneWidget);
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
