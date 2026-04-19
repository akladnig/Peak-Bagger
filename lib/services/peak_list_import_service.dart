import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/peak_list_file_picker.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peak_mgrs_converter.dart';
import 'package:peak_bagger/services/peak_repository.dart';

typedef PeakListCsvLoader = Future<String> Function(String csvPath);
typedef PeakListImportRootLoader = Future<String> Function();
typedef PeakListLogWriter =
    Future<void> Function(String logPath, List<String> entries);

class PeakListImportResult {
  const PeakListImportResult({
    required this.peakListId,
    required this.updated,
    required this.importedCount,
    required this.skippedCount,
    required this.matchedCount,
    required this.ambiguousCount,
    required this.warningEntries,
    required this.logEntries,
    this.warningMessage,
  });

  final int peakListId;
  final bool updated;
  final int importedCount;
  final int skippedCount;
  final int matchedCount;
  final int ambiguousCount;
  final List<String> warningEntries;
  final List<String> logEntries;
  final String? warningMessage;
}

class PeakListImportService {
  PeakListImportService({
    required PeakRepository peakRepository,
    required PeakListRepository peakListRepository,
    PeakListCsvLoader? csvLoader,
    PeakListImportRootLoader? importRootLoader,
    PeakListLogWriter? logWriter,
    DateTime Function()? clock,
  }) : _peakRepository = peakRepository,
       _peakListRepository = peakListRepository,
       _csvLoader = csvLoader ?? _loadCsvFromDisk,
       _importRootLoader =
           importRootLoader ?? PlatformPeakListFilePicker().resolveImportRoot,
       _logWriter = logWriter ?? _appendLogEntries,
       _clock = clock ?? DateTime.now;

  final PeakRepository _peakRepository;
  final PeakListRepository _peakListRepository;
  final PeakListCsvLoader _csvLoader;
  final PeakListImportRootLoader _importRootLoader;
  final PeakListLogWriter _logWriter;
  final DateTime Function() _clock;

  Future<PeakListImportResult> importPeakList({
    required String listName,
    required String csvPath,
  }) async {
    final trimmedListName = listName.trim();
    if (trimmedListName.isEmpty) {
      throw const FormatException('A list name is required.');
    }

    final existing = _peakListRepository.findByName(trimmedListName);
    final rows = _parseCsv(await _csvLoader(csvPath));
    final peaks = List<Peak>.from(_peakRepository.getAllPeaks());
    final items = <PeakListItem>[];
    final correctedPeaksByOsmId = <int, Peak>{};
    final warningEntries = <String>[];
    final logEntries = <String>[];
    var ambiguousCount = 0;
    var skippedCount = 0;
    var nextSyntheticOsmId = _peakRepository.nextSyntheticOsmId(peaks);

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) {
        continue;
      }

      final parseResult = _parseRow(rows.first, row, rowIndex + 1);
      if (parseResult.error != null) {
        skippedCount += 1;
        warningEntries.add(parseResult.error!);
        logEntries.add(_timestampedLogEntry(csvPath, parseResult.error!));
        continue;
      }

      final csvRow = parseResult.row!;
      final resolution = _resolveMatch(csvRow, peaks);
      if (resolution.match == null) {
        if (!resolution.hadSpatialCandidates) {
          final createdPeak = await _peakRepository.save(
            _createPeakFromCsv(csvRow, nextSyntheticOsmId),
          );
          nextSyntheticOsmId = createdPeak.osmId - 1;
          peaks.add(createdPeak);
          items.add(
            PeakListItem(peakOsmId: createdPeak.osmId, points: csvRow.points),
          );
          continue;
        }

        final warning = resolution.hadSpatialCandidates
            ? 'Row ${csvRow.rowNumber}: no confident name-confirmed match found for ${csvRow.name}'
            : 'Row ${csvRow.rowNumber}: no matching peak found for ${csvRow.name}';
        if (resolution.wasAmbiguous) {
          ambiguousCount += 1;
        }
        skippedCount += 1;
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
        continue;
      }

      final match = resolution.match!;
      final peak = match.peak;
      final coordinateWarning = _coordinateDriftWarning(csvRow, match);
      if (coordinateWarning != null) {
        warningEntries.add(coordinateWarning);
        logEntries.add(_timestampedLogEntry(csvPath, coordinateWarning));
      }
      final heightWarning = _heightCorrectionWarning(csvRow, peak);
      if (heightWarning != null) {
        warningEntries.add(heightWarning);
        logEntries.add(_timestampedLogEntry(csvPath, heightWarning));
      }
      final correctedPeak = _correctPeakFromCsv(csvRow, peak);
      if (_peakNeedsSave(peak, correctedPeak)) {
        correctedPeaksByOsmId[peak.osmId] = correctedPeak;
      }
      if (_normalizeName(csvRow.name) != _normalizeName(peak.name)) {
        final warning =
            'Row ${csvRow.rowNumber}: imported ${csvRow.name} as ${peak.name}';
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
      }

      items.add(PeakListItem(peakOsmId: peak.osmId, points: csvRow.points));
    }

    for (final correctedPeak in correctedPeaksByOsmId.values) {
      await _peakRepository.save(correctedPeak);
    }

    final saved = await _peakListRepository.save(
      PeakList(name: trimmedListName, peakList: encodePeakListItems(items)),
    );

    String? warningMessage;
    if (logEntries.isNotEmpty) {
      try {
        final importRoot = await _importRootLoader();
        await _logWriter(
          GpxImporter.resolveImportLogPath(importRoot),
          logEntries,
        );
      } catch (_) {
        warningEntries.add('Could not update import.log.');
        warningMessage = 'Could not update import.log.';
      }
    }

    return PeakListImportResult(
      peakListId: saved.peakListId,
      updated: existing != null,
      importedCount: items.length,
      skippedCount: skippedCount,
      matchedCount: items.length,
      ambiguousCount: ambiguousCount,
      warningEntries: List<String>.unmodifiable(warningEntries),
      logEntries: List<String>.unmodifiable(logEntries),
      warningMessage: warningMessage,
    );
  }

  List<List<dynamic>> _parseCsv(String contents) {
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(contents);
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    final headers = rows.first
        .map((value) => _normalizeHeader('$value'))
        .toList();
    _requireHeaders(headers, const [
      'Name',
      'Height',
      'Zone',
      'Easting',
      'Northing',
      'Latitude',
      'Longitude',
      'Points',
    ]);

    rows[0] = headers;
    return rows;
  }

  _PeakListCsvRowParseResult _parseRow(
    List<dynamic> headers,
    List<dynamic> row,
    int rowNumber,
  ) {
    try {
      final data = <String, String>{};
      for (var index = 0; index < headers.length; index++) {
        data[headers[index] as String] = index < row.length
            ? '${row[index]}'
            : '';
      }

      final zone = data['Zone']!.trim().toUpperCase();
      final mgrs = PeakMgrsConverter.fromCsvUtm(
        zone: zone,
        easting: data['Easting']!,
        northing: data['Northing']!,
      );
      return _PeakListCsvRowParseResult(
        row: _PeakListCsvRow(
          rowNumber: rowNumber,
          name: data['Name']!.trim(),
          height: double.parse(_preferHeightValue(data)).round(),
          zone: zone,
          mgrs100kId: mgrs.mgrs100kId,
          easting: int.parse(mgrs.easting),
          northing: int.parse(mgrs.northing),
          latitude: double.parse(data['Latitude']!.trim()),
          longitude: double.parse(data['Longitude']!.trim()),
          points: data['Points']!.trim(),
        ),
      );
    } catch (_) {
      return _PeakListCsvRowParseResult(
        error: 'Row $rowNumber: invalid peak-list data',
      );
    }
  }

  _PeakMatchResolution _resolveMatch(_PeakListCsvRow row, List<Peak> peaks) {
    var hadSpatialCandidates = false;
    var wasAmbiguous = false;

    for (final thresholdMeters in _candidateThresholdsMeters) {
      final candidates = _findSpatialMatchesWithinThreshold(
        row,
        peaks,
        thresholdMeters,
      );
      if (candidates.isEmpty) {
        continue;
      }

      hadSpatialCandidates = true;
      if (candidates.length > 1) {
        wasAmbiguous = true;
      }

      final nameConfirmed = candidates
          .where((candidate) {
            return _hasStrongNameConfirmation(row.name, candidate.peak.name);
          })
          .toList(growable: false);

      if (thresholdMeters <= 50 && candidates.length == 1) {
        return _PeakMatchResolution(
          match: candidates.single,
          hadSpatialCandidates: true,
          wasAmbiguous: wasAmbiguous,
        );
      }

      if (nameConfirmed.length == 1) {
        return _PeakMatchResolution(
          match: nameConfirmed.single,
          hadSpatialCandidates: true,
          wasAmbiguous: wasAmbiguous,
        );
      }
    }

    return _PeakMatchResolution(
      hadSpatialCandidates: hadSpatialCandidates,
      wasAmbiguous: wasAmbiguous,
    );
  }

  List<_PeakMatch> _findSpatialMatchesWithinThreshold(
    _PeakListCsvRow row,
    List<Peak> peaks,
    int thresholdMeters,
  ) {
    return peaks
        .where((peak) {
          if (peak.gridZoneDesignator.toUpperCase() != row.zone) {
            return false;
          }
          if (peak.mgrs100kId.toUpperCase() != row.mgrs100kId) {
            return false;
          }

          return haversineDistance(
                row.latitude,
                row.longitude,
                peak.latitude,
                peak.longitude,
              ) <=
              thresholdMeters;
        })
        .map((peak) {
          final peakEasting = int.tryParse(peak.easting);
          final peakNorthing = int.tryParse(peak.northing);
          if (peakEasting == null || peakNorthing == null) {
            return null;
          }

          final eastingDifference = (peakEasting - row.easting).abs();
          final northingDifference = (peakNorthing - row.northing).abs();
          if (eastingDifference > thresholdMeters ||
              northingDifference > thresholdMeters) {
            return null;
          }

          return _PeakMatch(
            peak: peak,
            eastingDifference: eastingDifference,
            northingDifference: northingDifference,
          );
        })
        .whereType<_PeakMatch>()
        .toList(growable: false);
  }

  bool _hasStrongNameConfirmation(String csvName, String peakName) {
    final normalizedCsvName = _normalizeName(csvName);
    final normalizedPeakName = _normalizeName(peakName);
    if (normalizedCsvName.isEmpty || normalizedPeakName.isEmpty) {
      return false;
    }
    if (normalizedCsvName == normalizedPeakName) {
      return true;
    }

    final distance = _levenshteinDistance(
      normalizedCsvName,
      normalizedPeakName,
    );
    final maxLength = math.max(
      normalizedCsvName.length,
      normalizedPeakName.length,
    );
    return maxLength >= 6 && distance <= 2;
  }

  String? _coordinateDriftWarning(_PeakListCsvRow row, _PeakMatch match) {
    if (match.eastingDifference <= 50 && match.northingDifference <= 50) {
      return null;
    }

    return 'Row ${row.rowNumber}: coordinate drift for ${row.name} '
        '(easting ${match.eastingDifference}m, northing ${match.northingDifference}m)';
  }

  String? _heightCorrectionWarning(_PeakListCsvRow row, Peak peak) {
    final existingHeight = peak.elevation?.round();
    if (existingHeight == row.height) {
      return null;
    }

    final existingLabel = existingHeight == null
        ? 'unknown'
        : '${existingHeight}m';
    return 'Row ${row.rowNumber}: updated height for ${row.name} '
        'from $existingLabel to ${row.height}m';
  }

  Peak _correctPeakFromCsv(_PeakListCsvRow row, Peak peak) {
    return peak.copyWith(
      latitude: row.latitude,
      longitude: row.longitude,
      elevation: row.height.toDouble(),
      easting: row.easting.toString().padLeft(5, '0'),
      northing: row.northing.toString().padLeft(5, '0'),
      sourceOfTruth: Peak.sourceOfTruthHwc,
    );
  }

  Peak _createPeakFromCsv(_PeakListCsvRow row, int syntheticOsmId) {
    return Peak(
      osmId: syntheticOsmId,
      name: row.name,
      elevation: row.height.toDouble(),
      latitude: row.latitude,
      longitude: row.longitude,
      gridZoneDesignator: row.zone,
      mgrs100kId: row.mgrs100kId,
      easting: row.easting.toString().padLeft(5, '0'),
      northing: row.northing.toString().padLeft(5, '0'),
      sourceOfTruth: Peak.sourceOfTruthHwc,
    );
  }

  bool _peakNeedsSave(Peak original, Peak corrected) {
    return original.latitude != corrected.latitude ||
        original.longitude != corrected.longitude ||
        original.elevation != corrected.elevation ||
        original.easting != corrected.easting ||
        original.northing != corrected.northing ||
        original.sourceOfTruth != corrected.sourceOfTruth;
  }

  bool _isRowBlank(List<dynamic> row) {
    return row.every((value) => '$value'.trim().isEmpty);
  }

  String _normalizeHeader(String header) {
    final trimmed = header.replaceFirst('\u{FEFF}', '').trim();
    if (trimmed == 'Ht') {
      return 'Height';
    }
    return trimmed;
  }

  void _requireHeaders(List<dynamic> headers, List<String> requiredHeaders) {
    for (final header in requiredHeaders) {
      if (!headers.contains(header)) {
        throw FormatException('CSV is missing required column: $header');
      }
    }
  }

  String _preferHeightValue(Map<String, String> data) {
    return data['Height']?.trim() ?? data['Ht']?.trim() ?? '';
  }

  String _normalizeName(String value) {
    var normalized = value.trim().toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'\bmt\b'), 'mount');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
    final tokens =
        normalized
            .split(RegExp(r'\s+'))
            .where((token) => token.isNotEmpty && token != 'the')
            .toList(growable: false)
          ..sort();
    return tokens.join(' ');
  }

  int _levenshteinDistance(String source, String target) {
    if (source.isEmpty) {
      return target.length;
    }
    if (target.isEmpty) {
      return source.length;
    }

    final previous = List<int>.generate(target.length + 1, (index) => index);
    final current = List<int>.filled(target.length + 1, 0);

    for (var i = 0; i < source.length; i++) {
      current[0] = i + 1;
      for (var j = 0; j < target.length; j++) {
        final cost = source[i] == target[j] ? 0 : 1;
        current[j + 1] = math.min(
          math.min(current[j] + 1, previous[j + 1] + 1),
          previous[j] + cost,
        );
      }

      for (var j = 0; j < current.length; j++) {
        previous[j] = current[j];
      }
    }

    return previous.last;
  }

  String _timestampedLogEntry(String csvPath, String warning) {
    return '${_clock().toIso8601String()} | $csvPath | $warning';
  }

  static Future<String> _loadCsvFromDisk(String csvPath) async {
    final file = File(csvPath);
    if (!await file.exists()) {
      throw FormatException('Selected file does not exist: $csvPath');
    }

    return utf8.decode(await file.readAsBytes());
  }

  static Future<void> _appendLogEntries(
    String logPath,
    List<String> entries,
  ) async {
    if (entries.isEmpty) {
      return;
    }

    final logFile = File(logPath);
    await logFile.parent.create(recursive: true);
    await logFile.writeAsString(
      '${entries.join('\n')}\n',
      mode: FileMode.append,
      flush: true,
    );
  }
}

class _PeakListCsvRow {
  const _PeakListCsvRow({
    required this.rowNumber,
    required this.name,
    required this.height,
    required this.zone,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    required this.latitude,
    required this.longitude,
    required this.points,
  });

  final int rowNumber;
  final String name;
  final int height;
  final String zone;
  final String mgrs100kId;
  final int easting;
  final int northing;
  final double latitude;
  final double longitude;
  final String points;
}

class _PeakListCsvRowParseResult {
  const _PeakListCsvRowParseResult({this.row, this.error});

  final _PeakListCsvRow? row;
  final String? error;
}

class _PeakMatch {
  const _PeakMatch({
    required this.peak,
    required this.eastingDifference,
    required this.northingDifference,
  });

  final Peak peak;
  final int eastingDifference;
  final int northingDifference;
}

class _PeakMatchResolution {
  const _PeakMatchResolution({
    this.match,
    required this.hadSpatialCandidates,
    required this.wasAmbiguous,
  });

  final _PeakMatch? match;
  final bool hadSpatialCandidates;
  final bool wasAmbiguous;
}

const _candidateThresholdsMeters = [
  50,
  100,
  150,
  200,
  250,
  300,
  350,
  400,
  450,
  500,
  550,
  600,
  650,
  700,
  750,
  800,
  850,
  900,
  950,
  1000,
  1050,
  1100,
  1150,
  1200,
  1250,
  1300,
  1350,
  1400,
  1450,
  1500,
  1550,
  1600,
  1650,
  1700,
  1750,
  1800,
  1850,
  1900,
  1950,
  2000,
];
