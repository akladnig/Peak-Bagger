import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/data_export_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/data_export_file_picker.dart';
import 'package:peak_bagger/services/data_export_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

import '../harness/test_peak_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('export peaks cancel is a no-op', (tester) async {
    final picker = TestDataExportFilePicker(outputDirectory: '/tmp/export');
    final fileSystem = RecordingDataExportFileSystem();

    await _pumpSettings(
      tester,
      picker: picker,
      fileSystem: fileSystem,
      peaks: [Peak(osmId: 1, name: 'Alpha', latitude: -41, longitude: 145)],
    );

    await _scrollToExportPeaks(tester);
    await tester.tap(find.byKey(const Key('list-export-peaks-tile')));
    await tester.pump();

    expect(find.text('Export Peaks?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('list-export-peaks-cancel')));
    await tester.pump();

    expect(picker.pickCallCount, 0);
    expect(fileSystem.writes, isEmpty);
    expect(find.byKey(const Key('list-export-status')), findsNothing);
  });

  testWidgets('export peaks writes csv and shows success dialog', (
    tester,
  ) async {
    final picker = TestDataExportFilePicker(outputDirectory: '/tmp/export');
    final fileSystem = RecordingDataExportFileSystem();

    await _pumpSettings(
      tester,
      picker: picker,
      fileSystem: fileSystem,
      peaks: [Peak(osmId: 1, name: 'Alpha', latitude: -41, longitude: 145)],
    );

    await _scrollToExportPeaks(tester);
    await tester.tap(find.byKey(const Key('list-export-peaks-tile')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('list-export-peaks-confirm')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();

    expect(picker.pickCallCount, 1);
    expect(fileSystem.writes.keys, contains('/tmp/export/peaks.csv.tmp'));
    expect(fileSystem.replacements, [
      ('/tmp/export/peaks.csv.tmp', '/tmp/export/peaks.csv'),
    ]);
    expect(find.text('Peaks Exported'), findsOneWidget);
    expect(find.text('Exported 1 rows to 1 file.'), findsOneWidget);
    expect(find.byKey(const Key('list-export-result-close')), findsOneWidget);
    expect(
      find.byKey(const Key('list-export-status'), skipOffstage: false),
      findsOneWidget,
    );
  });
}

Future<void> _pumpSettings(
  WidgetTester tester, {
  required TestDataExportFilePicker picker,
  required RecordingDataExportFileSystem fileSystem,
  required List<Peak> peaks,
}) async {
  final tasmapRepository = await TestTasmapRepository.create();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () => TestPeakNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        tasmapStateProvider.overrideWith(
          () => TestTasmapNotifier(tasmapRepository),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage(peaks)),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        dataExportFilePickerProvider.overrideWithValue(picker),
        dataExportFileSystemProvider.overrideWithValue(fileSystem),
        dataExportClockProvider.overrideWithValue(
          () => DateTime.utc(2024, 1, 2, 3, 4, 5),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/settings');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _scrollToExportPeaks(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const Key('list-export-peaks-tile')),
    400,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

class TestDataExportFilePicker implements DataExportFilePicker {
  TestDataExportFilePicker({this.outputDirectory});

  final String? outputDirectory;
  int pickCallCount = 0;

  @override
  Future<String?> pickOutputDirectory() async {
    pickCallCount += 1;
    return outputDirectory;
  }

  @override
  Future<String> resolveDefaultExportRoot() async => '/tmp';
}

class RecordingDataExportFileSystem implements DataExportFileSystem {
  final writes = <String, String>{};
  final replacements = <(String, String)>[];

  @override
  Future<void> appendLog(String path, List<String> entries) async {}

  @override
  Future<void> deleteFileIfExists(String path) async {}

  @override
  Future<bool> directoryExists(String path) async => true;

  @override
  Future<bool> fileExists(String path) async => false;

  @override
  Future<bool> isDirectoryWritable(String path) async => true;

  @override
  Future<void> replaceFile({
    required String tempPath,
    required String targetPath,
  }) async {
    replacements.add((tempPath, targetPath));
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    writes[path] = contents;
  }
}
