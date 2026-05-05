import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/import_path_helpers.dart';
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
    required PeakListRepository peakListRepository,
    required PeakRepository peakRepository,
    PeakListCsvOutputDirectoryResolver? outputDirectoryResolver,
    PeakListCsvFileWriter? fileWriter,
  }) : _peakListRepository = peakListRepository,
       _peakRepository = peakRepository,
       _outputDirectoryResolver =
           outputDirectoryResolver ?? _defaultOutputDirectoryResolver,
       _fileWriter = fileWriter ?? const IoPeakListCsvFileWriter();

  static const List<String> _headers = [
    'Name',
    'Alt Name',
    'Elevation',
    'Zone',
    'mgrs100kId',
    'Easting',
    'Northing',
    'Points',
    'osmId',
  ];

  final PeakListRepository _peakListRepository;
  final PeakRepository _peakRepository;
  final PeakListCsvOutputDirectoryResolver _outputDirectoryResolver;
  final PeakListCsvFileWriter _fileWriter;

  Future<PeakListCsvExportResult> exportPeakLists() async {
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
    var exportedFileCount = 0;
    var skippedRowCount = 0;
    var skippedMalformedListCount = 0;
    var skippedBlankNameListCount = 0;
    var skippedZeroResolvedRowListCount = 0;
    final warningEntries = <String>[];

    for (final preparedPeakList in preparedPeakLists) {
      final peakList = preparedPeakList.peakList;
      final fileName = preparedPeakList.fileName;
      if (fileName == null) {
        skippedBlankNameListCount += 1;
        warningEntries.add(
          'Peak list ${peakList.peakListId} (${peakList.name}): blank normalized filename stem',
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
        continue;
      }

      final rows = <List<dynamic>>[_headers];
      for (final item in items) {
        final peak = _peakRepository.findByOsmId(item.peakOsmId);
        if (peak == null) {
          skippedRowCount += 1;
          warningEntries.add(
            'Peak list ${peakList.peakListId} (${peakList.name}): missing peak osmId ${item.peakOsmId}',
          );
          continue;
        }

        rows.add([
          peak.name,
          peak.altName,
          peak.elevation?.toString() ?? '',
          peak.gridZoneDesignator,
          peak.mgrs100kId,
          peak.easting,
          peak.northing,
          item.points,
          peak.osmId,
        ]);
      }

      if (rows.length == 1 && items.isNotEmpty) {
        skippedZeroResolvedRowListCount += 1;
        warningEntries.add(
          'Peak list ${peakList.peakListId} (${peakList.name}): zero resolved peak rows',
        );
        continue;
      }

      final csvText = const ListToCsvConverter(eol: '\n').convert(rows);
      final outputPath = p.join(outputDirectory.path, fileName);
      try {
        await _fileWriter.write(outputPath, csvText);
      } catch (error) {
        throw PeakListCsvExportException(
          'Could not write CSV file at $outputPath: $error',
        );
      }
      exportedFileCount += 1;
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
}

class _PreparedPeakListExport {
  const _PreparedPeakListExport({
    required this.peakList,
    required this.fileName,
  });

  final PeakList peakList;
  final String? fileName;
}
