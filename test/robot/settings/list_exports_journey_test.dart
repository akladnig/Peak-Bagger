import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';

import 'list_exports_robot.dart';

void main() {
  testWidgets('peak-list export happy path writes csv and shows result', (
    tester,
  ) async {
    final robot = ListExportsRobot(tester);
    final picker = TestDataExportFilePicker(outputDirectory: '/tmp/export');
    final fileSystem = RecordingDataExportFileSystem();

    await robot.pumpApp(
      picker: picker,
      fileSystem: fileSystem,
      peaks: [Peak(osmId: 1, name: 'Alpha', latitude: -41, longitude: 145)],
      peakLists: [
        PeakList(
          peakListId: 1,
          name: 'Walking List',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 1, points: 5),
          ]),
        ),
      ],
    );

    await robot.exportPeakLists();

    expect(picker.pickCallCount, 1);
    expect(
      fileSystem.writes.keys,
      contains('/tmp/export/walking-list-peak-list.csv.tmp'),
    );
    expect(fileSystem.replacements, [
      (
        '/tmp/export/walking-list-peak-list.csv.tmp',
        '/tmp/export/walking-list-peak-list.csv',
      ),
    ]);
    robot.expectSuccess(rows: 1, files: 1);
    await robot.closeResultDialog();
  });

  testWidgets('peak-list export warning path reports log failure', (
    tester,
  ) async {
    final robot = ListExportsRobot(tester);
    final picker = TestDataExportFilePicker(outputDirectory: '/tmp/export');
    final fileSystem = RecordingDataExportFileSystem(failAppendLog: true);

    await robot.pumpApp(
      picker: picker,
      fileSystem: fileSystem,
      peaks: [Peak(osmId: 1, name: 'Alpha', latitude: -41, longitude: 145)],
      peakLists: [
        PeakList(
          peakListId: 1,
          name: 'Warning List',
          peakList: encodePeakListItems([
            const PeakListItem(peakOsmId: 1, points: 5),
            const PeakListItem(peakOsmId: 99, points: 1),
          ]),
        ),
      ],
    );

    await robot.exportPeakLists();

    robot.expectSuccess(
      rows: 1,
      files: 1,
      warnings: 1,
      logWarning: 'Could not update export.log.',
    );
    await robot.closeResultDialog();
  });
}
