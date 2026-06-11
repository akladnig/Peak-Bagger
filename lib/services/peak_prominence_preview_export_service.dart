import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/peak_source.dart';

class PeakProminencePreviewExportResult {
  const PeakProminencePreviewExportResult({
    required this.path,
    required this.exportedCount,
    required this.csvContents,
  });

  final String path;
  final int exportedCount;
  final String csvContents;
}

abstract class PeakProminencePreviewFileWriter {
  Future<void> write(String path, String contents);
}

class IoPeakProminencePreviewFileWriter
    implements PeakProminencePreviewFileWriter {
  const IoPeakProminencePreviewFileWriter();

  @override
  Future<void> write(String path, String contents) {
    return File(path).writeAsString(contents);
  }
}

class PeakProminencePreviewExportService {
  PeakProminencePreviewExportService({
    required PeakSource peakSource,
    Directory? outputDirectory,
    PeakProminencePreviewFileWriter? fileWriter,
  }) : _peakSource = peakSource,
       _outputDirectory = outputDirectory ??
           Directory(p.join(Directory.current.path, 'tool')),
       _fileWriter = fileWriter ?? const IoPeakProminencePreviewFileWriter();

  static const String fileName = 'peak-prominence-objectbox-preview.csv';

  final PeakSource _peakSource;
  final Directory _outputDirectory;
  final PeakProminencePreviewFileWriter _fileWriter;

  Future<PeakProminencePreviewExportResult> exportPreview({
    required Map<int, double?> prominenceByPeakId,
  }) async {
    await _outputDirectory.create(recursive: true);

    final peaks = List<Peak>.from(_peakSource.getAllPeaks())
      ..sort((left, right) => left.id.compareTo(right.id));
    final rows = <List<dynamic>>[
      ['id', 'region', 'name', 'latitude', 'longitude', 'elevation', 'prominence'],
      ...peaks.map(
        (peak) => [
          peak.id,
          peak.region ?? '',
          peak.name,
          peak.latitude,
          peak.longitude,
          peak.elevation?.toString() ?? '',
          prominenceByPeakId.containsKey(peak.id)
              ? prominenceByPeakId[peak.id]?.toString() ?? ''
              : peak.prominence?.toString() ?? '',
        ],
      ),
    ];

    final csvText = const ListToCsvConverter(eol: '\n').convert(rows);
    final outputPath = p.join(_outputDirectory.path, fileName);
    await _fileWriter.write(outputPath, csvText);

    return PeakProminencePreviewExportResult(
      path: outputPath,
      exportedCount: peaks.length,
      csvContents: csvText,
    );
  }
}
