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
    this.skippedMalformedListCount = 0,
    this.skippedBlankNameListCount = 0,
    this.skippedZeroResolvedRowListCount = 0,
  });

  final String outputDirectoryPath;
  final int exportedFileCount;
  final int skippedMalformedListCount;
  final int skippedBlankNameListCount;
  final int skippedZeroResolvedRowListCount;

  int get skippedListCount =>
      skippedMalformedListCount +
      skippedBlankNameListCount +
      skippedZeroResolvedRowListCount;
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
      throw StateError(
        'Export directory does not exist: ${outputDirectory.path}',
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

    var exportedFileCount = 0;
    for (final peakList in peakLists) {
      final items = decodePeakListItems(peakList.peakList);
      final rows = <List<dynamic>>[_headers];
      for (final item in items) {
        final peak = _peakRepository.findByOsmId(item.peakOsmId);
        if (peak == null) {
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
        continue;
      }

      final csvText = const ListToCsvConverter(eol: '\n').convert(rows);
      final outputPath = p.join(
        outputDirectory.path,
        '${_normalizeFileStem(peakList.name)}-peak-list.csv',
      );
      await _fileWriter.write(outputPath, csvText);
      exportedFileCount += 1;
    }

    return PeakListCsvExportResult(
      outputDirectoryPath: outputDirectory.path,
      exportedFileCount: exportedFileCount,
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
}
