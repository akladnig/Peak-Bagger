import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/peak_source.dart';
import 'package:peak_bagger/services/slovenia_peak_correlation_service.dart';

const sloveniaRankedPeakListBaseName = 'slovenia-ranked-peaks';

const List<String> sloveniaHribiSourcePeakListCsvHeader = [
  'Name',
  'Alt Name',
  'Country',
  'Mountain Range',
  'Altitude',
  'Latitude',
  'Longitude',
  'Popularity',
  'Rating',
  'Type',
];

const List<String> sloveniaHribiSourcePeakListRepairCsvHeader = [
  'Kind',
  'RangeUrl',
  'DetailUrl',
  'Name',
  'MissingFields',
  'LastError',
];

class SloveniaHribiSourceRangeConfig {
  const SloveniaHribiSourceRangeConfig({
    required this.order,
    required this.hribiRangeUrl,
    required this.mountainRangeLabel,
    required this.hikeRangeUrl,
    required this.montiRangeUrl,
  });

  final int order;
  final String hribiRangeUrl;
  final String mountainRangeLabel;
  final String hikeRangeUrl;
  final String montiRangeUrl;
}

const List<SloveniaHribiSourceRangeConfig>
sloveniaHribiSourceRangeConfigurations = [
  SloveniaHribiSourceRangeConfig(
    order: 1,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/gorisko_notranjsko_in_sneznisko_hribovje/26',
    mountainRangeLabel: 'Goriško, Notranjsko and Snežniško hribovje',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/gorisko_notranjsko_and_sneznisko_hribovje/26',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/gorisko_notranjsko_e_sneznisko_hribovje/26',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 2,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/julijske_alpe/1',
    mountainRangeLabel: 'Julian Alps',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/julian_alps/1',
    montiRangeUrl: 'https://www.monti.uno/catena_montuosa/alpi_giulie/1',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 3,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/kamnisko_savinjske_alpe/3',
    mountainRangeLabel: 'Kamnik Savinja Alps',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/kamnik_savinja_alps/3',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/alpi_di_kamnik-savinja/3',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 4,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/karavanke/11',
    mountainRangeLabel: 'Karawanks',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/karawanks/11',
    montiRangeUrl: 'https://www.monti.uno/catena_montuosa/caravanche/11',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 5,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/pohorje_dravinjske_gorice_in_haloze/4',
    mountainRangeLabel: 'Pohorje, Dravinjske gorice and Haloze',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/pohorje_dravinjske_gorice_and_haloze/4',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/pohorje_dravinjske_gorice_e_haloze/4',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 6,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/polhograjsko_hribovje_in_ljubljana/5',
    mountainRangeLabel: 'Polhograjsko hribovje and Ljubljana',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/polhograjsko_hribovje_and_ljubljana/5',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/polhograjsko_hribovje_e_lubiana/5',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 7,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/posavsko_hribovje_in_dolenjska/25',
    mountainRangeLabel: 'Posavsko hribovje and Dolenjska',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/posavsko_hribovje_and_dolenjska/25',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/posavsko_hribovje_e_dolenjska/25',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 8,
    hribiRangeUrl: 'https://www.hribi.net/gorovje/prekmurje/163',
    mountainRangeLabel: 'Prekmurje',
    hikeRangeUrl: 'https://www.hike.uno/mountain_range/prekmurje/163',
    montiRangeUrl: 'https://www.monti.uno/catena_montuosa/prekmurje/163',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 9,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/skofjelosko_cerkljansko_hribovje_in_jelovica/21',
    mountainRangeLabel: 'Škofjeloško, Cerkljansko hribovje and Jelovica',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/skofjelosko_cerkljansko_hribovje_and_jelovica/21',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/skofjelosko_cerkljansko_hribovje_e_jelovica/21',
  ),
  SloveniaHribiSourceRangeConfig(
    order: 10,
    hribiRangeUrl:
        'https://www.hribi.net/gorovje/strojna_kosenjak_kozjak_in_slovenske_gorice/162',
    mountainRangeLabel: 'Strojna, Košenjak, Kozjak and Slovenske gorice',
    hikeRangeUrl:
        'https://www.hike.uno/mountain_range/strojna_kosenjak_kozjak_and_slovenske_gorice/162',
    montiRangeUrl:
        'https://www.monti.uno/catena_montuosa/strojna_kosenjak_kozjak_e_slovenske_gorice/162',
  ),
];

typedef SloveniaHribiSourcePageLoader = Future<String> Function(Uri uri);
typedef SloveniaHribiSourceProgressCallback = void Function(String message);

class SloveniaHribiSourceRangeEntry {
  const SloveniaHribiSourceRangeEntry({
    required this.name,
    required this.detailUrl,
    required this.sourceOrder,
    required this.detailId,
  });

  final String name;
  final String detailUrl;
  final int sourceOrder;
  final int? detailId;
}

class SloveniaHribiSourceMontiEntry {
  const SloveniaHribiSourceMontiEntry({
    required this.name,
    required this.detailUrl,
    required this.sourceOrder,
    required this.detailId,
  });

  final String name;
  final String detailUrl;
  final int sourceOrder;
  final int? detailId;
}

class SloveniaHribiSourcePeakDetail {
  const SloveniaHribiSourcePeakDetail({
    required this.name,
    required this.countryText,
    required this.altitudeText,
    required this.coordinatesText,
    required this.popularityText,
    required this.typeText,
  });

  final String name;
  final String countryText;
  final String altitudeText;
  final String coordinatesText;
  final String popularityText;
  final String typeText;
}

class SloveniaHribiSourcePeakListHtmlParser {
  const SloveniaHribiSourcePeakListHtmlParser();

  List<SloveniaHribiSourceRangeEntry> parseHribiRangeEntries(String html) {
    final document = html_parser.parse(html);
    return _parseRangeEntries(
      document: document,
      detailPathSegment: '/gora/',
      hostBaseUrl: 'https://www.hribi.net',
      builder: (name, detailUrl, sourceOrder, detailId) =>
          SloveniaHribiSourceRangeEntry(
            name: name,
            detailUrl: detailUrl,
            sourceOrder: sourceOrder,
            detailId: detailId,
          ),
    );
  }

  List<SloveniaHribiSourceMontiEntry> parseMontiRangeEntries(String html) {
    final document = html_parser.parse(html);
    return _parseRangeEntries(
      document: document,
      detailPathSegment: '/montagna/',
      hostBaseUrl: 'https://www.monti.uno',
      builder: (name, detailUrl, sourceOrder, detailId) =>
          SloveniaHribiSourceMontiEntry(
            name: name,
            detailUrl: detailUrl,
            sourceOrder: sourceOrder,
            detailId: detailId,
          ),
    );
  }

  SloveniaHribiSourcePeakDetail parseHribiDetail(
    String html, {
    required String fallbackName,
  }) {
    final document = html_parser.parse(html);
    final heading = _cleanText(document.querySelector('h1')?.text);
    final name = heading.isEmpty ? fallbackName : heading;
    final countryText = _fieldText(document, const {'država'}) ?? '';
    final altitudeText = _fieldText(document, const {'višina'}) ?? '';
    final popularityText = _fieldText(document, const {'priljubljenost'}) ?? '';
    final typeText = _fieldText(document, const {'vrsta'}) ?? '';
    final coordinatesText = _cleanText(document.querySelector('#kf0')?.text);

    return SloveniaHribiSourcePeakDetail(
      name: name,
      countryText: countryText,
      altitudeText: altitudeText,
      coordinatesText: coordinatesText,
      popularityText: popularityText,
      typeText: typeText,
    );
  }

  List<T> _parseRangeEntries<T>({
    required dom.Document document,
    required String detailPathSegment,
    required String hostBaseUrl,
    required T Function(String, String, int, int?) builder,
  }) {
    final table = document.querySelector('#gorovjaseznam table');
    if (table == null) {
      throw FormatException('Missing range listing table');
    }

    final entries = <T>[];
    final seenUrls = <String>{};
    for (final row in table.querySelectorAll('tr')) {
      final anchor = row.querySelector('a[href*="$detailPathSegment"]');
      if (anchor == null) {
        continue;
      }
      final href = anchor.attributes['href'];
      if (href == null || href.isEmpty) {
        continue;
      }
      final detailUrl = _absoluteUrl(href, hostBaseUrl: hostBaseUrl);
      if (!seenUrls.add(detailUrl)) {
        continue;
      }
      entries.add(
        builder(
          _cleanText(anchor.text),
          detailUrl,
          entries.length,
          _detailIdFromUrl(detailUrl),
        ),
      );
    }

    if (entries.isEmpty) {
      throw FormatException('No range entries found for $detailPathSegment');
    }

    return entries;
  }

  String? _fieldText(dom.Document document, Set<String> acceptedLabels) {
    for (final field in document.querySelectorAll('div.g2')) {
      final label = field.querySelector('b');
      if (label == null) {
        continue;
      }
      final normalizedLabel = _normalizeLabel(label.text);
      if (!acceptedLabels.contains(normalizedLabel)) {
        continue;
      }
      final fieldText = _cleanText(field.text);
      final labelText = _cleanText(label.text);
      if (fieldText.startsWith(labelText)) {
        return _cleanText(fieldText.substring(labelText.length));
      }
      return fieldText;
    }
    return null;
  }

  static String _normalizeLabel(String value) {
    return _cleanText(
      value,
    ).toLowerCase().replaceAll(':', '').replaceAll('.', '');
  }

  static String _absoluteUrl(String href, {required String hostBaseUrl}) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('//')) {
      return 'https:$href';
    }
    return Uri.parse(hostBaseUrl).resolve(href).toString();
  }
}

class SloveniaHribiSourcePeakListNormalizer {
  const SloveniaHribiSourcePeakListNormalizer();

  static const Map<String, String> _countryMapping = {
    'Slovenija': 'Slovenia',
    'Italija': 'Italy',
    'Hrvaška': 'Croatia',
    'Avstrija': 'Austria',
  };

  bool isPeakType(String rawType) {
    return rawType.toLowerCase().contains('vrh');
  }

  String normalizeCountry(String rawCountry) {
    final seen = <String>{};
    final values = <String>[];
    for (final token in rawCountry.split(RegExp(r'\s*(?:,|/)\s*'))) {
      final trimmed = _cleanText(token);
      if (trimmed.isEmpty) {
        continue;
      }
      final mapped = _countryMapping[trimmed] ?? trimmed;
      if (seen.add(mapped)) {
        values.add(mapped);
      }
    }
    return values.join(', ');
  }

  String normalizeAltitude(String rawAltitude) {
    return _firstInteger(rawAltitude);
  }

  ({String latitude, String longitude}) normalizeCoordinates(
    String rawCoordinates,
  ) {
    final matches = RegExp(
      r'([+-]?\d+(?:[\.,]\d+)?)\s*°?\s*([NSEW])',
      caseSensitive: false,
    ).allMatches(rawCoordinates).toList(growable: false);
    if (matches.length < 2) {
      return (latitude: '', longitude: '');
    }

    return (
      latitude: _normalizedCoordinate(matches[0]),
      longitude: _normalizedCoordinate(matches[1]),
    );
  }

  String normalizePopularity(String rawPopularity) {
    final percentMatch = RegExp(r'(\d+)\s*%').firstMatch(rawPopularity);
    if (percentMatch != null) {
      return percentMatch.group(1)!;
    }
    return _firstInteger(rawPopularity);
  }

  ({String name, String altName}) resolveNames({
    required String hribiName,
    required String montiName,
    required String normalizedCountry,
  }) {
    final cleanedHribi = _cleanText(hribiName);
    final cleanedMonti = _cleanText(montiName);
    final countryParts = normalizedCountry
        .split(',')
        .map(_cleanText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    final sloveniaOnly =
        countryParts.length == 1 && countryParts.single == 'Slovenia';
    final primary = sloveniaOnly || cleanedMonti.isEmpty
        ? cleanedHribi
        : cleanedMonti;
    var alternate = sloveniaOnly ? cleanedMonti : cleanedHribi;
    if (_normalizeComparable(alternate) == _normalizeComparable(primary)) {
      alternate = '';
    }
    return (name: primary, altName: alternate);
  }

  static String _normalizedCoordinate(RegExpMatch match) {
    final numeric = match.group(1)!.replaceAll(',', '.');
    final direction = match.group(2)!.toUpperCase();
    final negative = direction == 'S' || direction == 'W';
    return negative && !numeric.startsWith('-') ? '-$numeric' : numeric;
  }

  static String _normalizeComparable(String value) {
    return _cleanText(value).toLowerCase();
  }

  static String _firstInteger(String value) {
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digits;
  }
}

class SloveniaHribiSourcePeakListRow {
  const SloveniaHribiSourcePeakListRow({
    required this.name,
    required this.altName,
    required this.country,
    required this.mountainRange,
    required this.altitude,
    required this.latitude,
    required this.longitude,
    required this.popularity,
    required this.rangeOrder,
    required this.sourceOrder,
    required this.rangeUrl,
    required this.hribiDetailUrl,
    required this.montiDetailUrl,
  });

  final String name;
  final String altName;
  final String country;
  final String mountainRange;
  final String altitude;
  final String latitude;
  final String longitude;
  final String popularity;
  final int rangeOrder;
  final int sourceOrder;
  final String rangeUrl;
  final String hribiDetailUrl;
  final String montiDetailUrl;

  String get rating {
    final popularityValue = double.tryParse(popularity);
    if (popularityValue == null) {
      return '';
    }
    final clamped = (popularityValue / 20).clamp(0, 5);
    return clamped.toStringAsFixed(1);
  }

  factory SloveniaHribiSourcePeakListRow.fromStateJson(
    Map<String, dynamic> json,
  ) {
    return SloveniaHribiSourcePeakListRow(
      name: json['Name'] as String? ?? '',
      altName: json['AltName'] as String? ?? '',
      country: json['Country'] as String? ?? '',
      mountainRange: json['MountainRange'] as String? ?? '',
      altitude: json['Altitude'] as String? ?? '',
      latitude: json['Latitude'] as String? ?? '',
      longitude: json['Longitude'] as String? ?? '',
      popularity: json['Popularity'] as String? ?? '',
      rangeOrder: json['RangeOrder'] as int? ?? 0,
      sourceOrder: json['SourceOrder'] as int? ?? 0,
      rangeUrl: json['RangeUrl'] as String? ?? '',
      hribiDetailUrl: json['HribiDetailUrl'] as String? ?? '',
      montiDetailUrl: json['MontiDetailUrl'] as String? ?? '',
    );
  }

  List<String> toCsvRow() {
    return [
      name,
      altName,
      country,
      mountainRange,
      altitude,
      latitude,
      longitude,
      popularity,
      rating,
      'Peak',
    ];
  }

  Map<String, Object> toStateJson() {
    return {
      'Name': name,
      'AltName': altName,
      'Country': country,
      'MountainRange': mountainRange,
      'Altitude': altitude,
      'Latitude': latitude,
      'Longitude': longitude,
      'Popularity': popularity,
      'Rating': rating,
      'Type': 'Peak',
      'RangeOrder': rangeOrder,
      'SourceOrder': sourceOrder,
      'RangeUrl': rangeUrl,
      'HribiDetailUrl': hribiDetailUrl,
      'MontiDetailUrl': montiDetailUrl,
    };
  }
}

class SloveniaHribiSourcePeakListRepairEntry {
  const SloveniaHribiSourcePeakListRepairEntry({
    required this.kind,
    required this.rangeUrl,
    required this.detailUrl,
    required this.name,
    required this.missingFields,
    required this.lastError,
  });

  final String kind;
  final String rangeUrl;
  final String detailUrl;
  final String name;
  final List<String> missingFields;
  final String lastError;

  factory SloveniaHribiSourcePeakListRepairEntry.fromStateJson(
    Map<String, dynamic> json,
  ) {
    final rawMissingFields = json['MissingFields'];
    return SloveniaHribiSourcePeakListRepairEntry(
      kind: json['Kind'] as String? ?? '',
      rangeUrl: json['RangeUrl'] as String? ?? '',
      detailUrl: json['DetailUrl'] as String? ?? '',
      name: json['Name'] as String? ?? '',
      missingFields: switch (rawMissingFields) {
        final List<dynamic> values => values.map((value) => '$value').toList(),
        final String value when value.isNotEmpty =>
          value
              .split(',')
              .map(_cleanText)
              .where((entry) => entry.isNotEmpty)
              .toList(),
        _ => const [],
      },
      lastError: json['LastError'] as String? ?? '',
    );
  }

  List<String> toCsvRow() {
    return [
      kind,
      rangeUrl,
      detailUrl,
      name,
      missingFields.join(', '),
      lastError,
    ];
  }

  Map<String, Object> toStateJson() {
    return {
      'Kind': kind,
      'RangeUrl': rangeUrl,
      'DetailUrl': detailUrl,
      'Name': name,
      'MissingFields': missingFields,
      'LastError': lastError,
    };
  }
}

class SloveniaHribiSourcePeakListRunResult {
  const SloveniaHribiSourcePeakListRunResult({
    required this.rows,
    required this.canonicalRows,
    required this.reviewRows,
    required this.csvPath,
    required this.reviewPath,
    required this.repairPath,
    required this.statePath,
    required this.repairEntries,
    required this.summaries,
    required this.version,
    required this.createdNewVersion,
    required this.tieWindowMeters,
  });

  final List<SloveniaHribiSourcePeakListRow> rows;
  final List<SloveniaRankedPeakListCsvRow> canonicalRows;
  final List<SloveniaCorrelationReviewCsvRow> reviewRows;
  final String csvPath;
  final String reviewPath;
  final String repairPath;
  final String statePath;
  final List<SloveniaHribiSourcePeakListRepairEntry> repairEntries;
  final List<String> summaries;
  final int version;
  final bool createdNewVersion;
  final int tieWindowMeters;
}

class _SloveniaHribiSourcePeakListSnapshot {
  const _SloveniaHribiSourcePeakListSnapshot({
    required this.version,
    required this.rows,
    required this.repairEntries,
    required this.csvPath,
    required this.reviewPath,
    required this.repairPath,
    required this.statePath,
    required this.csvText,
    required this.reviewText,
    required this.repairText,
  });

  final int version;
  final List<SloveniaHribiSourcePeakListRow> rows;
  final List<SloveniaHribiSourcePeakListRepairEntry> repairEntries;
  final String csvPath;
  final String reviewPath;
  final String repairPath;
  final String statePath;
  final String csvText;
  final String reviewText;
  final String repairText;
}

class _SloveniaHribiSourcePeakListArtifacts {
  const _SloveniaHribiSourcePeakListArtifacts({
    required this.rows,
    required this.repairEntries,
    required this.summaries,
  });

  final List<SloveniaHribiSourcePeakListRow> rows;
  final List<SloveniaHribiSourcePeakListRepairEntry> repairEntries;
  final List<String> summaries;
}

class _SloveniaHribiSourcePeakRepairOutcome {
  const _SloveniaHribiSourcePeakRepairOutcome({
    required this.row,
    required this.repairEntry,
    required this.summaries,
  });

  final SloveniaHribiSourcePeakListRow? row;
  final SloveniaHribiSourcePeakListRepairEntry? repairEntry;
  final List<String> summaries;
}

class SloveniaHribiSourcePeakListException implements Exception {
  const SloveniaHribiSourcePeakListException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SloveniaHribiSourcePeakListService {
  SloveniaHribiSourcePeakListService({
    SloveniaHribiSourcePageLoader? pageLoader,
    http.Client? httpClient,
    PeakSource? peakSource,
    SloveniaHribiSourcePeakListHtmlParser htmlParser =
        const SloveniaHribiSourcePeakListHtmlParser(),
    SloveniaHribiSourcePeakListNormalizer normalizer =
        const SloveniaHribiSourcePeakListNormalizer(),
    List<SloveniaHribiSourceRangeConfig> rangeConfigurations =
        sloveniaHribiSourceRangeConfigurations,
    Directory Function()? outputDirectoryResolver,
    Directory Function()? cacheDirectoryResolver,
    SloveniaHribiSourceProgressCallback? onProgress,
  }) : this._(
         htmlParser: htmlParser,
         normalizer: normalizer,
         rangeConfigurations: rangeConfigurations,
         outputDirectoryResolver:
             outputDirectoryResolver ?? _defaultOutputDirectoryResolver,
         cacheDirectoryResolver:
             cacheDirectoryResolver ?? _defaultCacheDirectoryResolver,
         httpClient: httpClient ?? http.Client(),
         ownsClient: httpClient == null,
         peakSource: peakSource ?? InMemoryPeakSource(),
         pageLoader: pageLoader,
         onProgress: onProgress,
       );

  SloveniaHribiSourcePeakListService._({
    required this.htmlParser,
    required this.normalizer,
    required this.rangeConfigurations,
    required this._outputDirectoryResolver,
    required this._cacheDirectoryResolver,
    required http.Client httpClient,
    required bool ownsClient,
    required this._peakSource,
    SloveniaHribiSourcePageLoader? pageLoader,
    this._onProgress,
  }) : _ownedClient = ownsClient ? httpClient : null,
       _basePageLoader = pageLoader ?? _buildDefaultPageLoader(httpClient);

  final SloveniaHribiSourcePeakListHtmlParser htmlParser;
  final SloveniaHribiSourcePeakListNormalizer normalizer;
  final List<SloveniaHribiSourceRangeConfig> rangeConfigurations;
  final Directory Function() _outputDirectoryResolver;
  final Directory Function() _cacheDirectoryResolver;
  final http.Client? _ownedClient;
  final PeakSource _peakSource;
  final SloveniaHribiSourcePageLoader _basePageLoader;
  final SloveniaHribiSourceProgressCallback? _onProgress;

  Future<SloveniaHribiSourcePeakListRunResult> run({
    bool repairList = false,
    bool refreshCache = false,
    int tieWindowMeters = 10,
  }) async {
    try {
      final latestSnapshot = _loadLatestSnapshot(requireRepairFile: repairList);
      if (repairList && latestSnapshot == null) {
        throw const SloveniaHribiSourcePeakListException(
          'No repair file found. Run a normal crawl first.',
        );
      }

      final artifacts = repairList
          ? await _runRepair(
              latestSnapshot: latestSnapshot!,
              refreshCache: refreshCache,
            )
          : await _runNormal(refreshCache: refreshCache);
      final normalizedRows = _sortedRows(artifacts.rows);
      final correlationOutput = SloveniaPeakCorrelationService(
        peakSource: _peakSource,
      ).correlate(rows: normalizedRows, tieWindowMeters: tieWindowMeters);
      final csvText = _buildRankedCsvText(correlationOutput.canonicalRows);
      final reviewText = _buildReviewCsvText(correlationOutput.reviewRows);
      final repairText = _buildRepairCsvText(artifacts.repairEntries);
      final correlationSummaries = _buildCorrelationSummaries(
        correlationOutput: correlationOutput,
        tieWindowMeters: tieWindowMeters,
      );
      final combinedSummaries = [
        ...artifacts.summaries,
        ...correlationSummaries,
      ];

      if (latestSnapshot != null &&
          latestSnapshot.csvText == csvText &&
          latestSnapshot.reviewText == reviewText &&
          latestSnapshot.repairText == repairText) {
        return SloveniaHribiSourcePeakListRunResult(
          rows: normalizedRows,
          canonicalRows: correlationOutput.canonicalRows,
          reviewRows: correlationOutput.reviewRows,
          csvPath: latestSnapshot.csvPath,
          reviewPath: latestSnapshot.reviewPath,
          repairPath: latestSnapshot.repairPath,
          statePath: latestSnapshot.statePath,
          repairEntries: artifacts.repairEntries,
          summaries: combinedSummaries,
          version: latestSnapshot.version,
          createdNewVersion: false,
          tieWindowMeters: tieWindowMeters,
        );
      }

      final outputDirectory = _outputDirectoryResolver();
      await outputDirectory.create(recursive: true);
      final version = _nextVersion(outputDirectory);
      final csvPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.csv',
      );
      final reviewPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.review.csv',
      );
      final repairPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.repair.csv',
      );
      final statePath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.state.json',
      );
      final stateJson = _buildStateJson(
        version: version,
        rows: normalizedRows,
        canonicalRows: correlationOutput.canonicalRows,
        reviewRows: correlationOutput.reviewRows,
        repairEntries: artifacts.repairEntries,
        csvPath: csvPath,
        reviewPath: reviewPath,
        repairPath: repairPath,
        tieWindowMeters: tieWindowMeters,
      );

      await File(csvPath).writeAsString(csvText);
      await File(reviewPath).writeAsString(reviewText);
      await File(repairPath).writeAsString(repairText);
      await File(statePath).writeAsString(stateJson);

      return SloveniaHribiSourcePeakListRunResult(
        rows: normalizedRows,
        canonicalRows: correlationOutput.canonicalRows,
        reviewRows: correlationOutput.reviewRows,
        csvPath: csvPath,
        reviewPath: reviewPath,
        repairPath: repairPath,
        statePath: statePath,
        repairEntries: artifacts.repairEntries,
        summaries: combinedSummaries,
        version: version,
        createdNewVersion: true,
        tieWindowMeters: tieWindowMeters,
      );
    } finally {
      _ownedClient?.close();
    }
  }

  SloveniaHribiSourceMontiEntry? _resolveMontiEntry({
    required SloveniaHribiSourceRangeEntry hribiEntry,
    required Map<int, SloveniaHribiSourceMontiEntry> montiByDetailId,
    required List<SloveniaHribiSourceMontiEntry> montiEntries,
  }) {
    final detailId = hribiEntry.detailId;
    if (detailId != null) {
      final matchedById = montiByDetailId[detailId];
      if (matchedById != null) {
        return matchedById;
      }
    }
    if (hribiEntry.sourceOrder < montiEntries.length) {
      return montiEntries[hribiEntry.sourceOrder];
    }
    return null;
  }

  Future<_SloveniaHribiSourcePeakListArtifacts> _runNormal({
    required bool refreshCache,
  }) async {
    final rows = <SloveniaHribiSourcePeakListRow>[];
    final repairEntries = <SloveniaHribiSourcePeakListRepairEntry>[];
    final summaries = <String>[];
    _reportProgress(
      'Crawling ${rangeConfigurations.length} configured Slovenia ranges.',
    );
    for (var index = 0; index < rangeConfigurations.length; index++) {
      final range = rangeConfigurations[index];
      _reportProgress(
        '[${index + 1}/${rangeConfigurations.length}] ${range.mountainRangeLabel}',
      );
      final rangeArtifacts = await _processWholeRange(
        range: range,
        refreshCache: refreshCache,
      );
      rows.addAll(rangeArtifacts.rows);
      repairEntries.addAll(rangeArtifacts.repairEntries);
      summaries.addAll(rangeArtifacts.summaries);
    }
    return _SloveniaHribiSourcePeakListArtifacts(
      rows: rows,
      repairEntries: repairEntries,
      summaries: summaries,
    );
  }

  Future<_SloveniaHribiSourcePeakListArtifacts> _runRepair({
    required _SloveniaHribiSourcePeakListSnapshot latestSnapshot,
    required bool refreshCache,
  }) async {
    final rows = List<SloveniaHribiSourcePeakListRow>.from(latestSnapshot.rows);
    final nextRepairEntries = <SloveniaHribiSourcePeakListRepairEntry>[];
    final summaries = <String>[];
    final processedRangeUrls = <String>{};
    final rangeRepairs = latestSnapshot.repairEntries
        .where((entry) => entry.kind == 'range')
        .length;
    final peakRepairs = latestSnapshot.repairEntries
        .where((entry) => entry.kind == 'peak')
        .length;
    _reportProgress(
      'Repairing V${latestSnapshot.version} with $rangeRepairs ranges and $peakRepairs peaks.',
    );

    final rangeRepairEntries = latestSnapshot.repairEntries
        .where((entry) => entry.kind == 'range')
        .toList(growable: false);
    for (var index = 0; index < rangeRepairEntries.length; index++) {
      final repairEntry = rangeRepairEntries[index];
      final range = _rangeForRepairEntry(repairEntry);
      if (range == null) {
        nextRepairEntries.add(repairEntry);
        continue;
      }
      if (!processedRangeUrls.add(range.hribiRangeUrl)) {
        continue;
      }

      _reportProgress(
        '[${index + 1}/${rangeRepairEntries.length}] Rebuilding ${range.mountainRangeLabel}',
      );

      final rangeArtifacts = await _processWholeRange(
        range: range,
        refreshCache: refreshCache,
      );
      summaries.addAll(rangeArtifacts.summaries);
      _replaceRangeRows(rows, range.hribiRangeUrl, rangeArtifacts.rows);
      nextRepairEntries.addAll(rangeArtifacts.repairEntries);
    }

    final peakRepairEntries = latestSnapshot.repairEntries
        .where((entry) => entry.kind == 'peak')
        .toList(growable: false);
    for (var index = 0; index < peakRepairEntries.length; index++) {
      final repairEntry = peakRepairEntries[index];
      final range = _rangeForRepairEntry(repairEntry);
      if (range == null) {
        nextRepairEntries.add(repairEntry);
        continue;
      }
      if (processedRangeUrls.contains(range.hribiRangeUrl)) {
        continue;
      }

      _reportProgress(
        '[${index + 1}/${peakRepairEntries.length}] ${repairEntry.name}',
      );

      final baselineRow = _rowByDetailUrl(rows, repairEntry.detailUrl);
      final peakOutcome = await _processPeakRepair(
        range: range,
        repairEntry: repairEntry,
        baselineRow: baselineRow,
        refreshCache: refreshCache,
      );
      summaries.addAll(peakOutcome.summaries);
      if (peakOutcome.row != null) {
        _upsertRow(rows, peakOutcome.row!);
      }
      if (peakOutcome.repairEntry != null) {
        nextRepairEntries.add(peakOutcome.repairEntry!);
      }
    }

    return _SloveniaHribiSourcePeakListArtifacts(
      rows: rows,
      repairEntries: nextRepairEntries,
      summaries: summaries,
    );
  }

  Future<_SloveniaHribiSourcePeakListArtifacts> _processWholeRange({
    required SloveniaHribiSourceRangeConfig range,
    required bool refreshCache,
  }) async {
    final rows = <SloveniaHribiSourcePeakListRow>[];
    final repairEntries = <SloveniaHribiSourcePeakListRepairEntry>[];
    final summaries = <String>[];

    final hribiRangeHtml = await _tryLoadPage(
      url: range.hribiRangeUrl,
      kind: 'range',
      rangeUrl: range.hribiRangeUrl,
      detailUrl: '',
      name: range.mountainRangeLabel,
      repairEntries: repairEntries,
      summaries: summaries,
      summaryPrefix: 'Range failed',
      refreshCache: refreshCache,
    );
    if (hribiRangeHtml == null) {
      return _SloveniaHribiSourcePeakListArtifacts(
        rows: rows,
        repairEntries: repairEntries,
        summaries: summaries,
      );
    }

    late final List<SloveniaHribiSourceRangeEntry> hribiEntries;
    try {
      hribiEntries = htmlParser.parseHribiRangeEntries(hribiRangeHtml);
    } on Object catch (error) {
      repairEntries.add(
        SloveniaHribiSourcePeakListRepairEntry(
          kind: 'range',
          rangeUrl: range.hribiRangeUrl,
          detailUrl: '',
          name: range.mountainRangeLabel,
          missingFields: const [],
          lastError: error.toString(),
        ),
      );
      summaries.add(
        'Range failed for ${range.mountainRangeLabel}: ${error.toString()}',
      );
      return _SloveniaHribiSourcePeakListArtifacts(
        rows: rows,
        repairEntries: repairEntries,
        summaries: summaries,
      );
    }

    List<SloveniaHribiSourceMontiEntry> montiEntries = const [];
    var montiRangeError = '';
    final montiRangeHtml = await _tryLoadPage(
      url: range.montiRangeUrl,
      kind: 'range',
      rangeUrl: range.montiRangeUrl,
      detailUrl: '',
      name: range.mountainRangeLabel,
      repairEntries: repairEntries,
      summaries: summaries,
      summaryPrefix: 'Monti enrichment range failed',
      refreshCache: refreshCache,
    );
    if (montiRangeHtml != null) {
      try {
        montiEntries = htmlParser.parseMontiRangeEntries(montiRangeHtml);
      } on Object catch (error) {
        montiRangeError = error.toString();
        repairEntries.add(
          SloveniaHribiSourcePeakListRepairEntry(
            kind: 'range',
            rangeUrl: range.montiRangeUrl,
            detailUrl: '',
            name: range.mountainRangeLabel,
            missingFields: const [],
            lastError: montiRangeError,
          ),
        );
        summaries.add(
          'Monti enrichment range failed for ${range.mountainRangeLabel}: $montiRangeError',
        );
      }
    } else {
      final matchingRangeRepair = repairEntries.isEmpty
          ? null
          : repairEntries.last;
      if (matchingRangeRepair != null &&
          matchingRangeRepair.kind == 'range' &&
          matchingRangeRepair.rangeUrl == range.montiRangeUrl) {
        montiRangeError = matchingRangeRepair.lastError;
      }
    }

    final montiByDetailId = {
      for (final entry in montiEntries)
        if (entry.detailId != null) entry.detailId!: entry,
    };

    _reportProgress(
      'Processing ${hribiEntries.length} peaks from ${range.mountainRangeLabel}.',
    );

    for (var index = 0; index < hribiEntries.length; index++) {
      final hribiEntry = hribiEntries[index];
      _reportProgress(
        '  [${index + 1}/${hribiEntries.length}] ${hribiEntry.name}',
      );
      final peakOutcome = await _processPeakEntry(
        range: range,
        hribiEntry: hribiEntry,
        montiEntries: montiEntries,
        montiByDetailId: montiByDetailId,
        montiRangeError: montiRangeError,
        refreshCache: refreshCache,
      );
      if (peakOutcome.row != null) {
        rows.add(peakOutcome.row!);
      }
      if (peakOutcome.repairEntry != null) {
        repairEntries.add(peakOutcome.repairEntry!);
      }
      summaries.addAll(peakOutcome.summaries);
    }

    return _SloveniaHribiSourcePeakListArtifacts(
      rows: rows,
      repairEntries: repairEntries,
      summaries: summaries,
    );
  }

  Future<_SloveniaHribiSourcePeakRepairOutcome> _processPeakEntry({
    required SloveniaHribiSourceRangeConfig range,
    required SloveniaHribiSourceRangeEntry hribiEntry,
    required List<SloveniaHribiSourceMontiEntry> montiEntries,
    required Map<int, SloveniaHribiSourceMontiEntry> montiByDetailId,
    required String montiRangeError,
    required bool refreshCache,
  }) async {
    final repairEntries = <SloveniaHribiSourcePeakListRepairEntry>[];
    final summaries = <String>[];

    final detailHtml = await _tryLoadPage(
      url: hribiEntry.detailUrl,
      kind: 'peak',
      rangeUrl: range.hribiRangeUrl,
      detailUrl: hribiEntry.detailUrl,
      name: hribiEntry.name,
      repairEntries: repairEntries,
      summaries: summaries,
      summaryPrefix: 'Peak detail failed before confirmation',
      refreshCache: refreshCache,
    );
    if (detailHtml == null) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: null,
        repairEntry: repairEntries.isEmpty ? null : repairEntries.single,
        summaries: summaries,
      );
    }

    late final SloveniaHribiSourcePeakDetail detail;
    try {
      detail = htmlParser.parseHribiDetail(
        detailHtml,
        fallbackName: hribiEntry.name,
      );
    } on Object catch (error) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: null,
        repairEntry: SloveniaHribiSourcePeakListRepairEntry(
          kind: 'peak',
          rangeUrl: range.hribiRangeUrl,
          detailUrl: hribiEntry.detailUrl,
          name: hribiEntry.name,
          missingFields: const [],
          lastError: error.toString(),
        ),
        summaries: [
          ...summaries,
          'Peak detail failed before confirmation for ${hribiEntry.name}: ${error.toString()}',
        ],
      );
    }

    if (_cleanText(detail.typeText).isEmpty) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: null,
        repairEntry: null,
        summaries: summaries,
      );
    }

    if (!normalizer.isPeakType(detail.typeText)) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: null,
        repairEntry: null,
        summaries: summaries,
      );
    }

    final montiEntry = _resolveMontiEntry(
      hribiEntry: hribiEntry,
      montiByDetailId: montiByDetailId,
      montiEntries: montiEntries,
    );
    final built = _buildRowAndRepair(
      range: range,
      hribiEntry: hribiEntry,
      detail: detail,
      montiEntry: montiEntry,
      montiRangeError: montiRangeError,
    );
    return _SloveniaHribiSourcePeakRepairOutcome(
      row: built.$1,
      repairEntry: built.$2,
      summaries: built.$3.isEmpty ? summaries : [...summaries, built.$3],
    );
  }

  Future<_SloveniaHribiSourcePeakRepairOutcome> _processPeakRepair({
    required SloveniaHribiSourceRangeConfig range,
    required SloveniaHribiSourcePeakListRepairEntry repairEntry,
    required SloveniaHribiSourcePeakListRow? baselineRow,
    required bool refreshCache,
  }) async {
    final summaries = <String>[];
    final hribiRangeHtml = await _loadPageForRepairTarget(
      url: range.hribiRangeUrl,
      refreshCache: refreshCache,
    );
    if (hribiRangeHtml == null) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: baselineRow,
        repairEntry: repairEntry,
        summaries: summaries,
      );
    }

    late final List<SloveniaHribiSourceRangeEntry> hribiEntries;
    try {
      hribiEntries = htmlParser.parseHribiRangeEntries(hribiRangeHtml);
    } on Object catch (error) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: baselineRow,
        repairEntry: SloveniaHribiSourcePeakListRepairEntry(
          kind: 'peak',
          rangeUrl: repairEntry.rangeUrl,
          detailUrl: repairEntry.detailUrl,
          name: repairEntry.name,
          missingFields: repairEntry.missingFields,
          lastError: error.toString(),
        ),
        summaries: summaries,
      );
    }

    SloveniaHribiSourceRangeEntry? hribiEntry;
    for (final entry in hribiEntries) {
      if (entry.detailUrl == repairEntry.detailUrl) {
        hribiEntry = entry;
        break;
      }
    }
    if (hribiEntry == null) {
      return _SloveniaHribiSourcePeakRepairOutcome(
        row: baselineRow,
        repairEntry: repairEntry,
        summaries: summaries,
      );
    }

    List<SloveniaHribiSourceMontiEntry> montiEntries = const [];
    var montiRangeError = '';
    final montiRangeHtml = await _loadPageForRepairTarget(
      url: range.montiRangeUrl,
      refreshCache: refreshCache,
    );
    if (montiRangeHtml != null) {
      try {
        montiEntries = htmlParser.parseMontiRangeEntries(montiRangeHtml);
      } on Object catch (error) {
        montiRangeError = error.toString();
      }
    }
    final montiByDetailId = {
      for (final entry in montiEntries)
        if (entry.detailId != null) entry.detailId!: entry,
    };
    final peakOutcome = await _processPeakEntry(
      range: range,
      hribiEntry: hribiEntry,
      montiEntries: montiEntries,
      montiByDetailId: montiByDetailId,
      montiRangeError: montiRangeError,
      refreshCache: refreshCache,
    );
    final repair = peakOutcome.repairEntry;
    if (repair == null) {
      return peakOutcome;
    }
    return _SloveniaHribiSourcePeakRepairOutcome(
      row: peakOutcome.row ?? baselineRow,
      repairEntry: repair,
      summaries: peakOutcome.summaries,
    );
  }

  static Directory _defaultOutputDirectoryResolver() {
    return Directory(p.join(Directory.current.path, 'assets', 'peaks'));
  }

  static Directory _defaultCacheDirectoryResolver() {
    return Directory(
      p.join(Directory.current.path, '.cache', 'hribi-source-peaks'),
    );
  }

  static SloveniaHribiSourcePageLoader _buildDefaultPageLoader(
    http.Client client,
  ) {
    return (Uri uri) async {
      final response = await client.get(uri);
      if (response.statusCode != 200) {
        throw HttpException(
          'Failed to load $uri: HTTP ${response.statusCode}',
          uri: uri,
        );
      }
      return response.body;
    };
  }

  static int _nextVersion(Directory outputDirectory) {
    final versionPattern = RegExp(
      '^${RegExp.escape(sloveniaRankedPeakListBaseName)}-V(\\d+)(?:\\.csv|\\.review\\.csv|\\.repair\\.csv|\\.state\\.json)'
      r'$',
    );
    var maxVersion = 0;
    for (final entity in outputDirectory.listSync()) {
      if (entity is! File) {
        continue;
      }
      final match = versionPattern.firstMatch(p.basename(entity.path));
      if (match == null) {
        continue;
      }
      final version = int.tryParse(match.group(1)!);
      if (version != null && version > maxVersion) {
        maxVersion = version;
      }
    }
    return maxVersion + 1;
  }

  _SloveniaHribiSourcePeakListSnapshot? _loadLatestSnapshot({
    required bool requireRepairFile,
  }) {
    final outputDirectory = _outputDirectoryResolver();
    if (!outputDirectory.existsSync()) {
      return null;
    }

    final versionPattern = RegExp(
      '^${RegExp.escape(sloveniaRankedPeakListBaseName)}-V(\\d+)\\.repair\\.csv'
      r'$',
    );
    final statePattern = RegExp(
      '^${RegExp.escape(sloveniaRankedPeakListBaseName)}-V(\\d+)\\.state\\.json'
      r'$',
    );
    final availableVersions = <int>[];
    for (final entity in outputDirectory.listSync()) {
      if (entity is! File) {
        continue;
      }
      final basename = p.basename(entity.path);
      final match = requireRepairFile
          ? versionPattern.firstMatch(basename)
          : statePattern.firstMatch(basename);
      if (match == null) {
        continue;
      }
      final version = int.tryParse(match.group(1)!);
      if (version != null) {
        availableVersions.add(version);
      }
    }
    if (availableVersions.isEmpty) {
      return null;
    }
    availableVersions.sort();

    for (final version in availableVersions.reversed) {
      final csvPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.csv',
      );
      final reviewPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.review.csv',
      );
      final repairPath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.repair.csv',
      );
      final statePath = p.join(
        outputDirectory.path,
        '$sloveniaRankedPeakListBaseName-V$version.state.json',
      );
      if (!File(csvPath).existsSync() ||
          !File(reviewPath).existsSync() ||
          !File(statePath).existsSync()) {
        continue;
      }
      if (requireRepairFile && !File(repairPath).existsSync()) {
        continue;
      }

      final state =
          jsonDecode(File(statePath).readAsStringSync())
              as Map<String, dynamic>;
      final rawRows = (state['Rows'] as List<dynamic>? ?? const <dynamic>[])
          .cast<Map<String, dynamic>>();
      final rawRepairEntries =
          (state['RepairEntries'] as List<dynamic>? ?? const <dynamic>[])
              .cast<Map<String, dynamic>>();
      final csvText = File(csvPath).readAsStringSync();
      final reviewText = File(reviewPath).readAsStringSync();
      final repairText = File(repairPath).existsSync()
          ? File(repairPath).readAsStringSync()
          : _buildRepairCsvText(const []);
      return _SloveniaHribiSourcePeakListSnapshot(
        version: version,
        rows: rawRows
            .map(SloveniaHribiSourcePeakListRow.fromStateJson)
            .toList(growable: false),
        repairEntries: rawRepairEntries
            .map(SloveniaHribiSourcePeakListRepairEntry.fromStateJson)
            .toList(growable: false),
        csvPath: csvPath,
        reviewPath: reviewPath,
        repairPath: repairPath,
        statePath: statePath,
        csvText: csvText,
        reviewText: reviewText,
        repairText: repairText,
      );
    }

    return null;
  }

  Future<String?> _tryLoadPage({
    required String url,
    required String kind,
    required String rangeUrl,
    required String detailUrl,
    required String name,
    required List<SloveniaHribiSourcePeakListRepairEntry> repairEntries,
    required List<String> summaries,
    required String summaryPrefix,
    required bool refreshCache,
  }) async {
    try {
      return await _loadPage(Uri.parse(url), refreshCache: refreshCache);
    } on Object catch (error) {
      repairEntries.add(
        SloveniaHribiSourcePeakListRepairEntry(
          kind: kind,
          rangeUrl: rangeUrl,
          detailUrl: detailUrl,
          name: name,
          missingFields: const [],
          lastError: error.toString(),
        ),
      );
      summaries.add('$summaryPrefix for $name: ${error.toString()}');
      return null;
    }
  }

  Future<String?> _loadPageForRepairTarget({
    required String url,
    required bool refreshCache,
  }) async {
    try {
      return await _loadPage(Uri.parse(url), refreshCache: refreshCache);
    } on Object {
      return null;
    }
  }

  Future<String> _loadPage(Uri uri, {required bool refreshCache}) async {
    final cacheFile = _cacheFileForUri(uri);
    if (!refreshCache && cacheFile.existsSync()) {
      return cacheFile.readAsStringSync();
    }

    final response = await _basePageLoader(uri);
    cacheFile.parent.createSync(recursive: true);
    cacheFile.writeAsStringSync(response);
    return response;
  }

  File _cacheFileForUri(Uri uri) {
    final digest = sha1.convert(utf8.encode(uri.toString())).toString();
    return File(p.join(_cacheDirectoryResolver().path, '$digest.html'));
  }

  (
    SloveniaHribiSourcePeakListRow,
    SloveniaHribiSourcePeakListRepairEntry?,
    String,
  )
  _buildRowAndRepair({
    required SloveniaHribiSourceRangeConfig range,
    required SloveniaHribiSourceRangeEntry hribiEntry,
    required SloveniaHribiSourcePeakDetail detail,
    required SloveniaHribiSourceMontiEntry? montiEntry,
    required String montiRangeError,
  }) {
    final country = normalizer.normalizeCountry(detail.countryText);
    final coordinates = normalizer.normalizeCoordinates(detail.coordinatesText);
    final altitude = normalizer.normalizeAltitude(detail.altitudeText);
    final popularity = normalizer.normalizePopularity(detail.popularityText);
    final missingFields = <String>[];
    if (country.isEmpty) {
      missingFields.add('Country');
    }
    if (altitude.isEmpty) {
      missingFields.add('Altitude');
    }
    if (coordinates.latitude.isEmpty) {
      missingFields.add('Latitude');
    }
    if (coordinates.longitude.isEmpty) {
      missingFields.add('Longitude');
    }
    if (popularity.isEmpty) {
      missingFields.add('Popularity');
    }
    missingFields.addAll(
      _missingMontiFields(normalizedCountry: country, montiEntry: montiEntry),
    );
    final names = normalizer.resolveNames(
      hribiName: detail.name,
      montiName: montiEntry?.name ?? '',
      normalizedCountry: country,
    );
    final row = SloveniaHribiSourcePeakListRow(
      name: names.name,
      altName: names.altName,
      country: country,
      mountainRange: range.mountainRangeLabel,
      altitude: altitude,
      latitude: coordinates.latitude,
      longitude: coordinates.longitude,
      popularity: popularity,
      rangeOrder: range.order,
      sourceOrder: hribiEntry.sourceOrder,
      rangeUrl: range.hribiRangeUrl,
      hribiDetailUrl: hribiEntry.detailUrl,
      montiDetailUrl: montiEntry?.detailUrl ?? '',
    );
    if (missingFields.isEmpty) {
      return (row, null, '');
    }
    return (
      row,
      SloveniaHribiSourcePeakListRepairEntry(
        kind: 'peak',
        rangeUrl: range.hribiRangeUrl,
        detailUrl: hribiEntry.detailUrl,
        name: row.name,
        missingFields: missingFields,
        lastError: _buildPeakRepairError(
          montiRangeError: montiRangeError,
          montiEntry: montiEntry,
        ),
      ),
      'Peak written with missing fields: ${row.name} (${missingFields.join(', ')})',
    );
  }

  SloveniaHribiSourceRangeConfig? _rangeForRepairEntry(
    SloveniaHribiSourcePeakListRepairEntry repairEntry,
  ) {
    for (final range in rangeConfigurations) {
      if (range.hribiRangeUrl == repairEntry.rangeUrl ||
          range.montiRangeUrl == repairEntry.rangeUrl) {
        return range;
      }
    }
    return null;
  }

  void _replaceRangeRows(
    List<SloveniaHribiSourcePeakListRow> rows,
    String rangeUrl,
    List<SloveniaHribiSourcePeakListRow> replacements,
  ) {
    rows.removeWhere((row) => row.rangeUrl == rangeUrl);
    rows.addAll(replacements);
  }

  SloveniaHribiSourcePeakListRow? _rowByDetailUrl(
    List<SloveniaHribiSourcePeakListRow> rows,
    String detailUrl,
  ) {
    for (final row in rows) {
      if (row.hribiDetailUrl == detailUrl) {
        return row;
      }
    }
    return null;
  }

  void _upsertRow(
    List<SloveniaHribiSourcePeakListRow> rows,
    SloveniaHribiSourcePeakListRow row,
  ) {
    final index = rows.indexWhere(
      (existing) => existing.hribiDetailUrl == row.hribiDetailUrl,
    );
    if (index == -1) {
      rows.add(row);
      return;
    }
    rows[index] = row;
  }

  List<SloveniaHribiSourcePeakListRow> _sortedRows(
    List<SloveniaHribiSourcePeakListRow> rows,
  ) {
    final sorted = List<SloveniaHribiSourcePeakListRow>.from(rows);
    sorted.sort((a, b) {
      final rangeComparison = a.rangeOrder.compareTo(b.rangeOrder);
      if (rangeComparison != 0) {
        return rangeComparison;
      }
      return a.sourceOrder.compareTo(b.sourceOrder);
    });
    return sorted;
  }

  String _buildRankedCsvText(List<SloveniaRankedPeakListCsvRow> rows) {
    return const CsvEncoder(lineDelimiter: '\n').convert([
      sloveniaRankedPeakListCsvHeader,
      ...rows.map((row) => row.toCsvRow()),
    ]);
  }

  String _buildReviewCsvText(List<SloveniaCorrelationReviewCsvRow> rows) {
    return const CsvEncoder(lineDelimiter: '\n').convert([
      sloveniaCorrelationReviewCsvHeader,
      ...rows.map((row) => row.toCsvRow()),
    ]);
  }

  String _buildRepairCsvText(
    List<SloveniaHribiSourcePeakListRepairEntry> repairEntries,
  ) {
    return const CsvEncoder(lineDelimiter: '\n').convert([
      sloveniaHribiSourcePeakListRepairCsvHeader,
      ...repairEntries.map((entry) => entry.toCsvRow()),
    ]);
  }

  String _buildStateJson({
    required int version,
    required List<SloveniaHribiSourcePeakListRow> rows,
    required List<SloveniaRankedPeakListCsvRow> canonicalRows,
    required List<SloveniaCorrelationReviewCsvRow> reviewRows,
    required List<SloveniaHribiSourcePeakListRepairEntry> repairEntries,
    required String csvPath,
    required String reviewPath,
    required String repairPath,
    required int tieWindowMeters,
  }) {
    final reviewReasonCounts = <String, int>{};
    for (final row in reviewRows) {
      reviewReasonCounts.update(
        row.correlationReason,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return jsonEncode({
      'BaseName': sloveniaRankedPeakListBaseName,
      'Version': version,
      'TieWindowMeters': tieWindowMeters,
      'Artifacts': {
        'RankedCsv': p.basename(csvPath),
        'ReviewCsv': p.basename(reviewPath),
        'RepairCsv': p.basename(repairPath),
      },
      'Correlation': {
        'CanonicalRowCount': canonicalRows.length,
        'ReviewRowCount': reviewRows.length,
        'ReviewReasonCounts': reviewReasonCounts,
      },
      'Rows': rows.map((row) => row.toStateJson()).toList(growable: false),
      'RepairEntries': repairEntries
          .map((entry) => entry.toStateJson())
          .toList(growable: false),
    });
  }

  List<String> _buildCorrelationSummaries({
    required SloveniaPeakCorrelationOutput correlationOutput,
    required int tieWindowMeters,
  }) {
    final reviewReasonCounts = <String, int>{};
    for (final row in correlationOutput.reviewRows) {
      reviewReasonCounts.update(
        row.correlationReason,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    final reviewSummaryText = reviewReasonCounts.entries.isEmpty
        ? 'no review rows'
        : (() {
            final sortedEntries = reviewReasonCounts.entries.toList(
              growable: false,
            )..sort((left, right) => left.key.compareTo(right.key));
            return sortedEntries
                .map((entry) => '${entry.key}:${entry.value}')
                .join(', ');
          })();
    return [
      'Correlation split with tie window ${tieWindowMeters}m: '
          '${correlationOutput.canonicalRows.length} canonical, '
          '${correlationOutput.reviewRows.length} review ($reviewSummaryText)',
    ];
  }

  void _reportProgress(String message) {
    _onProgress?.call(message);
  }

  List<String> _missingMontiFields({
    required String normalizedCountry,
    required SloveniaHribiSourceMontiEntry? montiEntry,
  }) {
    if (montiEntry != null) {
      return const [];
    }

    final countryParts = normalizedCountry
        .split(',')
        .map(_cleanText)
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    if (countryParts.length == 1 && countryParts.single == 'Slovenia') {
      return const ['Alt Name'];
    }
    if (countryParts.isEmpty) {
      return const ['Alt Name'];
    }
    return const ['Name', 'Alt Name'];
  }

  String _buildPeakRepairError({
    required String montiRangeError,
    required SloveniaHribiSourceMontiEntry? montiEntry,
  }) {
    if (montiEntry != null) {
      return '';
    }
    if (montiRangeError.isNotEmpty) {
      return montiRangeError;
    }
    return 'Missing monti.uno enrichment entry';
  }
}

int? _detailIdFromUrl(String url) {
  final match = RegExp(r'/(\d+)$').firstMatch(url);
  return match == null ? null : int.tryParse(match.group(1)!);
}

String _cleanText(String? value) {
  if (value == null) {
    return '';
  }
  return value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
