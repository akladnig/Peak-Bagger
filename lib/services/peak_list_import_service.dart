import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:csv/csv.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/services/geo.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';
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
    final rows = _decodeCsv(await _csvLoader(csvPath));
    if (_isAppOwnedExportPeakListCsv(rows.first)) {
      return _importAppOwnedExportPeakList(
        listName: trimmedListName,
        existing: existing,
        rows: rows,
      );
    }
    if (_isRankedPeakListCsv(rows.first)) {
      return _importRankedPeakList(
        listName: trimmedListName,
        csvPath: csvPath,
        existing: existing,
        rows: rows,
      );
    }

    return _importHwcPeakList(
      listName: trimmedListName,
      csvPath: csvPath,
      existing: existing,
      rows: _parseHwcCsv(rows),
    );
  }

  Future<PeakListImportResult> _importAppOwnedExportPeakList({
    required String listName,
    required PeakList? existing,
    required List<List<dynamic>> rows,
  }) async {
    final headers = rows.first
        .map((value) => _headerValue('$value'))
        .toList(growable: false);
    final peaksByOsmId = {
      for (final peak in _peakRepository.getAllPeaks()) peak.osmId: peak,
    };
    final parsedRows = <_AppOwnedPeakListCsvRow>[];
    final plannedPeaksByOsmId = <int, Peak>{};

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) {
        continue;
      }

      final parsedRow = _parseAppOwnedExportRow(
        headers: headers,
        row: row,
        rowNumber: rowIndex + 1,
      );
      parsedRows.add(parsedRow);
      final existingPeak = plannedPeaksByOsmId[parsedRow.osmId] ??
          peaksByOsmId[parsedRow.osmId];
      plannedPeaksByOsmId[parsedRow.osmId] = _applyAppOwnedExportRow(
        parsedRow,
        existingPeak,
      );
    }

    for (final peak in plannedPeaksByOsmId.values) {
      await _peakRepository.save(peak);
    }

    final saved = await _peakListRepository.save(
      PeakList(
        name: listName,
        region: existing?.region ?? Peak.defaultRegion,
        peakList: encodePeakListItems([
          for (final row in parsedRows)
            PeakListItem(peakOsmId: row.osmId, points: row.points),
        ]),
      ),
    );

    return PeakListImportResult(
      peakListId: saved.peakListId,
      updated: existing != null,
      importedCount: parsedRows.length,
      skippedCount: 0,
      matchedCount: parsedRows.length,
      ambiguousCount: 0,
      warningEntries: const [],
      logEntries: const [],
    );
  }

  Future<PeakListImportResult> _importHwcPeakList({
    required String listName,
    required String csvPath,
    required PeakList? existing,
    required List<List<dynamic>> rows,
  }) async {
    final peaks = List<Peak>.from(_peakRepository.getAllPeaks());
    final items = <PeakListItem>[];
    final correctedPeaksByOsmId = <int, Peak>{};
    final warningEntries = <String>[];
    final logEntries = <String>[];
    final seenPeakOsmIds = <int>{};
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
      for (final warning in parseResult.warnings) {
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
      }
      final resolution = _resolveMatch(csvRow, peaks);
      if (resolution.match == null) {
        if (!resolution.hadSpatialCandidates) {
          final createdPeak = await _peakRepository.save(
            _createPeakFromCsv(csvRow, nextSyntheticOsmId),
          );
          nextSyntheticOsmId = createdPeak.osmId - 1;
          peaks.add(createdPeak);
          if (seenPeakOsmIds.add(createdPeak.osmId)) {
            items.add(
              PeakListItem(peakOsmId: createdPeak.osmId, points: csvRow.points),
            );
          }
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
      final shouldProtectPeak = _isProtectedHwcPeak(peak);
      final heightWarning = _heightCorrectionWarning(
        csvRow,
        peak,
        willUpdate: !shouldProtectPeak,
      );
      if (heightWarning != null) {
        warningEntries.add(heightWarning);
        logEntries.add(_timestampedLogEntry(csvPath, heightWarning));
      }
      final correctedPeak = _correctPeakFromCsv(csvRow, peak);
      if (!shouldProtectPeak && _peakNeedsSave(peak, correctedPeak)) {
        correctedPeaksByOsmId[peak.osmId] = correctedPeak;
      }
      if (_normalizeName(csvRow.name) != _normalizeName(peak.name)) {
        final warning =
            'Row ${csvRow.rowNumber}: imported ${csvRow.name} as ${peak.name}';
        warningEntries.add(warning);
        logEntries.add(_timestampedLogEntry(csvPath, warning));
      }

      if (seenPeakOsmIds.add(peak.osmId)) {
        items.add(PeakListItem(peakOsmId: peak.osmId, points: csvRow.points));
      }
    }

    for (final correctedPeak in correctedPeaksByOsmId.values) {
      await _peakRepository.save(correctedPeak);
    }

    final saved = await _peakListRepository.save(
      PeakList(name: listName, peakList: encodePeakListItems(items)),
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

  Future<PeakListImportResult> _importRankedPeakList({
    required String listName,
    required String csvPath,
    required PeakList? existing,
    required List<List<dynamic>> rows,
  }) async {
    final headers = rows.first
        .map((value) => _rankedHeaderValue('$value'))
        .toList(growable: false);
    final peaksByOsmId = {
      for (final peak in _peakRepository.getAllPeaks()) peak.osmId: peak,
    };
    final items = <PeakListItem>[];
    final correctedPeaksByOsmId = <int, Peak>{};
    final seenOsmIds = <int>{};
    _RankedRegionMapping? fileRegionMapping;

    for (var rowIndex = 1; rowIndex < rows.length; rowIndex++) {
      final row = rows[rowIndex];
      if (_isRowBlank(row)) {
        continue;
      }

      final rankedRow = _parseRankedRow(
        headers: headers,
        row: row,
        rowNumber: rowIndex + 1,
        seenOsmIds: seenOsmIds,
        peaksByOsmId: peaksByOsmId,
        currentMapping: fileRegionMapping,
      );
      fileRegionMapping ??= rankedRow.regionMapping;
      correctedPeaksByOsmId[rankedRow.osmId] = _applyRankedRow(
        rankedRow,
        peaksByOsmId[rankedRow.osmId]!,
      );
      items.add(PeakListItem(peakOsmId: rankedRow.osmId, points: 1));
    }

    for (final correctedPeak in correctedPeaksByOsmId.values) {
      if (_peakNeedsSave(peaksByOsmId[correctedPeak.osmId]!, correctedPeak)) {
        await _peakRepository.save(correctedPeak);
      }
    }

    final saved = await _peakListRepository.save(
      PeakList(
        name: listName,
        region: fileRegionMapping?.peakListRegion ??
            existing?.region ??
            Peak.defaultRegion,
        peakList: encodePeakListItems(items),
      ),
    );

    return PeakListImportResult(
      peakListId: saved.peakListId,
      updated: existing != null,
      importedCount: items.length,
      skippedCount: 0,
      matchedCount: items.length,
      ambiguousCount: 0,
      warningEntries: const [],
      logEntries: const [],
    );
  }

  List<List<dynamic>> _decodeCsv(String contents) {
    final rows = const CsvDecoder().convert(contents);
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty.');
    }

    return rows;
  }

  bool _isRankedPeakListCsv(List<dynamic> headerRow) {
    final headers = headerRow
        .map((value) => _rankedHeaderValue('$value'))
        .toList(growable: false);
    if (headers.length != _rankedPeakListHeaders.length) {
      return false;
    }

    for (var index = 0; index < headers.length; index++) {
      if (headers[index] != _rankedPeakListHeaders[index]) {
        return false;
      }
    }
    return true;
  }

  bool _isAppOwnedExportPeakListCsv(List<dynamic> headerRow) {
    final headers = headerRow
        .map((value) => _headerValue('$value'))
        .toList(growable: false);
    if (headers.length != PeakListCsvExportService.csvHeaders.length) {
      return false;
    }

    for (var index = 0; index < headers.length; index++) {
      if (headers[index] != PeakListCsvExportService.csvHeaders[index]) {
        return false;
      }
    }
    return true;
  }

  List<List<dynamic>> _parseHwcCsv(List<List<dynamic>> rows) {

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

  _AppOwnedPeakListCsvRow _parseAppOwnedExportRow({
    required List<String> headers,
    required List<dynamic> row,
    required int rowNumber,
  }) {
    final data = <String, String>{};
    for (var index = 0; index < headers.length; index++) {
      data[headers[index]] = index < row.length ? '${row[index]}'.trim() : '';
    }

    final name = data['name'] ?? '';
    final nameLabel = name.isEmpty ? 'Unnamed peak' : name;
    final rawOsmId = data['osmId'] ?? '';
    final osmId = int.tryParse(rawOsmId);
    if (osmId == null) {
      throw FormatException(
        'invalid osmId "$rawOsmId" on row $rowNumber ($nameLabel)',
      );
    }

    final rawPoints = data['Points'] ?? '';
    final points = int.tryParse(rawPoints);
    if (points == null) {
      throw FormatException(
        'invalid Points "$rawPoints" on row $rowNumber ($nameLabel)',
      );
    }

    final rawElevation = data['elevation'] ?? '';
    final elevation = rawElevation.isEmpty ? null : double.tryParse(rawElevation);
    if (rawElevation.isNotEmpty && elevation == null) {
      throw FormatException(
        'invalid elevation "$rawElevation" on row $rowNumber ($nameLabel)',
      );
    }

    final gridZoneDesignator = data['gridZoneDesignator'] ?? '';
    final mgrs100kId = data['mgrs100kId'] ?? '';
    final easting = _normalizeAppOwnedMgrsComponent(data['easting'] ?? '');
    final northing = _normalizeAppOwnedMgrsComponent(data['northing'] ?? '');
    try {
      final latitudeLongitude = PeakMgrsConverter.latLngFromComponents(
        gridZoneDesignator: gridZoneDesignator,
        mgrs100kId: mgrs100kId,
        easting: easting,
        northing: northing,
      );
      final normalizedMgrs = PeakMgrsConverter.fromForwardString(
        '$gridZoneDesignator$mgrs100kId$easting$northing',
      );
      return _AppOwnedPeakListCsvRow(
        rowNumber: rowNumber,
        osmId: osmId,
        name: name,
        altName: data['altName'] ?? '',
        elevation: elevation,
        gridZoneDesignator: normalizedMgrs.gridZoneDesignator,
        mgrs100kId: normalizedMgrs.mgrs100kId,
        easting: normalizedMgrs.easting,
        northing: normalizedMgrs.northing,
        latitude: latitudeLongitude.latitude,
        longitude: latitudeLongitude.longitude,
        points: points,
        country: data['country'] ?? '',
        region: data['region'] ?? '',
        county: data['county'] ?? '',
        range: data['range'] ?? '',
        sourceOfTruth: data['sourceOfTruth'] ?? '',
      );
    } on FormatException {
      throw FormatException('invalid grid reference on row $rowNumber ($nameLabel)');
    }
  }

  _RankedPeakListCsvRow _parseRankedRow({
    required List<String> headers,
    required List<dynamic> row,
    required int rowNumber,
    required Set<int> seenOsmIds,
    required Map<int, Peak> peaksByOsmId,
    required _RankedRegionMapping? currentMapping,
  }) {
    final data = <String, String>{};
    for (var index = 0; index < headers.length; index++) {
      data[headers[index]] = index < row.length ? '${row[index]}'.trim() : '';
    }

    final name = data['name'] ?? '';
    final rawOsmId = data['osmId'] ?? '';
    if (rawOsmId.isEmpty) {
      throw FormatException('row $rowNumber is missing osmId ($name)');
    }

    final osmId = int.tryParse(rawOsmId);
    if (osmId == null || !peaksByOsmId.containsKey(osmId)) {
      throw FormatException(
        'row $rowNumber references unknown osmId $rawOsmId ($name)',
      );
    }
    if (!seenOsmIds.add(osmId)) {
      throw FormatException('duplicate osmId $osmId on row $rowNumber');
    }

    final regionValue = data['region'] ?? '';
    final regionMapping = _rankedRegionMappings[regionValue];
    if (regionMapping == null) {
      throw FormatException(
        'unsupported region "$regionValue" on row $rowNumber',
      );
    }
    if (currentMapping != null && currentMapping != regionMapping) {
      throw const FormatException('mixed ranked-import regions in one file');
    }

    return _RankedPeakListCsvRow(
      rowNumber: rowNumber,
      osmId: osmId,
      name: name,
      rating: _parseRankedRating(data['rating'] ?? '', rowNumber: rowNumber, name: name),
      elevation: _parseRankedNumber(
        data['elevation'] ?? '',
        fieldName: 'elevation',
        rowNumber: rowNumber,
        name: name,
      ),
      prominence: _parseRankedNumber(
        data['prominence'] ?? '',
        fieldName: 'prominence',
        rowNumber: rowNumber,
        name: name,
      ),
      latitude: _parseRankedNumber(
        data['latitude'] ?? '',
        fieldName: 'latitude',
        rowNumber: rowNumber,
        name: name,
      ),
      longitude: _parseRankedNumber(
        data['longitude'] ?? '',
        fieldName: 'longitude',
        rowNumber: rowNumber,
        name: name,
      ),
      country: data['country'] ?? '',
      range: data['range'] ?? '',
      county: data['county'] ?? '',
      difficulty: data['difficulty'] ?? '',
      viaFerrata: data['viaFerrata'] ?? '',
      notes: data['notes'] ?? '',
      regionMapping: regionMapping,
    );
  }

  double? _parseRankedRating(
    String rawValue, {
    required int rowNumber,
    required String name,
  }) {
    final parsed = _parseRankedNumber(
      rawValue,
      fieldName: 'rating',
      rowNumber: rowNumber,
      name: name,
    );
    if (parsed == null) {
      return null;
    }
    if (parsed < 0 || parsed > 5) {
      throw FormatException('invalid rating "$rawValue" on row $rowNumber ($name)');
    }
    return (parsed * 10).round() / 10;
  }

  double? _parseRankedNumber(
    String rawValue, {
    required String fieldName,
    required int rowNumber,
    required String name,
  }) {
    if (rawValue.isEmpty) {
      return null;
    }
    final parsed = double.tryParse(rawValue);
    if (parsed != null) {
      return parsed;
    }
    throw FormatException(
      'invalid $fieldName "$rawValue" on row $rowNumber ($name)',
    );
  }

  Peak _applyRankedRow(_RankedPeakListCsvRow row, Peak peak) {
    final latitude = row.latitude ?? peak.latitude;
    final longitude = row.longitude ?? peak.longitude;
    final mgrs = PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
    return peak.copyWith(
      name: row.name.isEmpty ? peak.name : row.name,
      elevation: row.elevation ?? peak.elevation,
      prominence: row.prominence ?? peak.prominence,
      latitude: latitude,
      longitude: longitude,
      country: row.country.isEmpty ? peak.country : row.country,
      region: row.regionMapping.peakRegion,
      range: row.range.isEmpty ? peak.range : row.range,
      county: row.county.isEmpty ? peak.county : row.county,
      rating: row.rating ?? peak.rating,
      difficulty: row.difficulty.isEmpty ? peak.difficulty : row.difficulty,
      viaFerrata: row.viaFerrata.isEmpty ? peak.viaFerrata : row.viaFerrata,
      notes: row.notes.isEmpty ? peak.notes : row.notes,
      gridZoneDesignator: mgrs.gridZoneDesignator,
      mgrs100kId: mgrs.mgrs100kId,
      easting: mgrs.easting,
      northing: mgrs.northing,
      sourceOfTruth: row.regionMapping.sourceOfTruth,
    );
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

      final warnings = <String>[];
      final rawName = data['Name']!.trim();
      final name = rawName.isEmpty ? 'Unknown' : rawName;
      final rawPoints = data['Points']!.trim();
      final points = _parsePointsValue(
        rawPoints,
        rowNumber: rowNumber,
        name: name,
        warnings: warnings,
      );
      final rawHeight = _preferHeightValue(data).trim();
      final height = _parseHeightValue(
        rawHeight,
        rowNumber: rowNumber,
        name: name,
        warnings: warnings,
      );

      final zone = data['Zone']!.trim().toUpperCase();
      final eastingValue = data['Easting']!.trim();
      final northingValue = data['Northing']!.trim();
      final latitudeValue = data['Latitude']!.trim();
      final longitudeValue = data['Longitude']!.trim();
      final hasLatLng = latitudeValue.isNotEmpty && longitudeValue.isNotEmpty;
      final hasUtm =
          zone.isNotEmpty &&
          eastingValue.isNotEmpty &&
          northingValue.isNotEmpty;
      if (!hasLatLng && !hasUtm) {
        return _PeakListCsvRowParseResult(
          error: 'Row $rowNumber: incomplete coordinate data for $name',
          warnings: warnings,
        );
      }

      final latitude = hasLatLng
          ? double.parse(latitudeValue)
          : PeakMgrsConverter.latLngFromCsvUtm(
              zone: zone,
              easting: eastingValue,
              northing: northingValue,
            ).latitude;
      final longitude = hasLatLng
          ? double.parse(longitudeValue)
          : PeakMgrsConverter.latLngFromCsvUtm(
              zone: zone,
              easting: eastingValue,
              northing: northingValue,
            ).longitude;
      final mgrs = hasUtm
          ? PeakMgrsConverter.fromCsvUtm(
              zone: zone,
              easting: eastingValue,
              northing: northingValue,
            )
          : PeakMgrsConverter.fromLatLng(LatLng(latitude, longitude));
      return _PeakListCsvRowParseResult(
        row: _PeakListCsvRow(
          rowNumber: rowNumber,
          name: name,
          height: height,
          zone: mgrs.gridZoneDesignator,
          mgrs100kId: mgrs.mgrs100kId,
          easting: int.parse(mgrs.easting),
          northing: int.parse(mgrs.northing),
          latitude: latitude,
          longitude: longitude,
          points: points,
        ),
        warnings: warnings,
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

  String? _heightCorrectionWarning(
    _PeakListCsvRow row,
    Peak peak, {
    required bool willUpdate,
  }) {
    final existingHeight = peak.elevation?.round();
    if (existingHeight == row.height) {
      return null;
    }

    final existingLabel = existingHeight == null
        ? 'unknown'
        : '${existingHeight}m';
    final action = willUpdate ? 'updated' : 'kept';
    return 'Row ${row.rowNumber}: $action height for ${row.name} '
        'at $existingLabel instead of ${row.height}m';
  }

  bool _isProtectedHwcPeak(Peak peak) {
    return peak.sourceOfTruth == Peak.sourceOfTruthHwc;
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
    return original.name != corrected.name ||
        original.latitude != corrected.latitude ||
        original.longitude != corrected.longitude ||
        original.elevation != corrected.elevation ||
        original.prominence != corrected.prominence ||
        original.country != corrected.country ||
        original.county != corrected.county ||
        original.range != corrected.range ||
        original.rating != corrected.rating ||
        original.difficulty != corrected.difficulty ||
        original.viaFerrata != corrected.viaFerrata ||
        original.notes != corrected.notes ||
        original.region != corrected.region ||
        original.gridZoneDesignator != corrected.gridZoneDesignator ||
        original.mgrs100kId != corrected.mgrs100kId ||
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

  String _headerValue(String header) {
    return header.replaceFirst('\u{FEFF}', '').trim();
  }

  String _normalizeAppOwnedMgrsComponent(String value) {
    final trimmed = value.trim();
    if (!RegExp(r'^\d{1,5}$').hasMatch(trimmed)) {
      throw const FormatException('Invalid app-owned MGRS component');
    }
    return trimmed.padLeft(5, '0');
  }

  String _rankedHeaderValue(String header) {
    return header.replaceFirst('\u{FEFF}', '');
  }

  Peak _applyAppOwnedExportRow(
    _AppOwnedPeakListCsvRow row,
    Peak? existingPeak,
  ) {
    if (existingPeak == null) {
      return Peak(
        osmId: row.osmId,
        name: row.name,
        altName: row.altName,
        elevation: row.elevation,
        latitude: row.latitude,
        longitude: row.longitude,
        region: row.region,
        gridZoneDesignator: row.gridZoneDesignator,
        mgrs100kId: row.mgrs100kId,
        easting: row.easting,
        northing: row.northing,
        country: row.country,
        county: row.county,
        range: row.range,
        sourceOfTruth: row.sourceOfTruth,
      );
    }

    return existingPeak.copyWith(
      name: row.name,
      altName: row.altName,
      elevation: row.elevation,
      latitude: row.latitude,
      longitude: row.longitude,
      country: row.country,
      county: row.county,
      range: row.range,
      region: row.region,
      gridZoneDesignator: row.gridZoneDesignator,
      mgrs100kId: row.mgrs100kId,
      easting: row.easting,
      northing: row.northing,
      sourceOfTruth: row.sourceOfTruth,
    );
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

  int _parsePointsValue(
    String rawPoints, {
    required int rowNumber,
    required String name,
    required List<String> warnings,
  }) {
    if (rawPoints.isEmpty) {
      return 0;
    }

    final parsed = int.tryParse(rawPoints);
    if (parsed != null) {
      return parsed;
    }

    warnings.add('Row $rowNumber: normalized invalid points for $name to 0');
    return 0;
  }

  int _parseHeightValue(
    String rawHeight, {
    required int rowNumber,
    required String name,
    required List<String> warnings,
  }) {
    if (rawHeight.isEmpty) {
      warnings.add('Row $rowNumber: missing height for $name defaulted to 0');
      return 0;
    }

    return double.parse(rawHeight).round();
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
  final int points;
}

class _PeakListCsvRowParseResult {
  const _PeakListCsvRowParseResult({
    this.row,
    this.error,
    this.warnings = const [],
  });

  final _PeakListCsvRow? row;
  final String? error;
  final List<String> warnings;
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

class _RankedPeakListCsvRow {
  const _RankedPeakListCsvRow({
    required this.rowNumber,
    required this.osmId,
    required this.name,
    required this.rating,
    required this.elevation,
    required this.prominence,
    required this.latitude,
    required this.longitude,
    required this.country,
    required this.range,
    required this.county,
    required this.difficulty,
    required this.viaFerrata,
    required this.notes,
    required this.regionMapping,
  });

  final int rowNumber;
  final int osmId;
  final String name;
  final double? rating;
  final double? elevation;
  final double? prominence;
  final double? latitude;
  final double? longitude;
  final String country;
  final String range;
  final String county;
  final String difficulty;
  final String viaFerrata;
  final String notes;
  final _RankedRegionMapping regionMapping;
}

class _AppOwnedPeakListCsvRow {
  const _AppOwnedPeakListCsvRow({
    required this.rowNumber,
    required this.osmId,
    required this.name,
    required this.altName,
    required this.elevation,
    required this.gridZoneDesignator,
    required this.mgrs100kId,
    required this.easting,
    required this.northing,
    required this.latitude,
    required this.longitude,
    required this.points,
    required this.country,
    required this.region,
    required this.county,
    required this.range,
    required this.sourceOfTruth,
  });

  final int rowNumber;
  final int osmId;
  final String name;
  final String altName;
  final double? elevation;
  final String gridZoneDesignator;
  final String mgrs100kId;
  final String easting;
  final String northing;
  final double latitude;
  final double longitude;
  final int points;
  final String country;
  final String region;
  final String county;
  final String range;
  final String sourceOfTruth;
}

class _RankedRegionMapping {
  const _RankedRegionMapping({
    required this.peakRegion,
    required this.peakListRegion,
    required this.sourceOfTruth,
  });

  final String peakRegion;
  final String peakListRegion;
  final String sourceOfTruth;
}

const _rankedPeakListHeaders = [
  'name',
  'osmId',
  'rating',
  'elevation',
  'prominence',
  'latitude',
  'longitude',
  'country',
  'region',
  'range',
  'county',
  'difficulty',
  'viaFerrata',
  'notes',
];

const _rankedRegionMappings = {
  'Friuli Venezia Giulia': _RankedRegionMapping(
    peakRegion: 'fvg',
    peakListRegion: 'italy-nord-est',
    sourceOfTruth: Peak.sourceOfTruthFvg,
  ),
  'Veneto': _RankedRegionMapping(
    peakRegion: 'veneto',
    peakListRegion: 'italy-nord-est',
    sourceOfTruth: Peak.sourceOfTruthVeneto,
  ),
};

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
