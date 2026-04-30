import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
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

import '../../harness/test_peak_notifier.dart';
import '../../harness/test_tasmap_notifier.dart';
import '../../harness/test_tasmap_repository.dart';

class ListExportsRobot {
  ListExportsRobot(this.tester);

  final WidgetTester tester;

  Finder get exportPeakListsTile =>
      find.byKey(const Key('list-export-peak-lists-tile'));
  Finder get exportPeakListsConfirm =>
      find.byKey(const Key('list-export-peak-lists-confirm'));
  Finder get resultClose => find.byKey(const Key('list-export-result-close'));

  Future<void> pumpApp({
    required TestDataExportFilePicker picker,
    required RecordingDataExportFileSystem fileSystem,
    required List<Peak> peaks,
    required List<PeakList> peakLists,
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
            PeakListRepository.test(InMemoryPeakListStorage(peakLists)),
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

  Future<void> exportPeakLists() async {
    await tester.scrollUntilVisible(
      exportPeakListsTile,
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(exportPeakListsTile);
    await tester.pump();
    await tester.tap(exportPeakListsConfirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump();
  }

  void expectSuccess({
    required int rows,
    required int files,
    int warnings = 0,
    String? logPath,
    String? logWarning,
  }) {
    expect(find.text('Peak Lists Exported'), findsOneWidget);
    expect(
      find.text('Exported $rows rows to ${_formatFileCount(files)}.'),
      findsOneWidget,
    );
    if (warnings > 0) {
      expect(find.text('Warnings: $warnings'), findsOneWidget);
    }
    if (logPath != null) {
      expect(find.text('Warnings were written to $logPath.'), findsOneWidget);
    }
    if (logWarning != null) {
      expect(find.text(logWarning), findsOneWidget);
    }
  }

  Future<void> closeResultDialog() async {
    await tester.tap(resultClose);
    await tester.pump();
  }

  String _formatFileCount(int count) => count == 1 ? '1 file' : '$count files';
}

class TestDataExportFilePicker implements DataExportFilePicker {
  TestDataExportFilePicker({required this.outputDirectory});

  final String outputDirectory;
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
  RecordingDataExportFileSystem({this.failAppendLog = false});

  final bool failAppendLog;
  final writes = <String, String>{};
  final replacements = <(String, String)>[];
  final appendedLogs = <String, List<String>>{};

  @override
  Future<void> appendLog(String path, List<String> entries) async {
    if (failAppendLog) {
      throw Exception('log failed');
    }
    appendedLogs[path] = entries;
  }

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
