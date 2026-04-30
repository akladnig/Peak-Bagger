import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

abstract class DataExportService {
  Future<DataExportPlan> preparePeaksExport(String outputDirectory);

  Future<DataExportCommitResult> commitExport(DataExportPlan plan);
}

abstract class DataExportFileSystem {
  Future<bool> directoryExists(String path);

  Future<bool> isDirectoryWritable(String path);

  Future<bool> fileExists(String path);

  Future<void> writeTextFile(String path, String contents);

  Future<void> replaceFile({
    required String tempPath,
    required String targetPath,
  });

  Future<void> deleteFileIfExists(String path);

  Future<void> appendLog(String path, List<String> entries);
}

class DataExportTarget {
  const DataExportTarget({
    required this.fileName,
    required this.path,
    required this.payload,
    required this.rowCount,
  });

  final String fileName;
  final String path;
  final String payload;
  final int rowCount;
}

class DataExportPlan {
  const DataExportPlan({
    required this.outputDirectory,
    required this.targets,
    required this.warningEntries,
    required this.overwriteConflicts,
  });

  final String outputDirectory;
  final List<DataExportTarget> targets;
  final List<String> warningEntries;
  final List<String> overwriteConflicts;

  int get totalRowCount =>
      targets.fold(0, (total, target) => total + target.rowCount);
}

class DataExportCommitResult {
  const DataExportCommitResult({
    required this.exportedFileCount,
    required this.exportedRowCount,
    required this.warningCount,
    this.logPath,
    this.logWarning,
  });

  final int exportedFileCount;
  final int exportedRowCount;
  final int warningCount;
  final String? logPath;
  final String? logWarning;
}

class DefaultDataExportService implements DataExportService {
  DefaultDataExportService({
    required PeakRepository peakRepository,
    required PeakListRepository peakListRepository,
    required DataExportFileSystem fileSystem,
    required DateTime Function() clock,
  }) : _peakRepository = peakRepository,
       _peakListRepository = peakListRepository,
       _fileSystem = fileSystem,
       _clock = clock;

  final PeakRepository _peakRepository;
  // Kept for the phase-2 peak-list slice so the service API stays stable.
  // ignore: unused_field
  final PeakListRepository _peakListRepository;
  final DataExportFileSystem _fileSystem;
  final DateTime Function() _clock;

  @override
  Future<DataExportPlan> preparePeaksExport(String outputDirectory) async {
    await _ensureWritableDirectory(outputDirectory);
    final peaks = List<Peak>.from(_peakRepository.getAllPeaks())
      ..sort(_comparePeaksForExport);
    final targetPath = p.join(outputDirectory, 'peaks.csv');
    final target = DataExportTarget(
      fileName: 'peaks.csv',
      path: targetPath,
      payload: _buildPeaksCsv(peaks),
      rowCount: peaks.length,
    );

    return DataExportPlan(
      outputDirectory: outputDirectory,
      targets: [target],
      warningEntries: const [],
      overwriteConflicts: await _overwriteConflicts([target]),
    );
  }

  @override
  Future<DataExportCommitResult> commitExport(DataExportPlan plan) async {
    for (final target in plan.targets) {
      final tempPath = '${target.path}.tmp';
      await _fileSystem.writeTextFile(tempPath, target.payload);
      await _fileSystem.replaceFile(
        tempPath: tempPath,
        targetPath: target.path,
      );
    }

    return DataExportCommitResult(
      exportedFileCount: plan.targets.length,
      exportedRowCount: plan.totalRowCount,
      warningCount: plan.warningEntries.length,
    );
  }

  Future<void> _ensureWritableDirectory(String outputDirectory) async {
    if (!await _fileSystem.directoryExists(outputDirectory)) {
      throw DataExportException(
        'Selected output folder does not exist: $outputDirectory',
      );
    }
    if (!await _fileSystem.isDirectoryWritable(outputDirectory)) {
      throw DataExportException(
        'Selected output folder is not writable: $outputDirectory',
      );
    }
  }

  Future<List<String>> _overwriteConflicts(
    List<DataExportTarget> targets,
  ) async {
    final conflicts = <String>[];
    for (final target in targets) {
      if (await _fileSystem.fileExists(target.path)) {
        conflicts.add(target.path);
      }
    }
    return List<String>.unmodifiable(conflicts);
  }

  String _buildPeaksCsv(List<Peak> peaks) {
    final rows = <List<Object?>>[
      const [
        'name',
        'elevation',
        'Latitude',
        'longitude',
        'area',
        'gridZoneDesignator',
        'mgrs100kId',
        'easting',
        'northing',
        'osmId',
        'sourceOfTruth',
      ],
      for (final peak in peaks)
        [
          peak.name,
          peak.elevation?.toString() ?? '',
          peak.latitude.toString(),
          peak.longitude.toString(),
          peak.area ?? '',
          peak.gridZoneDesignator,
          peak.mgrs100kId,
          peak.easting,
          peak.northing,
          peak.osmId.toString(),
          peak.sourceOfTruth,
        ],
    ];
    return const ListToCsvConverter(eol: '\n').convert(rows);
  }

  int _comparePeaksForExport(Peak a, Peak b) {
    final nameCompare = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    if (nameCompare != 0) {
      return nameCompare;
    }
    return a.osmId.compareTo(b.osmId);
  }

  // Used by later warning-log slices.
  // ignore: unused_element
  String _timestampedLogEntry(
    String exportType,
    String context,
    String warning,
  ) {
    return '${_clock().toIso8601String()} | $exportType | $context | $warning';
  }
}

class DataExportException implements Exception {
  const DataExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class LocalDataExportFileSystem implements DataExportFileSystem {
  @override
  Future<void> appendLog(String path, List<String> entries) async {
    if (entries.isEmpty) {
      return;
    }
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(
      '${entries.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }

  @override
  Future<void> deleteFileIfExists(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<bool> directoryExists(String path) => Directory(path).exists();

  @override
  Future<bool> fileExists(String path) => File(path).exists();

  @override
  Future<bool> isDirectoryWritable(String path) async {
    final probe = File(p.join(path, '.peak_bagger_export_probe'));
    try {
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> replaceFile({
    required String tempPath,
    required String targetPath,
  }) async {
    final target = File(targetPath);
    if (await target.exists()) {
      await target.delete();
    }
    await File(tempPath).rename(targetPath);
  }

  @override
  Future<void> writeTextFile(String path, String contents) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents, flush: true);
  }
}
