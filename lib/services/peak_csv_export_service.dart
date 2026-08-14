import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_repository.dart';

class PeakCsvExportResult {
  const PeakCsvExportResult({required this.path, required this.exportedCount});

  final String path;
  final int exportedCount;
}

typedef PeakCsvExportProgressCallback =
    void Function(PeakCsvExportProgress progress);

class PeakCsvExportProgress {
  const PeakCsvExportProgress({
    required this.writtenCount,
    required this.totalCount,
    required this.fileName,
  });

  final int writtenCount;
  final int totalCount;
  final String fileName;

  double? get percent {
    if (totalCount <= 0) {
      return null;
    }
    return writtenCount / totalCount;
  }
}

abstract class PeakCsvFileWriter {
  Future<void> write(String path, String contents);
}

class IoPeakCsvFileWriter implements PeakCsvFileWriter {
  const IoPeakCsvFileWriter();

  @override
  Future<void> write(String path, String contents) {
    return File(path).writeAsString(contents);
  }
}

class PeakCsvExportService {
  PeakCsvExportService({
    required this._peakRepository,
    Directory? outputDirectory,
    PeakCsvFileWriter? fileWriter,
  }) : _outputDirectory = outputDirectory ?? Directory(_defaultOutputDirectory),
       _fileWriter = fileWriter ?? const IoPeakCsvFileWriter();

  static const String fileName = 'peaks.csv';
  static const String _defaultOutputDirectory =
      '/Users/adrian/Documents/Bushwalking/Features';
  static const List<String> _headers = [
    'id',
    'osmId',
    'peakbaggerPid',
    'name',
    'altName',
    'elevation',
    'prominence',
    'country',
    'county',
    'range',
    'rating',
    'durationMinutes',
    'durationLabel',
    'difficulty',
    'viaFerrata',
    'notes',
    'latitude',
    'longitude',
    'region',
    'gridZoneDesignator',
    'mgrs100kId',
    'easting',
    'northing',
    'verified',
    'sourceOfTruth',
  ];

  final PeakRepository _peakRepository;
  final Directory _outputDirectory;
  final PeakCsvFileWriter _fileWriter;

  Future<PeakCsvExportResult> exportPeaks({
    PeakCsvExportProgressCallback? onProgress,
  }) async {
    await _outputDirectory.create(recursive: true);

    final peaks = List<Peak>.from(_peakRepository.getAllPeaks());
    final rows = <List<dynamic>>[_headers];
    final outputPath = p.join(_outputDirectory.path, fileName);

    void reportProgress(int writtenCount) {
      onProgress?.call(
        PeakCsvExportProgress(
          writtenCount: writtenCount,
          totalCount: peaks.length,
          fileName: p.basename(outputPath),
        ),
      );
    }

    reportProgress(0);
    for (final peak in peaks) {
      rows.add(_toCsvRow(peak));
      reportProgress(rows.length - 1);
    }

    final csvText = const CsvEncoder(lineDelimiter: '\n').convert(rows);
    await _fileWriter.write(outputPath, csvText);

    return PeakCsvExportResult(path: outputPath, exportedCount: peaks.length);
  }

  List<dynamic> _toCsvRow(Peak peak) {
    return [
      peak.id,
      peak.osmId,
      peak.peakbaggerPid ?? '',
      peak.name,
      peak.altName,
      peak.elevation ?? '',
      peak.prominence ?? '',
      peak.country,
      peak.county,
      peak.range,
      peak.rating ?? '',
      peak.durationMinutes ?? '',
      peak.durationLabel,
      peak.difficulty,
      peak.viaFerrata,
      peak.notes,
      peak.latitude,
      peak.longitude,
      peak.region ?? '',
      peak.gridZoneDesignator,
      peak.mgrs100kId,
      peak.easting,
      peak.northing,
      peak.verified,
      peak.sourceOfTruth,
    ];
  }
}
