import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/objectbox_admin_repository.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

import '../../harness/test_peak_list_file_picker.dart';
import 'peak_lists_robot.dart';

void main() {
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
      );
    }

    await robot.pumpApp(
      filePicker: TestPeakListFilePicker(selectedFilePath: '/tmp/peaks.csv'),
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
