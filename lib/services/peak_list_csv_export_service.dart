import 'dart:io';

import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_repository.dart';

class PeakListCsvExportResult {
  const PeakListCsvExportResult({
    required this.outputDirectoryPath,
    required this.exportedFileCount,
    this.skippedRowCount = 0,
    this.skippedMalformedListCount = 0,
    this.skippedBlankNameListCount = 0,
    this.skippedZeroResolvedRowListCount = 0,
    this.warningEntries = const [],
  });

  final String outputDirectoryPath;
  final int exportedFileCount;
  final int skippedRowCount;
  final int skippedMalformedListCount;
  final int skippedBlankNameListCount;
  final int skippedZeroResolvedRowListCount;
  final List<String> warningEntries;

  int get skippedListCount =>
      skippedMalformedListCount +
      skippedBlankNameListCount +
      skippedZeroResolvedRowListCount;
}

class PeakListCsvExportException implements Exception {
  const PeakListCsvExportException(this.message);

  final String message;

  @override
  String toString() => message;
}

typedef PeakListCsvExportProgressCallback =
    void Function(PeakListCsvExportProgress progress);

class PeakListCsvExportProgress {
  const PeakListCsvExportProgress({
    required this.completedFileCount,
    required this.totalFileCount,
    required this.currentFileName,
    required this.currentFileWrittenRowCount,
    required this.currentFileTotalRowCount,
  });

  final int completedFileCount;
  final int totalFileCount;
  final String currentFileName;
  final int currentFileWrittenRowCount;
  final int currentFileTotalRowCount;

  double? get currentFilePercent {
    if (currentFileTotalRowCount <= 0) {
      return null;
    }
    return currentFileWrittenRowCount / currentFileTotalRowCount;
  }
}

typedef PeakListCsvOutputDirectoryResolver = Directory Function();

abstract class PeakListCsvFileWriter {
  Future<void> write(String path, String contents);
}

class IoPeakListCsvFileWriter implements PeakListCsvFileWriter {
  const IoPeakListCsvFileWriter();

  @override
  Future<void> write(String path, String contents) {
    return File(path).writeAsString(contents);
  }
}

class PeakListCsvExportService {
  PeakListCsvExportService({
    required this._peakListRepository,
    required this._peakRepository,
    PeakListCsvOutputDirectoryResolver? outputDirectoryResolver,
    PeakListCsvFileWriter? fileWriter,
  }) : _outputDirectoryResolver =
           outputDirectoryResolver ?? _defaultOutputDirectoryResolver,
       _fileWriter = fileWriter ?? const IoPeakListCsvFileWriter();

  static const List<String> csvHeaders = [
    'name',
    'altName',
    'elevation',
    'prominence',
    'rating',
    'difficulty',
    'duration',
    'viaFerrata',
    'gridZoneDesignator',
    'mgrs100kId',
    'easting',
    'northing',
    'points',
    'osmId',
    'peakbaggerPid',
    'country',
    'region',
    'county',
    'range',
    'notes',
    'verified',
    'sourceOfTruth',
  ];

  final PeakListRepository _peakListRepository;
  final PeakRepository _peakRepository;
  final PeakListCsvOutputDirectoryResolver _outputDirectoryResolver;
  final PeakListCsvFileWriter _fileWriter;

  Future<PeakListCsvExportResult> exportPeakLists({
    PeakListCsvExportProgressCallback? onProgress,
  }) async {
    final outputDirectory = _outputDirectoryResolver();
    if (!outputDirectory.existsSync()) {
      throw PeakListCsvExportException(
        'Peak_Lists directory does not exist at ${outputDirectory.path}. '
        'Create the folder and retry.',
      );
    }

    final peakLists = List<PeakList>.from(_peakListRepository.getAllPeakLists())
      ..sort((left, right) {
        final nameComparison = left.name.toLowerCase().compareTo(
          right.name.toLowerCase(),
        );
        return nameComparison != 0
            ? nameComparison
            : left.peakListId.compareTo(right.peakListId);
      });

    final preparedPeakLists = _preparePeakLists(peakLists);
    final totalFileCount = preparedPeakLists.length;
    var exportedFileCount = 0;
    var skippedRowCount = 0;
    var skippedMalformedListCount = 0;
    var skippedBlankNameListCount = 0;
    var skippedZeroResolvedRowListCount = 0;
    final warningEntries = <String>[];
    var completedFileCount = 0;

    void reportProgress({
      required String currentFileName,
      required int currentFileWrittenRowCount,
      required int currentFileTotalRowCount,
    }) {
      onProgress?.call(
        PeakListCsvExportProgress(
          completedFileCount: completedFileCount,
          totalFileCount: totalFileCount,
          currentFileName: currentFileName,
          currentFileWrittenRowCount: currentFileWrittenRowCount,
          currentFileTotalRowCount: currentFileTotalRowCount,
        ),
      );
    }

    for (final preparedPeakList in preparedPeakLists) {
      final peakList = preparedPeakList.peakList;
      final fileName = preparedPeakList.fileName;
      final currentFileName = fileName ?? peakList.name;
      reportProgress(
        currentFileName: currentFileName,
        currentFileWrittenRowCount: 0,
        currentFileTotalRowCount: 0,
      );
      if (fileName == null) {
        skippedBlankNameListCount += 1;
        warningEntries.add(
          'Peak list ${peakList.peakListId} (${peakList.name}): blank normalized filename stem',
        );
        completedFileCount += 1;
        reportProgress(
          currentFileName: currentFileName,
          currentFileWrittenRowCount: 0,
          currentFileTotalRowCount: 0,
        );
        continue;
      }

      late final List<PeakListItem> items;
      try {
        items = decodePeakListItems(peakList.peakList);
      } catch (_) {
        skippedMalformedListCount += 1;
        warningEntries.add(
          'Peak list ${peakList.peakListId} (${peakList.name}): malformed peakList payload',
        );
        completedFileCount += 1;
        reportProgress(
          currentFileName: currentFileName,
          currentFileWrittenRowCount: 0,
          currentFileTotalRowCount: 0,
        );
        continue;
      }

      final rows = <List<dynamic>>[csvHeaders];
      final totalRowCount = items.length;
      var writtenRowCount = 0;
      reportProgress(
        currentFileName: currentFileName,
        currentFileWrittenRowCount: 0,
        currentFileTotalRowCount: totalRowCount,
      );
      for (final item in items) {
        final peak = _peakRepository.findByOsmId(item.peakOsmId);
        if (peak == null) {
          skippedRowCount += 1;
          warningEntries.add(
            'Peak list ${peakList.peakListId} (${peakList.name}): missing peak osmId ${item.peakOsmId}',
          );
          reportProgress(
            currentFileName: currentFileName,
            currentFileWrittenRowCount: writtenRowCount,
            currentFileTotalRowCount: totalRowCount,
          );
          continue;
        }

        final mgrs = _resolveMgrsComponents(peak);
        rows.add([
          peak.name,
          peak.altName,
          _formatOptionalNumber(peak.elevation),
          _formatOptionalNumber(peak.prominence),
          _formatOptionalRating(peak.rating),
          peak.difficulty,
          _formatDuration(peak),
          peak.viaFerrata,
          mgrs.gridZoneDesignator,
          mgrs.mgrs100kId,
          mgrs.easting,
          mgrs.northing,
          item.points,
          peak.osmId,
          peak.peakbaggerPid?.toString() ?? '',
          peak.country,
          peak.region ?? '',
          peak.county,
          peak.range,
          peak.notes,
          peak.verified.toString(),
          peak.sourceOfTruth,
        ]);
        writtenRowCount += 1;
        reportProgress(
          currentFileName: currentFileName,
          currentFileWrittenRowCount: writtenRowCount,
          currentFileTotalRowCount: totalRowCount,
        );
      }

      if (rows.length == 1 && items.isNotEmpty) {
        skippedZeroResolvedRowListCount += 1;
        warningEntries.add(
          'Peak list ${peakList.peakListId} (${peakList.name}): zero resolved peak rows',
        );
        completedFileCount += 1;
        reportProgress(
          currentFileName: currentFileName,
          currentFileWrittenRowCount: writtenRowCount,
          currentFileTotalRowCount: totalRowCount,
        );
        continue;
      }

      final csvText = const CsvEncoder(lineDelimiter: '\n').convert(rows);
      final outputPath = p.join(outputDirectory.path, fileName);
      try {
        await _fileWriter.write(outputPath, csvText);
      } catch (error) {
        throw PeakListCsvExportException(
          'Could not write CSV file at $outputPath: $error',
        );
      }
      exportedFileCount += 1;
      completedFileCount += 1;
      reportProgress(
        currentFileName: currentFileName,
        currentFileWrittenRowCount: writtenRowCount,
        currentFileTotalRowCount: totalRowCount,
      );
    }

    return PeakListCsvExportResult(
      outputDirectoryPath: outputDirectory.path,
      exportedFileCount: exportedFileCount,
      skippedRowCount: skippedRowCount,
      skippedMalformedListCount: skippedMalformedListCount,
      skippedBlankNameListCount: skippedBlankNameListCount,
      skippedZeroResolvedRowListCount: skippedZeroResolvedRowListCount,
      warningEntries: List<String>.unmodifiable(warningEntries),
    );
  }

  static Directory _defaultOutputDirectoryResolver() {
    return Directory(p.join(resolveBushwalkingRoot(), 'Peak_Lists'));
  }

  String _normalizeFileStem(String value) {
    var stem = value.trim().replaceAll(RegExp(r'\s+'), '-').toLowerCase();
    stem = stem.replaceAll(RegExp(r'[/:\\]'), '-');
    stem = stem.replaceFirst(RegExp(r'^\.+'), '');
    stem = stem.replaceFirst(RegExp(r'\.+$'), '');
    return stem;
  }

  List<_PreparedPeakListExport> _preparePeakLists(List<PeakList> peakLists) {
    final collisionCounts = <String, int>{};
    final prepared = <_PreparedPeakListExport>[];
    for (final peakList in peakLists) {
      final normalizedStem = _normalizeFileStem(peakList.name);
      if (normalizedStem.isEmpty) {
        prepared.add(
          _PreparedPeakListExport(peakList: peakList, fileName: null),
        );
        continue;
      }

      final collisionIndex = (collisionCounts[normalizedStem] ?? 0) + 1;
      collisionCounts[normalizedStem] = collisionIndex;
      final resolvedStem = collisionIndex == 1
          ? normalizedStem
          : '$normalizedStem-$collisionIndex';
      prepared.add(
        _PreparedPeakListExport(
          peakList: peakList,
          fileName: '$resolvedStem-peak-list.csv',
        ),
      );
    }

    return prepared;
  }

  PeakMgrsComponents _resolveMgrsComponents(Peak peak) {
    final storedForward =
        '${peak.gridZoneDesignator.trim().toUpperCase()}'
        '${peak.mgrs100kId.trim().toUpperCase()}'
        '${peak.easting.trim()}'
        '${peak.northing.trim()}';
    try {
      return PeakMgrsConverter.fromForwardString(storedForward);
    } on FormatException {
      return PeakMgrsConverter.fromLatLng(
        LatLng(peak.latitude, peak.longitude),
      );
    }
  }

  String _formatDuration(Peak peak) {
    if (peak.durationLabel.trim().isNotEmpty) {
      return peak.durationLabel;
    }

    return formatPeakDurationMinutes(peak.durationMinutes);
  }

  String _formatOptionalNumber(double? value) {
    return value?.toString() ?? '';
  }

  String _formatOptionalRating(double? rating) {
    return rating == null ? '' : rating.toStringAsFixed(1);
  }
}

class _PreparedPeakListExport {
  const _PreparedPeakListExport({
    required this.peakList,
    required this.fileName,
  });

  final PeakList peakList;
  final String? fileName;
}
