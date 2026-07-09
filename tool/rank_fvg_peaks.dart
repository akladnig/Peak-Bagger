import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/polygon_geometry.dart';

const _defaultRegionKey = 'fvg';
const _defaultTopCount = 500;
const _defaultDelayMs = 1200;
const _saveInterval = 100;
const _platformRatingBonusMultiplier = 2.0;
const _httpRequestTimeout = Duration(seconds: 30);
const _jinaDuckDuckGoPrefix =
    'https://r.jina.ai/http://https://duckduckgo.com/html/';
const _nominatimReverseUrl = 'https://nominatim.openstreetmap.org/reverse';
const _userAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
    'AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/126.0.0.0 Safari/537.36';
String get _usage {
  final regionKeys = _builtInRegionProfiles.keys.join(', ');
  return '''
Ranks region peaks by likely climbing popularity from web search.

What it does:
- loads a region peak dataset
- filters peaks inside region polygons
- runs a mirrored DuckDuckGo HTML search for each peak
- runs a second pass on top peaks missing region-specific platform signals
- scores peaks from route-source domains, route keywords, and light mountain tie-breakers
- writes ranked JSON and CSV outputs

Usage:
  dart run tool/rank_fvg_peaks.dart
  dart run tool/rank_fvg_peaks.dart --region-key slovenia
  dart run tool/rank_fvg_peaks.dart --top 200 --max-candidates 700
  dart run tool/rank_fvg_peaks.dart --second-pass-only
  dart run tool/rank_fvg_peaks.dart --offline
  dart run tool/rank_fvg_peaks.dart --refresh-cache --delay-ms 1500

Options:
  --region-key KEY     Built-in region key. Default: $_defaultRegionKey
                       Available: $regionKeys
  --top N              Number of ranked peaks to write. Default: 500
  --max-candidates N   Only search the top N prefiltered candidates by elevation/prominence
  --delay-ms N         Delay between live searches. Default: 1200
  --cache-dir PATH     Cache directory. Default: region-specific
  --output-json PATH   JSON output path. Default: region-specific
  --output-csv PATH    CSV output path. Default: region-specific
  --output-lesser-csv [PATH]
                      Write ranked peaks after the top set. Default path: region-specific
  --second-pass-only   Reopen the existing JSON output and rerun only the second pass
  --offline            Use cache only; do not fetch live search results
  --refresh-cache      Ignore cache and refetch search results
  --help, -h           Show this help

Notes:
  - slovenia is supported out of the box.
  - veneto expects assets/polygons/veneto.poly to exist.
''';
}

const _baseWeightedDomains = <String, ({double score, String label})>{
  'cai.it': (score: 5.0, label: 'CAI'),
  'gulliver.it': (score: 5.0, label: 'Gulliver'),
  'vienormali.it': (score: 4.5, label: 'Vie Normali'),
  'wikiloc.com': (score: 4.0, label: 'Wikiloc'),
  'komoot.com': (score: 4.0, label: 'Komoot'),
  'outdooractive.com': (score: 4.0, label: 'Outdooractive'),
  'ferrate365.it': (score: 3.5, label: 'Ferrate365'),
  'inmont.it': (score: 3.5, label: 'Guide Alpine InMont'),
  'ormeverticali.it': (score: 3.5, label: 'Orme Verticali'),
  'planetmountain.com': (score: 3.5, label: 'PlanetMountain'),
  'peakvisor.com': (score: 3.0, label: 'PeakVisor'),
  'summitpost.org': (score: 3.0, label: 'SummitPost'),
  'abcdolomiti.com': (score: 3.0, label: 'ABC Dolomiti'),
  'andreabasso.it': (score: 2.5, label: 'Andrea Basso'),
  'alpinistiinvista.com': (score: 2.5, label: 'Alpinisti in Vista'),
  'wikipedia.org': (score: 1.0, label: 'Wikipedia'),
};

const _fvgWeightedDomains = <String, ({double score, String label})>{
  ..._baseWeightedDomains,
  'cai-fvg.it': (score: 6.0, label: 'CAI FVG'),
  'camminateinfriuli.it': (score: 4.5, label: 'Camminate in Friuli'),
  'camminatefvg.it': (score: 4.5, label: 'Camminate in Friuli'),
};

const _sloveniaWeightedDomains = <String, ({double score, String label})>{
  ..._baseWeightedDomains,
  'hribi.net': (score: 5.5, label: 'Hribi'),
  'pzs.si': (score: 5.0, label: 'PZS'),
  'slotrips.si': (score: 4.5, label: 'Slotrips'),
  'gore-ljudje.net': (score: 3.5, label: 'Gore Ljudje'),
  'ferata.si': (score: 3.5, label: 'Ferata.si'),
};

const _genericRouteKeywords = <String>[
  'escursione',
  'sentiero',
  'itinerario',
  'anello',
  'via normale',
  'ferrata',
  'salita',
  'traccia gps',
  'route',
  'hike',
  'climb',
  'summit',
  'rifugio',
];

const _sloveniaRouteKeywords = <String>[
  ..._genericRouteKeywords,
  'pohod',
  'tura',
  'vzpon',
  'planinska pot',
  'gorska pot',
  'koča',
];

const _genericPrimaryQueryKeywords = <String>[
  'escursione',
  'sentiero',
  'anello',
  'itinerario',
  'via normale',
];

const _sloveniaPrimaryQueryKeywords = <String>[
  'pohod',
  'tura',
  'vzpon',
  'planinska pot',
  'ferata',
];

const _genericScenicKeywords = <String>[
  'panorama',
  'panoramico',
  'vista',
  'iconic',
  'simbolo',
  'spectacular',
  'classica',
  'must',
];

const _sloveniaScenicKeywords = <String>[
  ..._genericScenicKeywords,
  'razgled',
  'razgleden',
  'panoramski',
];

const _fvgProvinceIsoNames = <String, String>{
  'IT-UD': 'Udine',
  'IT-PN': 'Pordenone',
  'IT-GO': 'Gorizia',
  'IT-TS': 'Trieste',
};

const _venetoProvinceIsoNames = <String, String>{
  'IT-BL': 'Belluno',
  'IT-TV': 'Treviso',
  'IT-VI': 'Vicenza',
  'IT-VR': 'Verona',
  'IT-PD': 'Padova',
  'IT-VE': 'Venezia',
  'IT-RO': 'Rovigo',
};

const _fvgSecondPassRequiredDomains = <String>{
  'Komoot',
  'Outdooractive',
  'Gulliver',
};

const _sloveniaSecondPassRequiredDomains = <String>{
  'Komoot',
  'Outdooractive',
  'Hribi',
};

const _searchCharacterReplacements = <String, String>{
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'Ç': 'C',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ñ': 'N',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ý': 'Y',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ç': 'c',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'Č': 'C',
  'č': 'c',
  'Ć': 'C',
  'ć': 'c',
  'Đ': 'D',
  'đ': 'd',
  'Š': 'S',
  'š': 's',
  'Ž': 'Z',
  'ž': 'z',
};

const _genericMountainGroupAliases = <String, List<String>>{
  'Friulian Dolomites': [
    'dolomiti friulane',
    'friulian dolomites',
    'dolomiti d\'oltrepiave',
    'dolomites of d\'oltrepiave',
    'preti - duranno',
  ],
  'Carnic Alps': [
    'alpi carniche',
    'carnic alps',
    'carniche',
    'karnische alpen',
  ],
  'Julian Alps': ['alpi giulie', 'julian alps', 'julische alpen'],
  'Carnic Prealps': ['prealpi carniche', 'carnic prealps'],
  'Julian Prealps': ['prealpi giulie', 'julian prealps'],
};

const _sloveniaMountainGroupAliases = <String, List<String>>{
  ..._genericMountainGroupAliases,
  'Kamnik-Savinja Alps': [
    'kamniško-savinjsk',
    'kamnisko-savinjsk',
    'kamnik-savinja',
    'kamnik savinja',
    'kamnik savinja alps',
  ],
  'Karawanks': ['karavanke', 'karawanks'],
  'Pohorje': ['pohorje'],
};

const _knownItalianLocationSignals = <String>[
  'abruzzo',
  'aosta',
  'aosta valley',
  'apulia',
  'basilicata',
  'calabria',
  'campania',
  'emilia romagna',
  'friuli venezia giulia',
  'lazio',
  'liguria',
  'lombardia',
  'lombardy',
  'marche',
  'molise',
  'piemonte',
  'piedmont',
  'puglia',
  'sardegna',
  'sardinia',
  'sicilia',
  'sicily',
  'south tyrol',
  'sudtirol',
  'trentino alto adige',
  'toscana',
  'tuscany',
  'umbria',
  'valle d aosta',
  'valle d\'aosta',
  'veneto',
  'agrigento',
  'alessandria',
  'ancona',
  'aosta',
  'arezzo',
  'ascoli piceno',
  'asti',
  'avellino',
  'bari',
  'barletta',
  'andria',
  'trani',
  'belluno',
  'benevento',
  'bergamo',
  'biella',
  'bologna',
  'bolzano',
  'bozen',
  'brescia',
  'brindisi',
  'cagliari',
  'caltanissetta',
  'campobasso',
  'caserta',
  'catania',
  'catanzaro',
  'chieti',
  'como',
  'cosenza',
  'cremona',
  'crotone',
  'cuneo',
  'enna',
  'ferrara',
  'firenze',
  'florence',
  'foggia',
  'forli',
  'cesena',
  'frosinone',
  'genoa',
  'genova',
  'grosseto',
  'imperia',
  'isernia',
  'la spezia',
  'l aquila',
  'l\'aquila',
  'latina',
  'lecce',
  'lecco',
  'livorno',
  'lodi',
  'lucca',
  'macerata',
  'mantova',
  'massa',
  'carrara',
  'matera',
  'messina',
  'milano',
  'milan',
  'modena',
  'monza',
  'brianza',
  'napoli',
  'naples',
  'novara',
  'nuoro',
  'oristano',
  'padova',
  'palermo',
  'parma',
  'pavia',
  'perugia',
  'pesaro',
  'urbino',
  'pescara',
  'piacenza',
  'pisa',
  'pistoia',
  'pordenone',
  'potenza',
  'prato',
  'ragusa',
  'ravenna',
  'reggio calabria',
  'reggio emilia',
  'rieti',
  'rimini',
  'roma',
  'rome',
  'rovigo',
  'salerno',
  'sassari',
  'savona',
  'siena',
  'siracusa',
  'sondrio',
  'taranto',
  'teramo',
  'terni',
  'torino',
  'turin',
  'trapani',
  'trento',
  'treviso',
  'trieste',
  'udine',
  'varese',
  'venezia',
  'venice',
  'verbania',
  'vercelli',
  'verona',
  'vibo valentia',
  'vicenza',
  'viterbo',
];

const _genericPeakNameTokens = <String>{
  'alta',
  'alto',
  'anticima',
  'bassa',
  'basso',
  'cima',
  'cime',
  'col',
  'colle',
  'croda',
  'est',
  'forcella',
  'grande',
  'il',
  'la',
  'lo',
  'monte',
  'nord',
  'ovest',
  'passo',
  'piccola',
  'piccolo',
  'piz',
  'pizzo',
  'punta',
  'quota',
  'rio',
  'rocca',
  'sasso',
  'sud',
  'torre',
  'val',
  'vetta',
  'via',
};

class _RegionProfile {
  const _RegionProfile({
    required this.key,
    required this.countryName,
    required this.regionName,
    required this.datasetPath,
    required this.polygonPaths,
    required this.defaultCacheDir,
    required this.defaultJsonOutputPath,
    required this.defaultCsvOutputPath,
    required this.defaultLesserCsvOutputPath,
    required this.duckDuckGoLocale,
    required this.acceptLanguage,
    required this.weightedDomains,
    required this.routeKeywords,
    required this.primaryQueryKeywords,
    required this.scenicKeywords,
    required this.provinceIsoNames,
    required this.nameKeyOrder,
    required this.mountainGroupAliases,
    required this.secondPassRequiredDomains,
    required this.preferredAuthorityDomainLabel,
    required this.highestPeakNeedles,
    required this.highestPeakNote,
    required this.allowedLocationSignals,
  });

  final String key;
  final String countryName;
  final String regionName;
  final String datasetPath;
  final List<String> polygonPaths;
  final String defaultCacheDir;
  final String defaultJsonOutputPath;
  final String defaultCsvOutputPath;
  final String defaultLesserCsvOutputPath;
  final String duckDuckGoLocale;
  final String acceptLanguage;
  final Map<String, ({double score, String label})> weightedDomains;
  final List<String> routeKeywords;
  final List<String> primaryQueryKeywords;
  final List<String> scenicKeywords;
  final Map<String, String> provinceIsoNames;
  final List<String> nameKeyOrder;
  final Map<String, List<String>> mountainGroupAliases;
  final Set<String> secondPassRequiredDomains;
  final String? preferredAuthorityDomainLabel;
  final List<String> highestPeakNeedles;
  final String? highestPeakNote;
  final List<String> allowedLocationSignals;
}

const _builtInRegionProfiles = <String, _RegionProfile>{
  'fvg': _RegionProfile(
    key: 'fvg',
    countryName: 'Italy',
    regionName: 'Friuli Venezia Giulia',
    datasetPath: 'assets/peaks/italy-nord-est-peaks.json',
    polygonPaths: [
      'assets/polygons/friuli-venezia-giulia-mainland.poly',
      'assets/polygons/friuli-venezia-giulia-islet.poly',
    ],
    defaultCacheDir: '.cache/fvg-peak-ranker',
    defaultJsonOutputPath: 'fvg-top-peaks.json',
    defaultCsvOutputPath: 'fvg-top-peaks.csv',
    defaultLesserCsvOutputPath: 'lesser_fvg_peaks.csv',
    duckDuckGoLocale: 'it-it',
    acceptLanguage: 'it-IT,it;q=0.9,en;q=0.8',
    weightedDomains: _fvgWeightedDomains,
    routeKeywords: _genericRouteKeywords,
    primaryQueryKeywords: _genericPrimaryQueryKeywords,
    scenicKeywords: _genericScenicKeywords,
    provinceIsoNames: _fvgProvinceIsoNames,
    nameKeyOrder: [
      'name:it',
      'name',
      'name:sl',
      'name:de',
      'name:fur',
      'alt_name',
    ],
    mountainGroupAliases: _genericMountainGroupAliases,
    secondPassRequiredDomains: _fvgSecondPassRequiredDomains,
    preferredAuthorityDomainLabel: 'CAI FVG',
    highestPeakNeedles: [
      'più alta del friuli',
      'highest in friuli venezia giulia',
      'highest peak in friuli venezia giulia',
    ],
    highestPeakNote: 'Highest peak in FVG',
    allowedLocationSignals: [
      'Friuli Venezia Giulia',
      'Friuli',
      'FVG',
      'Trieste',
      'Gorizia',
      'Udine',
      'Pordenone',
    ],
  ),
  'slovenia': _RegionProfile(
    key: 'slovenia',
    countryName: 'Slovenia',
    regionName: 'Slovenia',
    datasetPath: 'assets/peaks/slovenia-peaks.json',
    polygonPaths: ['assets/polygons/slovenia.poly'],
    defaultCacheDir: '.cache/slovenia-peak-ranker',
    defaultJsonOutputPath: 'slovenia-top-peaks.json',
    defaultCsvOutputPath: 'slovenia-top-peaks.csv',
    defaultLesserCsvOutputPath: 'lesser_slovenia_peaks.csv',
    duckDuckGoLocale: 'si-sl',
    acceptLanguage: 'sl-SI,sl;q=0.9,en;q=0.8',
    weightedDomains: _sloveniaWeightedDomains,
    routeKeywords: _sloveniaRouteKeywords,
    primaryQueryKeywords: _sloveniaPrimaryQueryKeywords,
    scenicKeywords: _sloveniaScenicKeywords,
    provinceIsoNames: {},
    nameKeyOrder: ['name:sl', 'name', 'name:it', 'name:de', 'alt_name'],
    mountainGroupAliases: _sloveniaMountainGroupAliases,
    secondPassRequiredDomains: _sloveniaSecondPassRequiredDomains,
    preferredAuthorityDomainLabel: 'Hribi',
    highestPeakNeedles: [
      'najvišji vrh slovenije',
      'najvisji vrh slovenije',
      'highest peak in slovenia',
    ],
    highestPeakNote: 'Highest peak in Slovenia',
    allowedLocationSignals: ['Slovenia', 'Slovenija'],
  ),
  'veneto': _RegionProfile(
    key: 'veneto',
    countryName: 'Italy',
    regionName: 'Veneto',
    datasetPath: 'assets/peaks/italy-nord-est-peaks.json',
    polygonPaths: ['assets/polygons/veneto.poly'],
    defaultCacheDir: '.cache/veneto-peak-ranker',
    defaultJsonOutputPath: 'veneto-top-peaks.json',
    defaultCsvOutputPath: 'veneto-top-peaks.csv',
    defaultLesserCsvOutputPath: 'lesser_veneto_peaks.csv',
    duckDuckGoLocale: 'it-it',
    acceptLanguage: 'it-IT,it;q=0.9,en;q=0.8',
    weightedDomains: _baseWeightedDomains,
    routeKeywords: _genericRouteKeywords,
    primaryQueryKeywords: _genericPrimaryQueryKeywords,
    scenicKeywords: _genericScenicKeywords,
    provinceIsoNames: _venetoProvinceIsoNames,
    nameKeyOrder: ['name:it', 'name', 'name:de', 'name:lld', 'alt_name'],
    mountainGroupAliases: _genericMountainGroupAliases,
    secondPassRequiredDomains: _fvgSecondPassRequiredDomains,
    preferredAuthorityDomainLabel: 'CAI',
    highestPeakNeedles: ['più alta del veneto', 'highest peak in veneto'],
    highestPeakNote: 'Highest peak in Veneto',
    allowedLocationSignals: [
      'Veneto',
      'Belluno',
      'Treviso',
      'Vicenza',
      'Verona',
      'Padova',
      'Venezia',
      'Rovigo',
    ],
  ),
};

late _RegionProfile _activeRegionProfile;

Map<String, ({double score, String label})> get _weightedDomains =>
    _activeRegionProfile.weightedDomains;

List<String> get _routeKeywords => _activeRegionProfile.routeKeywords;

List<String> get _primaryQueryKeywords =>
    _activeRegionProfile.primaryQueryKeywords;

List<String> get _scenicKeywords => _activeRegionProfile.scenicKeywords;

Map<String, String> get _provinceIsoNames =>
    _activeRegionProfile.provinceIsoNames;

List<String> get _nameKeyOrder => _activeRegionProfile.nameKeyOrder;

Map<String, List<String>> get _mountainGroupAliases =>
    _activeRegionProfile.mountainGroupAliases;

Set<String> get _secondPassRequiredDomains =>
    _activeRegionProfile.secondPassRequiredDomains;

String? get _preferredAuthorityDomainLabel =>
    _activeRegionProfile.preferredAuthorityDomainLabel;

List<String> get _highestPeakNeedles => _activeRegionProfile.highestPeakNeedles;

String? get _highestPeakNote => _activeRegionProfile.highestPeakNote;

_RegionProfile _regionProfileForKey(String regionKey) {
  final normalizedKey = regionKey.trim().toLowerCase();
  final profile = _builtInRegionProfiles[normalizedKey];
  if (profile != null) {
    return profile;
  }

  final availableKeys = _builtInRegionProfiles.keys.join(', ');
  throw ArgumentError(
    'Unknown --region-key "$regionKey". Available region keys: $availableKeys.',
  );
}

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  _activeRegionProfile = options.regionProfile;
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  if (options.secondPassOnly) {
    final searchClient = _DuckDuckGoSearchClient(
      delayMs: options.delayMs,
      duckDuckGoLocale: options.regionProfile.duckDuckGoLocale,
      acceptLanguage: options.regionProfile.acceptLanguage,
    );
    try {
      final existingOutput = await _loadExistingRankedOutput(
        options.outputJsonPath,
      );
      if (existingOutput.regionKey != null &&
          existingOutput.regionKey != options.regionKey) {
        throw ArgumentError(
          'Existing output ${options.outputJsonPath} was generated for '
          '${existingOutput.regionKey}, not ${options.regionKey}.',
        );
      }
      final refinedPeaks = await _runSecondPass(
        topPeaks: existingOutput.peaks,
        totalRegionPeaks: existingOutput.totalRegionPeaks,
        searchedCandidates: existingOutput.searchedCandidates,
        options: options,
        client: searchClient,
      );

      stdout.writeln('Wrote ${refinedPeaks.length} ranked peaks.');
      stdout.writeln('JSON: ${options.outputJsonPath}');
      stdout.writeln('CSV: ${options.outputCsvPath}');
      if (options.lesserCsvOutputPath != null) {
        stderr.writeln(
          'Skipping lesser CSV in --second-pass-only mode because the existing JSON only contains the top peaks.',
        );
      }
      _printPreview(refinedPeaks);
      return;
    } finally {
      searchClient.close();
    }
  }

  final polygons = await _loadRegionPolygons();
  final peaks = await _loadRegionPeaks(polygons);
  final candidateCount = options.maxCandidates == null
      ? peaks.length
      : math.min(options.maxCandidates!, peaks.length);
  final selectedPeaks = peaks.take(candidateCount).toList(growable: false);

  stdout.writeln(
    'Loaded ${peaks.length} peaks in ${options.regionProfile.regionName}.',
  );
  stdout.writeln('Scoring ${selectedPeaks.length} candidates.');

  final searchClient = _DuckDuckGoSearchClient(
    delayMs: options.delayMs,
    duckDuckGoLocale: options.regionProfile.duckDuckGoLocale,
    acceptLanguage: options.regionProfile.acceptLanguage,
  );
  try {
    final rankedPeaks = <_RankedPeak>[];
    for (var index = 0; index < selectedPeaks.length; index++) {
      final peak = selectedPeaks[index];
      stdout.writeln(
        '[${index + 1}/${selectedPeaks.length}] ${peak.displayName}',
      );
      final cacheEntry = await _loadOrFetchPrimarySearch(
        peak: peak,
        options: options,
        client: searchClient,
      );
      rankedPeaks.add(_rankPeak(peak, cacheEntry));

      final processedCount = index + 1;
      if (processedCount % _saveInterval == 0) {
        await _writeRankedOutputs(
          rankedPeaks: rankedPeaks,
          totalRegionPeaks: peaks.length,
          searchedCandidates: selectedPeaks.length,
          options: options,
          useSearchOnlyEnrichment: true,
          showProgress: false,
        );
        stdout.writeln(
          'Saved first-pass progress at $processedCount peaks to ${options.outputJsonPath}.',
        );
      }
    }

    final enrichedPeaks = await _writeRankedOutputs(
      rankedPeaks: rankedPeaks,
      totalRegionPeaks: peaks.length,
      searchedCandidates: selectedPeaks.length,
      options: options,
      useSearchOnlyEnrichment: false,
      showProgress: true,
    );

    final refinedPeaks = await _runSecondPass(
      topPeaks: enrichedPeaks,
      totalRegionPeaks: peaks.length,
      searchedCandidates: selectedPeaks.length,
      options: options,
      client: searchClient,
    );
    await _writeLesserCsvIfRequested(
      rankedPeaks: rankedPeaks,
      options: options,
    );

    stdout.writeln('Wrote ${refinedPeaks.length} ranked peaks.');
    stdout.writeln('JSON: ${options.outputJsonPath}');
    stdout.writeln('CSV: ${options.outputCsvPath}');
    if (options.lesserCsvOutputPath != null) {
      stdout.writeln('Lesser CSV: ${options.lesserCsvOutputPath}');
    }
    _printPreview(refinedPeaks);
  } finally {
    searchClient.close();
  }
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.regionKey,
    required this.regionProfile,
    required this.topCount,
    required this.maxCandidates,
    required this.delayMs,
    required this.cacheDir,
    required this.outputJsonPath,
    required this.outputCsvPath,
    required this.lesserCsvOutputPath,
    required this.secondPassOnly,
    required this.offline,
    required this.refreshCache,
  });

  final bool showHelp;
  final String regionKey;
  final _RegionProfile regionProfile;
  final int topCount;
  final int? maxCandidates;
  final int delayMs;
  final String cacheDir;
  final String outputJsonPath;
  final String outputCsvPath;
  final String? lesserCsvOutputPath;
  final bool secondPassOnly;
  final bool offline;
  final bool refreshCache;

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var regionKey = _defaultRegionKey;
    var topCount = _defaultTopCount;
    int? maxCandidates;
    var delayMs = _defaultDelayMs;
    String? cacheDir;
    String? outputJsonPath;
    String? outputCsvPath;
    String? lesserCsvOutputPath;
    var wantsLesserCsv = false;
    var secondPassOnly = false;
    var offline = false;
    var refreshCache = false;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }
      if (arg == '--offline') {
        offline = true;
        continue;
      }
      if (arg == '--second-pass-only') {
        secondPassOnly = true;
        continue;
      }
      if (arg == '--refresh-cache') {
        refreshCache = true;
        continue;
      }
      if (arg.startsWith('--region-key=')) {
        regionKey = arg.substring('--region-key='.length).trim();
        continue;
      }
      if (arg == '--region-key') {
        regionKey = _nextArgValue(args, ++index, '--region-key').trim();
        continue;
      }
      if (arg.startsWith('--top=')) {
        topCount = _parsePositiveInt(arg.substring('--top='.length), '--top');
        continue;
      }
      if (arg == '--top') {
        topCount = _parsePositiveInt(
          _nextArgValue(args, ++index, '--top'),
          '--top',
        );
        continue;
      }
      if (arg.startsWith('--max-candidates=')) {
        maxCandidates = _parsePositiveInt(
          arg.substring('--max-candidates='.length),
          '--max-candidates',
        );
        continue;
      }
      if (arg == '--max-candidates') {
        maxCandidates = _parsePositiveInt(
          _nextArgValue(args, ++index, '--max-candidates'),
          '--max-candidates',
        );
        continue;
      }
      if (arg.startsWith('--delay-ms=')) {
        delayMs = _parseNonNegativeInt(
          arg.substring('--delay-ms='.length),
          '--delay-ms',
        );
        continue;
      }
      if (arg == '--delay-ms') {
        delayMs = _parseNonNegativeInt(
          _nextArgValue(args, ++index, '--delay-ms'),
          '--delay-ms',
        );
        continue;
      }
      if (arg.startsWith('--cache-dir=')) {
        cacheDir = arg.substring('--cache-dir='.length);
        continue;
      }
      if (arg == '--cache-dir') {
        cacheDir = _nextArgValue(args, ++index, '--cache-dir');
        continue;
      }
      if (arg.startsWith('--output-json=')) {
        outputJsonPath = arg.substring('--output-json='.length);
        continue;
      }
      if (arg == '--output-json') {
        outputJsonPath = _nextArgValue(args, ++index, '--output-json');
        continue;
      }
      if (arg.startsWith('--output-csv=')) {
        outputCsvPath = arg.substring('--output-csv='.length);
        continue;
      }
      if (arg == '--output-csv') {
        outputCsvPath = _nextArgValue(args, ++index, '--output-csv');
        continue;
      }
      if (arg.startsWith('--output-lesser-csv=')) {
        final path = arg.substring('--output-lesser-csv='.length).trim();
        wantsLesserCsv = true;
        lesserCsvOutputPath = path.isEmpty ? null : path;
        continue;
      }
      if (arg == '--output-lesser-csv') {
        wantsLesserCsv = true;
        final nextIndex = index + 1;
        if (nextIndex < args.length && !args[nextIndex].startsWith('--')) {
          lesserCsvOutputPath = args[nextIndex];
          index = nextIndex;
          continue;
        }
        continue;
      }
      throw ArgumentError('Unknown argument: $arg');
    }

    final regionProfile = _regionProfileForKey(regionKey);

    return _CliOptions(
      showHelp: showHelp,
      regionKey: regionProfile.key,
      regionProfile: regionProfile,
      topCount: topCount,
      maxCandidates: maxCandidates,
      delayMs: delayMs,
      cacheDir: cacheDir ?? regionProfile.defaultCacheDir,
      outputJsonPath: outputJsonPath ?? regionProfile.defaultJsonOutputPath,
      outputCsvPath: outputCsvPath ?? regionProfile.defaultCsvOutputPath,
      lesserCsvOutputPath: wantsLesserCsv
          ? lesserCsvOutputPath ?? regionProfile.defaultLesserCsvOutputPath
          : null,
      secondPassOnly: secondPassOnly,
      offline: offline,
      refreshCache: refreshCache,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'regionKey': regionKey,
      'topCount': topCount,
      'maxCandidates': maxCandidates,
      'delayMs': delayMs,
      'cacheDir': cacheDir,
      'outputJsonPath': outputJsonPath,
      'outputCsvPath': outputCsvPath,
      'lesserCsvOutputPath': lesserCsvOutputPath,
      'secondPassOnly': secondPassOnly,
      'offline': offline,
      'refreshCache': refreshCache,
    };
  }
}

class _PeakCandidate {
  const _PeakCandidate({
    required this.osmId,
    required this.displayName,
    required this.searchName,
    required this.alternateNames,
    required this.latitude,
    required this.longitude,
    required this.elevationMeters,
    required this.prominenceMeters,
  });

  final int osmId;
  final String displayName;
  final String searchName;
  final List<String> alternateNames;
  final double latitude;
  final double longitude;
  final double? elevationMeters;
  final double? prominenceMeters;

  Map<String, Object?> toJson() {
    return {
      'osmId': osmId,
      'displayName': displayName,
      'searchName': searchName,
      'alternateNames': alternateNames,
      'latitude': latitude,
      'longitude': longitude,
      'elevationMeters': elevationMeters,
      'prominenceMeters': prominenceMeters,
    };
  }

  static _PeakCandidate fromJson(Map<String, dynamic> json) {
    return _PeakCandidate(
      osmId: (json['osmId'] as num?)?.toInt() ?? -1,
      displayName: json['displayName'] as String? ?? '',
      searchName: json['searchName'] as String? ?? '',
      alternateNames: (json['alternateNames'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
      elevationMeters: (json['elevationMeters'] as num?)?.toDouble(),
      prominenceMeters: (json['prominenceMeters'] as num?)?.toDouble(),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.url,
    required this.domain,
    required this.snippet,
  });

  final String title;
  final String url;
  final String domain;
  final String snippet;

  Map<String, Object?> toJson() {
    return {'title': title, 'url': url, 'domain': domain, 'snippet': snippet};
  }

  static _SearchResult fromJson(Map<String, dynamic> json) {
    return _SearchResult(
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      snippet: json['snippet'] as String? ?? '',
    );
  }
}

class _SearchCacheEntry {
  const _SearchCacheEntry({
    required this.query,
    required this.results,
    required this.fetchedAt,
    required this.error,
    required this.secondPassQueries,
  });

  final String query;
  final List<_SearchResult> results;
  final DateTime fetchedAt;
  final String? error;
  final List<String> secondPassQueries;

  Map<String, Object?> toJson() {
    return {
      'query': query,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'error': error,
      'secondPassQueries': secondPassQueries,
      'results': results.map((result) => result.toJson()).toList(),
    };
  }

  static _SearchCacheEntry fromJson(Map<String, dynamic> json) {
    final rawResults = json['results'];
    final rawSecondPassQueries = json['secondPassQueries'];
    return _SearchCacheEntry(
      query: json['query'] as String? ?? '',
      fetchedAt:
          DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      error: json['error'] as String?,
      secondPassQueries: rawSecondPassQueries is List<dynamic>
          ? rawSecondPassQueries
                .whereType<String>()
                .map((query) => query.trim())
                .where((query) => query.isNotEmpty)
                .toList(growable: false)
          : const [],
      results: rawResults is List<dynamic>
          ? rawResults
                .whereType<Map<String, dynamic>>()
                .map(_SearchResult.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}

class _ScoreBreakdown {
  const _ScoreBreakdown({
    required this.domainScores,
    required this.routeKeywordHits,
    required this.scenicKeywordHits,
    required this.varietyBonus,
    required this.resultsBonus,
    required this.elevationBonus,
    required this.prominenceBonus,
    required this.platformRatingBonus,
    required this.crossSourceBonus,
  });

  final Map<String, double> domainScores;
  final int routeKeywordHits;
  final int scenicKeywordHits;
  final double varietyBonus;
  final double resultsBonus;
  final double elevationBonus;
  final double prominenceBonus;
  final double platformRatingBonus;
  final double crossSourceBonus;

  Map<String, Object?> toJson() {
    return {
      'domainScores': domainScores,
      'routeKeywordHits': routeKeywordHits,
      'scenicKeywordHits': scenicKeywordHits,
      'varietyBonus': varietyBonus,
      'resultsBonus': resultsBonus,
      'elevationBonus': elevationBonus,
      'prominenceBonus': prominenceBonus,
      'platformRatingBonus': platformRatingBonus,
      'crossSourceBonus': crossSourceBonus,
    };
  }

  static _ScoreBreakdown fromJson(Map<String, dynamic> json) {
    final rawDomainScores = json['domainScores'];
    return _ScoreBreakdown(
      domainScores: rawDomainScores is Map<String, dynamic>
          ? rawDomainScores.map(
              (key, value) => MapEntry(key, (value as num).toDouble()),
            )
          : const {},
      routeKeywordHits: (json['routeKeywordHits'] as num?)?.toInt() ?? 0,
      scenicKeywordHits: (json['scenicKeywordHits'] as num?)?.toInt() ?? 0,
      varietyBonus: (json['varietyBonus'] as num?)?.toDouble() ?? 0,
      resultsBonus: (json['resultsBonus'] as num?)?.toDouble() ?? 0,
      elevationBonus: (json['elevationBonus'] as num?)?.toDouble() ?? 0,
      prominenceBonus: (json['prominenceBonus'] as num?)?.toDouble() ?? 0,
      platformRatingBonus:
          (json['platformRatingBonus'] as num?)?.toDouble() ?? 0,
      crossSourceBonus: (json['crossSourceBonus'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _RankedPeak {
  const _RankedPeak({
    required this.peak,
    required this.score,
    required this.cacheEntry,
    required this.breakdown,
    required this.recognizedDomains,
  });

  final _PeakCandidate peak;
  final double score;
  final _SearchCacheEntry cacheEntry;
  final _ScoreBreakdown breakdown;
  final List<String> recognizedDomains;

  Map<String, Object?> toJson() {
    return {
      'score': score,
      'peak': peak.toJson(),
      'recognizedDomains': recognizedDomains,
      'search': cacheEntry.toJson(),
      'breakdown': breakdown.toJson(),
    };
  }

  static _RankedPeak fromJson(Map<String, dynamic> json) {
    return _RankedPeak(
      peak: _PeakCandidate.fromJson(
        json['peak'] as Map<String, dynamic>? ?? const {},
      ),
      score: (json['score'] as num?)?.toDouble() ?? 0,
      cacheEntry: _SearchCacheEntry.fromJson(
        json['search'] as Map<String, dynamic>? ?? const {},
      ),
      breakdown: _ScoreBreakdown.fromJson(
        json['breakdown'] as Map<String, dynamic>? ?? const {},
      ),
      recognizedDomains:
          (json['recognizedDomains'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class _EnrichedPeak {
  const _EnrichedPeak({
    required this.rankedPeak,
    required this.mountainGroup,
    required this.province,
    required this.difficulty,
    required this.viaFerrata,
    required this.notes,
  });

  final _RankedPeak rankedPeak;
  final String? mountainGroup;
  final String? province;
  final String? difficulty;
  final String viaFerrata;
  final String? notes;

  Map<String, Object?> toJson() {
    return {
      'rankedPeak': rankedPeak.toJson(),
      'mountainGroup': mountainGroup,
      'province': province,
      'difficulty': difficulty,
      'viaFerrata': viaFerrata,
      'notes': notes,
    };
  }

  static _EnrichedPeak fromJson(Map<String, dynamic> json) {
    return _EnrichedPeak(
      rankedPeak: _RankedPeak.fromJson(
        json['rankedPeak'] as Map<String, dynamic>? ?? const {},
      ),
      mountainGroup: json['mountainGroup'] as String?,
      province: json['province'] as String?,
      difficulty: json['difficulty'] as String?,
      viaFerrata: json['viaFerrata'] as String? ?? 'No',
      notes: json['notes'] as String?,
    );
  }
}

class _ExistingRankedOutput {
  const _ExistingRankedOutput({
    required this.regionKey,
    required this.totalRegionPeaks,
    required this.searchedCandidates,
    required this.peaks,
  });

  final String? regionKey;
  final int totalRegionPeaks;
  final int searchedCandidates;
  final List<_EnrichedPeak> peaks;
}

class _ProvinceLookupResult {
  const _ProvinceLookupResult({
    required this.province,
    required this.fetchedAt,
    required this.error,
  });

  final String? province;
  final DateTime fetchedAt;
  final String? error;

  Map<String, Object?> toJson() {
    return {
      'province': province,
      'fetchedAt': fetchedAt.toUtc().toIso8601String(),
      'error': error,
    };
  }

  static _ProvinceLookupResult fromJson(Map<String, dynamic> json) {
    return _ProvinceLookupResult(
      province: json['province'] as String?,
      fetchedAt:
          DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      error: json['error'] as String?,
    );
  }
}

class _LocalizedSearchCacheEntry {
  const _LocalizedSearchCacheEntry({
    required this.cacheEntry,
    required this.usedFilteredResults,
  });

  final _SearchCacheEntry cacheEntry;
  final bool usedFilteredResults;
}

class _DuckDuckGoSearchClient {
  _DuckDuckGoSearchClient({
    required this.delayMs,
    required this.duckDuckGoLocale,
    required this.acceptLanguage,
  }) : _client = HttpClient() {
    _client.connectionTimeout = _httpRequestTimeout;
  }

  final int delayMs;
  final String duckDuckGoLocale;
  final String acceptLanguage;
  final HttpClient _client;
  DateTime? _lastRequestAt;

  Future<_SearchCacheEntry> search(String query) async {
    await _waitForRateLimit();
    final uri = Uri.parse(
      '$_jinaDuckDuckGoPrefix?q=${Uri.encodeQueryComponent(query)}&kl=$duckDuckGoLocale',
    );
    final request = await _client.getUrl(uri).timeout(_httpRequestTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(HttpHeaders.acceptLanguageHeader, acceptLanguage);
    final response = await request.close().timeout(_httpRequestTimeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_httpRequestTimeout);
    _lastRequestAt = DateTime.now();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Mirrored DuckDuckGo returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    return _SearchCacheEntry(
      query: query,
      results: _parseSearchResults(body),
      fetchedAt: DateTime.now(),
      error: null,
      secondPassQueries: const [],
    );
  }

  void close() {
    _client.close(force: true);
  }

  Future<void> _waitForRateLimit() async {
    if (_lastRequestAt == null || delayMs <= 0) {
      return;
    }
    final elapsed = DateTime.now().difference(_lastRequestAt!);
    final remaining = Duration(milliseconds: delayMs) - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }
}

class _NominatimReverseGeocodeClient {
  _NominatimReverseGeocodeClient({required this.delayMs})
    : _client = HttpClient() {
    _client.connectionTimeout = _httpRequestTimeout;
  }

  final int delayMs;
  final HttpClient _client;
  DateTime? _lastRequestAt;

  Future<_ProvinceLookupResult> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    await _waitForRateLimit();
    final uri = Uri.parse(_nominatimReverseUrl).replace(
      queryParameters: {
        'format': 'jsonv2',
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'zoom': '10',
      },
    );
    final request = await _client.getUrl(uri).timeout(_httpRequestTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, _userAgent);
    request.headers.set(
      HttpHeaders.acceptLanguageHeader,
      'it-IT,it;q=0.9,en;q=0.8',
    );
    final response = await request.close().timeout(_httpRequestTimeout);
    final body = await response
        .transform(utf8.decoder)
        .join()
        .timeout(_httpRequestTimeout);
    _lastRequestAt = DateTime.now();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Nominatim returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }

    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Nominatim reverse geocode must return a JSON object.');
    }

    return _ProvinceLookupResult(
      province: _extractProvinceName(decoded),
      fetchedAt: DateTime.now(),
      error: null,
    );
  }

  void close() {
    _client.close(force: true);
  }

  Future<void> _waitForRateLimit() async {
    if (_lastRequestAt == null || delayMs <= 0) {
      return;
    }
    final elapsed = DateTime.now().difference(_lastRequestAt!);
    final remaining = Duration(milliseconds: delayMs) - elapsed;
    if (remaining > Duration.zero) {
      await Future<void>.delayed(remaining);
    }
  }
}

Future<List<List<LatLng>>> _loadRegionPolygons() async {
  final polygons = <List<LatLng>>[];
  for (final path in _activeRegionProfile.polygonPaths) {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Missing polygon asset', path);
    }
    final parseResult = parsePolygonText(await file.readAsString());
    if (!parseResult.isSuccess || parseResult.polygon == null) {
      throw StateError('Invalid polygon asset $path: ${parseResult.error}');
    }
    polygons.add(parseResult.polygon!.vertices);
  }
  return polygons;
}

Future<List<_PeakCandidate>> _loadRegionPeaks(
  List<List<LatLng>> polygons,
) async {
  final datasetFile = File(_activeRegionProfile.datasetPath);
  if (!await datasetFile.exists()) {
    throw FileSystemException(
      'Missing peak dataset',
      _activeRegionProfile.datasetPath,
    );
  }

  final decoded = jsonDecode(await datasetFile.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Peak dataset must be a JSON object.');
  }
  final elements = decoded['elements'];
  if (elements is! List<dynamic>) {
    throw StateError('Peak dataset must define an elements list.');
  }

  final peaksByKey = <String, _PeakCandidate>{};
  for (final rawElement in elements) {
    if (rawElement is! Map<String, dynamic>) {
      continue;
    }
    final tags = rawElement['tags'];
    if (tags is! Map<String, dynamic> || tags['natural'] != 'peak') {
      continue;
    }

    final latitude = _toDouble(rawElement['lat']);
    final longitude = _toDouble(rawElement['lon']);
    if (latitude == null || longitude == null) {
      continue;
    }

    final point = LatLng(latitude, longitude);
    final isInside = polygons.any(
      (polygon) => polygonContainsPoint(point, polygon),
    );
    if (!isInside) {
      continue;
    }

    final allNames = _collectNames(tags);
    if (allNames.isEmpty) {
      continue;
    }
    final displayName = allNames.first;
    final searchName = _searchName(tags, displayName);
    final peak = _PeakCandidate(
      osmId: (rawElement['id'] as num?)?.toInt() ?? -1,
      displayName: displayName,
      searchName: searchName,
      alternateNames: allNames.skip(1).toList(growable: false),
      latitude: latitude,
      longitude: longitude,
      elevationMeters: _toDouble(tags['ele']),
      prominenceMeters: _toDouble(tags['prominence']),
    );

    final dedupeKey =
        '${_normalizeText(searchName)}|${latitude.toStringAsFixed(4)}|${longitude.toStringAsFixed(4)}';
    final existing = peaksByKey[dedupeKey];
    if (existing == null || _isBetterPeak(peak, existing)) {
      peaksByKey[dedupeKey] = peak;
    }
  }

  final peaks = peaksByKey.values.toList()
    ..sort((left, right) {
      final elevationComparison = (right.elevationMeters ?? -1).compareTo(
        left.elevationMeters ?? -1,
      );
      if (elevationComparison != 0) {
        return elevationComparison;
      }
      final prominenceComparison = (right.prominenceMeters ?? -1).compareTo(
        left.prominenceMeters ?? -1,
      );
      if (prominenceComparison != 0) {
        return prominenceComparison;
      }
      return left.displayName.compareTo(right.displayName);
    });
  return peaks;
}

bool _isBetterPeak(_PeakCandidate left, _PeakCandidate right) {
  final leftMetadataScore =
      (left.elevationMeters != null ? 1 : 0) +
      (left.prominenceMeters != null ? 1 : 0) +
      left.alternateNames.length;
  final rightMetadataScore =
      (right.elevationMeters != null ? 1 : 0) +
      (right.prominenceMeters != null ? 1 : 0) +
      right.alternateNames.length;
  if (leftMetadataScore != rightMetadataScore) {
    return leftMetadataScore > rightMetadataScore;
  }
  final leftElevation = left.elevationMeters ?? -1;
  final rightElevation = right.elevationMeters ?? -1;
  if (leftElevation != rightElevation) {
    return leftElevation > rightElevation;
  }
  final leftProminence = left.prominenceMeters ?? -1;
  final rightProminence = right.prominenceMeters ?? -1;
  return leftProminence > rightProminence;
}

Future<_SearchCacheEntry> _loadOrFetchSearch({
  required _PeakCandidate peak,
  required String query,
  required _CliOptions options,
  required _DuckDuckGoSearchClient client,
}) async {
  final cacheFile = _searchCacheFile(
    peak: peak,
    query: query,
    options: options,
  );
  if (!options.refreshCache && await cacheFile.exists()) {
    final cached = _SearchCacheEntry.fromJson(
      jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>,
    );
    if (cached.query == query) {
      return cached;
    }
  }

  if (options.offline) {
    return _SearchCacheEntry(
      query: query,
      results: const [],
      fetchedAt: DateTime.now(),
      error: 'Offline mode with no matching cache entry.',
      secondPassQueries: const [],
    );
  }

  try {
    final fresh = await client.search(query);
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(fresh.toJson()),
    );
    return fresh;
  } catch (error) {
    final failed = _SearchCacheEntry(
      query: query,
      results: const [],
      fetchedAt: DateTime.now(),
      error: error.toString(),
      secondPassQueries: const [],
    );
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(failed.toJson()),
    );
    stderr.writeln('Search failed for ${peak.displayName}: $error');
    return failed;
  }
}

Future<_SearchCacheEntry> _loadOrFetchPrimarySearch({
  required _PeakCandidate peak,
  required _CliOptions options,
  required _DuckDuckGoSearchClient client,
}) async {
  final queries = _buildPrimaryQueries(peak);
  _SearchCacheEntry? combinedEntry;

  for (final query in queries) {
    final entry = await _loadOrFetchSearch(
      peak: peak,
      query: query,
      options: options,
      client: client,
    );
    if (combinedEntry == null) {
      combinedEntry = entry;
      continue;
    }
    combinedEntry = _mergeSearchCacheEntries(
      current: combinedEntry,
      followUp: entry,
      requiredDomains: _secondPassRequiredDomains,
      trackFollowUpQuery: false,
    );
  }

  return combinedEntry ??
      _SearchCacheEntry(
        query: _buildDefaultPrimaryQuery(peak),
        results: const [],
        fetchedAt: DateTime.now(),
        error: 'No primary queries were generated.',
        secondPassQueries: const [],
      );
}

File _searchCacheFile({
  required _PeakCandidate peak,
  required String query,
  required _CliOptions options,
}) {
  if (query == _buildDefaultPrimaryQuery(peak)) {
    return File(p.join(options.cacheDir, '${peak.osmId}.json'));
  }
  return File(
    p.join(
      options.cacheDir,
      'second-pass',
      '${peak.osmId}',
      '${_queryCacheKey(query)}.json',
    ),
  );
}

String _queryCacheKey(String query) {
  final normalized = _normalizeText(
    _normalizeSearchText(query),
  ).replaceAll(' ', '_');
  final hash = query.codeUnits.fold<int>(
    0,
    (value, codeUnit) => (value * 31 + codeUnit) & 0x7fffffff,
  );
  if (normalized.isEmpty) {
    return hash.toRadixString(16);
  }
  return '$normalized-${hash.toRadixString(16)}';
}

Future<String?> _loadOrFetchProvince({
  required _PeakCandidate peak,
  required _CliOptions options,
  required _NominatimReverseGeocodeClient client,
  required _SearchCacheEntry searchCacheEntry,
}) async {
  final cacheFile = File(
    p.join(options.cacheDir, 'reverse-geocode', '${peak.osmId}.json'),
  );
  if (await cacheFile.exists()) {
    final cached = _ProvinceLookupResult.fromJson(
      jsonDecode(await cacheFile.readAsString()) as Map<String, dynamic>,
    );
    if (cached.province != null && cached.province!.isNotEmpty) {
      return cached.province;
    }
  }

  if (options.offline) {
    return _inferProvinceFromSearchResults(searchCacheEntry);
  }

  try {
    final result = await client.reverseGeocode(
      latitude: peak.latitude,
      longitude: peak.longitude,
    );
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(result.toJson()),
    );
    return result.province ?? _inferProvinceFromSearchResults(searchCacheEntry);
  } catch (error) {
    final failed = _ProvinceLookupResult(
      province: _inferProvinceFromSearchResults(searchCacheEntry),
      fetchedAt: DateTime.now(),
      error: error.toString(),
    );
    await cacheFile.parent.create(recursive: true);
    await cacheFile.writeAsString(
      const JsonEncoder.withIndent('  ').convert(failed.toJson()),
    );
    stderr.writeln('Reverse geocode failed for ${peak.displayName}: $error');
    return failed.province;
  }
}

String _buildDefaultPrimaryQuery(_PeakCandidate peak) {
  final fallbackKeyword = _primaryQueryKeywords.isEmpty
      ? 'hike'
      : _primaryQueryKeywords.first;
  return '"${peak.searchName}" $fallbackKeyword';
}

List<String> _buildPrimaryQueries(_PeakCandidate peak) {
  final queries = <String>[];
  final seen = <String>{};

  void addQueriesForName(String name) {
    for (final keyword in _primaryQueryKeywords) {
      final query = '"$name" $keyword';
      if (seen.add(query.toLowerCase())) {
        queries.add(query);
      }
    }
  }

  addQueriesForName(peak.searchName);
  final normalizedSearchName = _normalizeSearchText(peak.searchName);
  if (normalizedSearchName != peak.searchName) {
    addQueriesForName(normalizedSearchName);
  }
  return queries;
}

List<String> _buildSecondPassQueries(_PeakCandidate peak) {
  final queries = <String>[];
  final seen = <String>{};

  void addQuery(String candidate) {
    final trimmed = candidate.trim();
    if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) {
      return;
    }
    queries.add(trimmed);
  }

  addQuery(peak.searchName);
  if (peak.displayName != peak.searchName) {
    addQuery(peak.displayName);
  }

  final normalizedSearchName = _normalizeSearchText(peak.searchName);
  if (normalizedSearchName != peak.searchName) {
    addQuery(normalizedSearchName);
  }

  final normalizedDisplayName = _normalizeSearchText(peak.displayName);
  if (normalizedDisplayName != peak.displayName) {
    addQuery(normalizedDisplayName);
  }

  return queries;
}

Future<List<_EnrichedPeak>> _runSecondPass({
  required List<_EnrichedPeak> topPeaks,
  required int totalRegionPeaks,
  required int searchedCandidates,
  required _CliOptions options,
  required _DuckDuckGoSearchClient client,
}) async {
  stdout.writeln(
    'Reviewing ${options.outputJsonPath} for missing '
    '${_secondPassRequiredDomains.join(', ')} scores.',
  );

  final reviewedPeaks = topPeaks.toList(growable: true);
  for (var index = 0; index < reviewedPeaks.length; index++) {
    reviewedPeaks[index] = await _runSecondPassForPeak(
      peak: reviewedPeaks[index],
      options: options,
      client: client,
    );

    final reviewedCount = index + 1;
    if (reviewedCount % _saveInterval == 0) {
      final sortedBatch = _sortEnrichedPeaks(reviewedPeaks);
      await _writeJson(
        outputPath: options.outputJsonPath,
        topPeaks: sortedBatch,
        totalRegionPeaks: totalRegionPeaks,
        searchedCandidates: searchedCandidates,
        options: options,
      );
      await _writeCsv(options.outputCsvPath, sortedBatch, options);
      stdout.writeln(
        'Saved second-pass progress at $reviewedCount peaks to ${options.outputJsonPath}.',
      );
    }
  }

  final sortedPeaks = _sortEnrichedPeaks(reviewedPeaks);
  await _writeJson(
    outputPath: options.outputJsonPath,
    topPeaks: sortedPeaks,
    totalRegionPeaks: totalRegionPeaks,
    searchedCandidates: searchedCandidates,
    options: options,
  );
  await _writeCsv(options.outputCsvPath, sortedPeaks, options);
  return sortedPeaks;
}

Future<List<_EnrichedPeak>> _writeRankedOutputs({
  required List<_RankedPeak> rankedPeaks,
  required int totalRegionPeaks,
  required int searchedCandidates,
  required _CliOptions options,
  required bool useSearchOnlyEnrichment,
  required bool showProgress,
}) async {
  final sortedRankedPeaks = _prepareRankedPeaksForSelection(rankedPeaks);
  final topCount = math.min(options.topCount, sortedRankedPeaks.length);
  final topPeaks = sortedRankedPeaks.take(topCount).toList(growable: false);
  final enrichedPeaks = await _enrichPeaks(
    topPeaks: topPeaks,
    options: options,
    useSearchOnlyEnrichment: useSearchOnlyEnrichment,
    showProgress: showProgress,
  );

  await _writeJson(
    outputPath: options.outputJsonPath,
    topPeaks: enrichedPeaks,
    totalRegionPeaks: totalRegionPeaks,
    searchedCandidates: searchedCandidates,
    options: options,
  );
  await _writeCsv(options.outputCsvPath, enrichedPeaks, options);
  return enrichedPeaks;
}

Future<void> _writeLesserCsvIfRequested({
  required List<_RankedPeak> rankedPeaks,
  required _CliOptions options,
}) async {
  final outputPath = options.lesserCsvOutputPath;
  if (outputPath == null) {
    return;
  }

  final sortedRankedPeaks = _prepareRankedPeaksForSelection(rankedPeaks);
  final topCount = math.min(options.topCount, sortedRankedPeaks.length);
  final lesserPeaks = sortedRankedPeaks.skip(topCount).toList(growable: false);
  final enrichedLesserPeaks = await _enrichPeaks(
    topPeaks: lesserPeaks,
    options: options,
    useSearchOnlyEnrichment: true,
    showProgress: false,
  );
  await _writeCsv(outputPath, enrichedLesserPeaks, options);
}

Future<_ExistingRankedOutput> _loadExistingRankedOutput(
  String outputPath,
) async {
  final file = File(outputPath);
  if (!await file.exists()) {
    throw FileSystemException('Missing ranked peak JSON output', outputPath);
  }

  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw StateError('Ranked peak output must be a JSON object.');
  }

  final rawPeaks = decoded['peaks'];
  if (rawPeaks is! List<dynamic>) {
    throw StateError('Ranked peak output must define a peaks list.');
  }

  return _ExistingRankedOutput(
    regionKey: decoded['regionKey'] as String?,
    totalRegionPeaks:
        (decoded['totalRegionPeaks'] as num?)?.toInt() ??
        (decoded['totalFvgPeaks'] as num?)?.toInt() ??
        0,
    searchedCandidates: (decoded['searchedCandidates'] as num?)?.toInt() ?? 0,
    peaks: rawPeaks
        .whereType<Map<String, dynamic>>()
        .map(_EnrichedPeak.fromJson)
        .toList(growable: false),
  );
}

Future<_EnrichedPeak> _runSecondPassForPeak({
  required _EnrichedPeak peak,
  required _CliOptions options,
  required _DuckDuckGoSearchClient client,
}) async {
  var updatedPeak = _localizeEnrichedPeak(peak);
  var missingDomains = _missingSecondPassDomains(
    updatedPeak.rankedPeak.recognizedDomains,
  );
  if (missingDomains.isEmpty) {
    return updatedPeak;
  }

  final secondPassQueries = _buildSecondPassQueries(updatedPeak.rankedPeak.peak)
      .where(
        (query) => !updatedPeak.rankedPeak.cacheEntry.secondPassQueries
            .contains(query),
      )
      .toList(growable: false);
  if (secondPassQueries.isEmpty) {
    return updatedPeak;
  }

  stdout.writeln(
    'Second pass for ${updatedPeak.rankedPeak.peak.displayName}: ${missingDomains.join(', ')} missing.',
  );

  for (final query in secondPassQueries) {
    final followUpEntry = await _loadOrFetchSearch(
      peak: updatedPeak.rankedPeak.peak,
      query: query,
      options: options,
      client: client,
    );
    final mergedCacheEntry = _mergeSearchCacheEntries(
      current: updatedPeak.rankedPeak.cacheEntry,
      followUp: followUpEntry,
      requiredDomains: missingDomains,
    );
    final rerankedPeak = _rankPeak(
      updatedPeak.rankedPeak.peak,
      mergedCacheEntry,
    );
    updatedPeak = _localizeEnrichedPeak(
      _rebuildEnrichedPeak(current: updatedPeak, rankedPeak: rerankedPeak),
    );
    missingDomains = _missingSecondPassDomains(
      updatedPeak.rankedPeak.recognizedDomains,
    );
    if (missingDomains.isEmpty) {
      break;
    }
  }

  return updatedPeak;
}

_SearchCacheEntry _mergeSearchCacheEntries({
  required _SearchCacheEntry current,
  required _SearchCacheEntry followUp,
  required Set<String> requiredDomains,
  bool trackFollowUpQuery = true,
}) {
  final prioritizedResults = <_SearchResult>[];
  final deferredResults = <_SearchResult>[];
  for (final result in followUp.results) {
    final weightedDomain = _weightedDomainScore(
      _normalizeDomain(result.domain.isEmpty ? result.url : result.domain),
    );
    if (weightedDomain != null &&
        requiredDomains.contains(weightedDomain.label)) {
      prioritizedResults.add(result);
      continue;
    }
    deferredResults.add(result);
  }

  final mergedResults = _mergeSearchResults([
    ...prioritizedResults,
    ...current.results,
    ...deferredResults,
  ]);
  final secondPassQueries = trackFollowUpQuery
      ? ([...current.secondPassQueries, followUp.query]
            .map((query) => query.trim())
            .where((query) => query.isNotEmpty)
            .toSet()
            .toList()
          ..sort())
      : current.secondPassQueries;

  return _SearchCacheEntry(
    query: current.query,
    results: mergedResults,
    fetchedAt: followUp.fetchedAt.isAfter(current.fetchedAt)
        ? followUp.fetchedAt
        : current.fetchedAt,
    error: mergedResults.isNotEmpty ? null : current.error ?? followUp.error,
    secondPassQueries: secondPassQueries,
  );
}

List<_SearchResult> _mergeSearchResults(List<_SearchResult> results) {
  final seen = <String>{};
  final merged = <_SearchResult>[];
  for (final result in results) {
    final dedupeKey = result.url.isEmpty
        ? '${result.domain}|${result.title}'.toLowerCase()
        : result.url.toLowerCase();
    if (!seen.add(dedupeKey)) {
      continue;
    }
    merged.add(result);
  }
  return merged;
}

Set<String> _missingSecondPassDomains(List<String> recognizedDomains) {
  return _secondPassRequiredDomains.difference(recognizedDomains.toSet());
}

_EnrichedPeak _rebuildEnrichedPeak({
  required _EnrichedPeak current,
  required _RankedPeak rankedPeak,
}) {
  return _EnrichedPeak(
    rankedPeak: rankedPeak,
    mountainGroup:
        _inferMountainGroup(rankedPeak.cacheEntry) ?? current.mountainGroup,
    province:
        current.province ??
        _inferProvinceFromSearchResults(rankedPeak.cacheEntry),
    difficulty: _inferDifficulty(rankedPeak.cacheEntry) ?? current.difficulty,
    viaFerrata: _inferViaFerrata(rankedPeak.cacheEntry),
    notes: _inferNotes(rankedPeak: rankedPeak) ?? current.notes,
  );
}

List<_EnrichedPeak> _sortEnrichedPeaks(List<_EnrichedPeak> peaks) {
  final sorted = peaks.toList(growable: false);
  sorted.sort(
    (left, right) => _compareRankedPeaks(left.rankedPeak, right.rankedPeak),
  );
  return sorted;
}

_RankedPeak _rankPeak(_PeakCandidate peak, _SearchCacheEntry cacheEntry) {
  final recognizedDomainScores = <String, double>{};
  final distinctDomains = <String>{};
  final hikingPlatformDomains = <String>{};
  var routeKeywordHits = 0;
  var scenicKeywordHits = 0;

  for (final result in cacheEntry.results.take(10)) {
    final domain = _normalizeDomain(
      result.domain.isEmpty ? result.url : result.domain,
    );
    if (domain.isNotEmpty) {
      distinctDomains.add(domain);
      final platformScore = _weightedDomainScore(domain);
      if (platformScore != null) {
        recognizedDomainScores[platformScore.label] = platformScore.score;
        hikingPlatformDomains.add(platformScore.label);
      }
    }

    final haystack = '${result.title} ${result.snippet}'.toLowerCase();
    routeKeywordHits += _countKeywordHits(haystack, _routeKeywords);
    scenicKeywordHits += _countKeywordHits(haystack, _scenicKeywords);
  }

  final resultsBonus = math.min(cacheEntry.results.length, 10).toDouble();
  final varietyBonus = math.min(distinctDomains.length * 0.6, 4.0);
  final routeKeywordBonus = math.min(routeKeywordHits * 0.4, 4.0);
  final scenicKeywordBonus = math.min(scenicKeywordHits * 0.25, 2.0);
  final elevationBonus = peak.elevationMeters == null
      ? 0.0
      : math.min(peak.elevationMeters! / 1000, 2.5);
  final prominenceBonus = peak.prominenceMeters == null
      ? 0.0
      : math.min(peak.prominenceMeters! / 500, 2.0);
  final platformRatingBonus =
      _platformRatingFromDomainScores(recognizedDomainScores) *
      _platformRatingBonusMultiplier;
  final authorityDomainLabel = _preferredAuthorityDomainLabel;
  final crossSourceBonus =
      authorityDomainLabel != null &&
          recognizedDomainScores.containsKey(authorityDomainLabel) &&
          hikingPlatformDomains.length >= 2
      ? 2.0
      : hikingPlatformDomains.length >= 3
      ? 1.5
      : 0.0;
  final totalScore =
      recognizedDomainScores.values.fold<double>(
        0,
        (sum, value) => sum + value,
      ) +
      resultsBonus +
      varietyBonus +
      routeKeywordBonus +
      scenicKeywordBonus +
      elevationBonus +
      prominenceBonus +
      platformRatingBonus +
      crossSourceBonus;

  final recognizedDomains = recognizedDomainScores.keys.toList()..sort();
  return _RankedPeak(
    peak: peak,
    score: double.parse(totalScore.toStringAsFixed(2)),
    cacheEntry: cacheEntry,
    recognizedDomains: recognizedDomains,
    breakdown: _ScoreBreakdown(
      domainScores: recognizedDomainScores,
      routeKeywordHits: routeKeywordHits,
      scenicKeywordHits: scenicKeywordHits,
      varietyBonus: double.parse(varietyBonus.toStringAsFixed(2)),
      resultsBonus: double.parse(resultsBonus.toStringAsFixed(2)),
      elevationBonus: double.parse(elevationBonus.toStringAsFixed(2)),
      prominenceBonus: double.parse(prominenceBonus.toStringAsFixed(2)),
      platformRatingBonus: double.parse(platformRatingBonus.toStringAsFixed(2)),
      crossSourceBonus: double.parse(crossSourceBonus.toStringAsFixed(2)),
    ),
  );
}

int _compareRankedPeaks(_RankedPeak left, _RankedPeak right) {
  final scoreComparison = right.score.compareTo(left.score);
  if (scoreComparison != 0) {
    return scoreComparison;
  }
  final elevationComparison = (right.peak.elevationMeters ?? -1).compareTo(
    left.peak.elevationMeters ?? -1,
  );
  if (elevationComparison != 0) {
    return elevationComparison;
  }
  return left.peak.displayName.compareTo(right.peak.displayName);
}

Future<List<_EnrichedPeak>> _enrichPeaks({
  required List<_RankedPeak> topPeaks,
  required _CliOptions options,
  required bool useSearchOnlyEnrichment,
  required bool showProgress,
}) async {
  if (useSearchOnlyEnrichment) {
    return topPeaks.map(_enrichPeakFromSearchResults).toList(growable: false);
  }

  if (showProgress) {
    stdout.writeln('Final enrichment (${topPeaks.length} peaks):');
  }

  final geocodeClient = _NominatimReverseGeocodeClient(
    delayMs: options.delayMs,
  );
  try {
    final enrichedPeaks = <_EnrichedPeak>[];
    for (var index = 0; index < topPeaks.length; index++) {
      final rankedPeak = topPeaks[index];
      final province = await _loadOrFetchProvince(
        peak: rankedPeak.peak,
        options: options,
        client: geocodeClient,
        searchCacheEntry: rankedPeak.cacheEntry,
      );
      final mountainGroup = _inferMountainGroup(rankedPeak.cacheEntry);
      final difficulty = _inferDifficulty(rankedPeak.cacheEntry);
      final viaFerrata = _inferViaFerrata(rankedPeak.cacheEntry);
      final notes = _inferNotes(rankedPeak: rankedPeak);
      enrichedPeaks.add(
        _localizeEnrichedPeak(
          _EnrichedPeak(
            rankedPeak: rankedPeak,
            mountainGroup: mountainGroup,
            province: province,
            difficulty: difficulty,
            viaFerrata: viaFerrata,
            notes: notes,
          ),
        ),
      );

      if (showProgress) {
        stdout.write('.');
        final processedCount = index + 1;
        if (processedCount % 25 == 0 || processedCount == topPeaks.length) {
          stdout.writeln(' $processedCount/${topPeaks.length}');
        }
      }
    }
    return enrichedPeaks;
  } finally {
    geocodeClient.close();
  }
}

_EnrichedPeak _enrichPeakFromSearchResults(_RankedPeak rankedPeak) {
  return _localizeEnrichedPeak(
    _EnrichedPeak(
      rankedPeak: rankedPeak,
      mountainGroup: _inferMountainGroup(rankedPeak.cacheEntry),
      province: _inferProvinceFromSearchResults(rankedPeak.cacheEntry),
      difficulty: _inferDifficulty(rankedPeak.cacheEntry),
      viaFerrata: _inferViaFerrata(rankedPeak.cacheEntry),
      notes: _inferNotes(rankedPeak: rankedPeak),
    ),
  );
}

List<_RankedPeak> _prepareRankedPeaksForSelection(
  List<_RankedPeak> rankedPeaks,
) {
  final localizedRankedPeaks =
      rankedPeaks.map(_localizeRankedPeakForSelection).toList(growable: false)
        ..sort(_compareRankedPeaks);
  return localizedRankedPeaks;
}

_RankedPeak _localizeRankedPeakForSelection(_RankedPeak rankedPeak) {
  final localized = _localizeSearchCacheEntry(
    peak: rankedPeak.peak,
    cacheEntry: rankedPeak.cacheEntry,
    province: null,
  );
  if (!localized.usedFilteredResults) {
    return rankedPeak;
  }

  return _rankPeak(rankedPeak.peak, localized.cacheEntry);
}

_EnrichedPeak _localizeEnrichedPeak(_EnrichedPeak peak) {
  final localized = _localizeSearchCacheEntry(
    peak: peak.rankedPeak.peak,
    cacheEntry: peak.rankedPeak.cacheEntry,
    province: peak.province,
  );
  if (!localized.usedFilteredResults) {
    return peak;
  }

  final localizedRankedPeak = _rankPeak(
    peak.rankedPeak.peak,
    localized.cacheEntry,
  );
  return _EnrichedPeak(
    rankedPeak: localizedRankedPeak,
    mountainGroup: _inferMountainGroup(localized.cacheEntry),
    province:
        peak.province ?? _inferProvinceFromSearchResults(localized.cacheEntry),
    difficulty: _inferDifficulty(localized.cacheEntry),
    viaFerrata: _inferViaFerrata(localized.cacheEntry),
    notes: _inferNotes(rankedPeak: localizedRankedPeak),
  );
}

_LocalizedSearchCacheEntry _localizeSearchCacheEntry({
  required _PeakCandidate peak,
  required _SearchCacheEntry cacheEntry,
  required String? province,
}) {
  final nameSignals = _buildNameSignals(peak);
  final hasDistinctiveNameSignals = _hasDistinctiveNameSignals(peak);
  final localitySignals = _buildLocalitySignals(province: province);
  final conflictingLocationSignals = _buildConflictingLocationSignals(
    province: province,
  );
  if (nameSignals.isEmpty && localitySignals.isEmpty) {
    return _LocalizedSearchCacheEntry(
      cacheEntry: cacheEntry,
      usedFilteredResults: false,
    );
  }

  final filteredResults = cacheEntry.results
      .where(
        (result) => _matchesLocality(
          result,
          hasDistinctiveNameSignals: hasDistinctiveNameSignals,
          nameSignals: nameSignals,
          localitySignals: localitySignals,
          conflictingLocationSignals: conflictingLocationSignals,
        ),
      )
      .toList(growable: false);
  if (filteredResults.length == cacheEntry.results.length) {
    return _LocalizedSearchCacheEntry(
      cacheEntry: cacheEntry,
      usedFilteredResults: false,
    );
  }

  return _LocalizedSearchCacheEntry(
    cacheEntry: _SearchCacheEntry(
      query: cacheEntry.query,
      results: filteredResults,
      fetchedAt: cacheEntry.fetchedAt,
      error: cacheEntry.error,
      secondPassQueries: cacheEntry.secondPassQueries,
    ),
    usedFilteredResults: true,
  );
}

Set<String> _buildNameSignals(_PeakCandidate peak) {
  final signals = <String>{};

  void addSignal(String? raw) {
    if (raw == null) {
      return;
    }
    final normalized = _normalizeText(raw);
    if (normalized.length >= 3) {
      signals.add(normalized);
      signals.add(normalized.replaceAll(' ', ''));
    }
  }

  addSignal(peak.displayName);
  addSignal(peak.searchName);
  for (final alternateName in peak.alternateNames) {
    addSignal(alternateName);
  }

  return signals;
}

bool _hasDistinctiveNameSignals(_PeakCandidate peak) {
  final names = <String>[
    peak.displayName,
    peak.searchName,
    ...peak.alternateNames,
  ];
  for (final name in names) {
    final normalizedName = _normalizeText(name);
    if (normalizedName.isEmpty) {
      continue;
    }
    final tokens = normalizedName.split(' ');
    for (final token in tokens) {
      if (token.length >= 4 && !_genericPeakNameTokens.contains(token)) {
        return true;
      }
    }
  }
  return false;
}

Set<String> _buildLocalitySignals({required String? province}) {
  final signals = <String>{};

  void addSignal(String? raw) {
    if (raw == null) {
      return;
    }
    final normalized = _normalizeText(raw);
    if (normalized.length >= 3) {
      signals.add(normalized);
      signals.add(normalized.replaceAll(' ', ''));
    }
  }

  addSignal(province);
  for (final allowedLocationSignal
      in _activeRegionProfile.allowedLocationSignals) {
    addSignal(allowedLocationSignal);
  }

  return signals;
}

Set<String> _buildConflictingLocationSignals({required String? province}) {
  final normalizedAllowedSignals = _buildLocalitySignals(province: province);
  final conflictingSignals = <String>{};

  for (final rawSignal in _knownItalianLocationSignals) {
    final normalized = _normalizeText(rawSignal);
    if (normalized.length < 3 ||
        normalizedAllowedSignals.contains(normalized)) {
      continue;
    }
    conflictingSignals.add(normalized);
    conflictingSignals.add(normalized.replaceAll(' ', ''));
  }

  return conflictingSignals;
}

bool _matchesLocality(
  _SearchResult result, {
  required bool hasDistinctiveNameSignals,
  required Set<String> nameSignals,
  required Set<String> localitySignals,
  required Set<String> conflictingLocationSignals,
}) {
  final haystack = _normalizeText(
    '${result.title} ${result.snippet} ${result.url}',
  );
  final compactHaystack = haystack.replaceAll(' ', '');

  final hasConflictingLocation = _containsSignal(
    haystack,
    compactHaystack,
    conflictingLocationSignals,
  );
  if (_containsSignal(haystack, compactHaystack, localitySignals)) {
    return true;
  }

  return hasDistinctiveNameSignals &&
      _containsSignal(haystack, compactHaystack, nameSignals) &&
      !hasConflictingLocation;
}

bool _containsSignal(
  String haystack,
  String compactHaystack,
  Set<String> signals,
) {
  for (final signal in signals) {
    if (signal.contains(' ')) {
      if (haystack.contains(signal)) {
        return true;
      }
      continue;
    }
    if (compactHaystack.contains(signal)) {
      return true;
    }
  }
  return false;
}

Future<void> _writeJson({
  required String outputPath,
  required List<_EnrichedPeak> topPeaks,
  required int totalRegionPeaks,
  required int searchedCandidates,
  required _CliOptions options,
}) async {
  final payload = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'regionKey': options.regionKey,
    'region': options.regionProfile.regionName,
    'datasetPath': options.regionProfile.datasetPath,
    'totalRegionPeaks': totalRegionPeaks,
    'searchedCandidates': searchedCandidates,
    'options': options.toJson(),
    'peaks': topPeaks.map((peak) => peak.toJson()).toList(),
  };
  final file = File(outputPath);
  await file.parent.create(recursive: true);
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
}

Future<void> _writeCsv(
  String outputPath,
  List<_EnrichedPeak> topPeaks,
  _CliOptions options,
) async {
  final rows = <List<Object?>>[
    [
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
    ],
  ];

  for (var index = 0; index < topPeaks.length; index++) {
    final enrichedPeak = topPeaks[index];
    final peak = enrichedPeak.rankedPeak;
    rows.add([
      peak.peak.displayName,
      peak.peak.osmId,
      _platformRating(peak.breakdown),
      peak.peak.elevationMeters,
      peak.peak.prominenceMeters,
      peak.peak.latitude,
      peak.peak.longitude,
      options.regionProfile.countryName,
      options.regionProfile.regionName,
      enrichedPeak.mountainGroup,
      enrichedPeak.province,
      enrichedPeak.difficulty,
      enrichedPeak.viaFerrata,
      enrichedPeak.notes,
    ]);
  }

  final file = File(outputPath);
  await file.parent.create(recursive: true);
  final csv = rows.map(_toCsvRow).join('\n');
  await file.writeAsString('$csv\n');
}

double _platformRating(_ScoreBreakdown breakdown) {
  return _platformRatingFromDomainScores(breakdown.domainScores);
}

double _platformRatingFromDomainScores(Map<String, double> domainScores) {
  final ratings = _secondPassRequiredDomains
      .map((label) => domainScores[label])
      .whereType<double>()
      .toList(growable: false);
  if (ratings.isEmpty) {
    return 0;
  }
  final average = ratings.reduce((sum, value) => sum + value) / ratings.length;
  return double.parse(average.toStringAsFixed(2));
}

void _printPreview(List<_EnrichedPeak> topPeaks) {
  final previewCount = math.min(10, topPeaks.length);
  if (previewCount == 0) {
    return;
  }

  stdout.writeln('Top $previewCount preview:');
  for (var index = 0; index < previewCount; index++) {
    final peak = topPeaks[index].rankedPeak;
    final elevation = peak.peak.elevationMeters == null
        ? 'unknown'
        : '${peak.peak.elevationMeters!.round()} m';
    stdout.writeln(
      '${index + 1}. ${peak.peak.displayName} '
      '(score ${peak.score.toStringAsFixed(2)}, $elevation)',
    );
  }
}

List<_SearchResult> _parseSearchResults(String html) {
  if (html.contains('## No results found')) {
    return const [];
  }

  final matches = _markdownResultBlockPattern.allMatches(html);
  final results = <_SearchResult>[];
  for (final match in matches) {
    final href = match.namedGroup('url');
    final title = match.namedGroup('title');
    final block = match.namedGroup('body');
    if (href == null || title == null || block == null) {
      continue;
    }

    final url = _extractDuckDuckGoTargetUrl(href);
    if (url == null || url.isEmpty) {
      continue;
    }

    results.add(
      _SearchResult(
        title: _cleanupMarkdownText(title),
        url: url,
        domain: _normalizeDomain(url),
        snippet: _extractSnippetFromMarkdownBlock(block),
      ),
    );
  }
  return results;
}

final _markdownResultBlockPattern = RegExp(
  r'^## \[(?<title>.+?)\]\((?<url>.+?)\)\s*$\n(?<body>.*?)(?=^## \[|\z)',
  multiLine: true,
  dotAll: true,
);

String? _extractDuckDuckGoTargetUrl(String href) {
  final normalizedHref = href.startsWith('//') ? 'https:$href' : href;
  final uri = Uri.tryParse(normalizedHref);
  if (uri == null) {
    return null;
  }
  if (uri.host.contains('duckduckgo.com')) {
    return uri.queryParameters['uddg'];
  }
  return normalizedHref;
}

String _cleanupMarkdownText(String text) {
  return _decodeHtmlEntities(
    text,
  ).replaceAll(RegExp(r'\*+'), '').replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _extractSnippetFromMarkdownBlock(String block) {
  final lines = const LineSplitter().convert(block);
  String best = '';
  for (final rawLine in lines) {
    final line = rawLine.trim();
    if (line.isEmpty || !line.startsWith('[')) {
      continue;
    }
    if (line.startsWith('[![') ||
        line.contains('duckduckgo.com/feedback.html')) {
      continue;
    }

    final text = _extractMarkdownLinkText(line);
    if (text == null ||
        text.length <= best.length ||
        _looksLikeDisplayUrl(text)) {
      continue;
    }
    best = text;
  }
  return _cleanupMarkdownText(best);
}

String? _extractMarkdownLinkText(String line) {
  final firstOpen = line.indexOf('[');
  final firstClose = line.indexOf('](', firstOpen);
  if (firstOpen == -1 || firstClose == -1) {
    return null;
  }
  return line.substring(firstOpen + 1, firstClose);
}

bool _looksLikeDisplayUrl(String text) {
  return text.contains('/') && text.contains('.') && !text.contains(' ');
}

String _decodeHtmlEntities(String input) {
  return input
      .replaceAll('&quot;', '"')
      .replaceAll('&#x27;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');
}

String? _extractProvinceName(Map<String, dynamic> response) {
  final address = response['address'];
  if (address is! Map<String, dynamic>) {
    return null;
  }

  final isoCode = address['ISO3166-2-lvl6'] as String?;
  if (isoCode != null && _provinceIsoNames.containsKey(isoCode)) {
    return _provinceIsoNames[isoCode];
  }

  final county = address['county'] as String?;
  if (county == null || county.isEmpty) {
    return null;
  }
  return _normalizeProvinceLabel(county) ?? county;
}

String? _inferProvinceFromSearchResults(_SearchCacheEntry cacheEntry) {
  final haystack = _searchHaystack(cacheEntry);
  for (final province in _provinceIsoNames.values) {
    if (haystack.contains(province.toLowerCase())) {
      return province;
    }
  }
  return null;
}

String? _inferMountainGroup(_SearchCacheEntry cacheEntry) {
  final haystack = _searchHaystack(cacheEntry);
  for (final entry in _mountainGroupAliases.entries) {
    if (entry.value.any(haystack.contains)) {
      return entry.key;
    }
  }
  return null;
}

String? _inferDifficulty(_SearchCacheEntry cacheEntry) {
  final haystack = _searchHaystack(cacheEntry);
  final hasFerrata = _containsAny(haystack, [
    'via ferrata',
    ' ferrata',
    'attrezzat',
    'zavarovana plezalna pot',
  ]);
  final hasNormalRoute = _containsAny(haystack, [
    'via normale',
    'normal route',
    'non richiede attrezzatura',
    'does not require special equipment',
    'brez posebne opreme',
  ]);
  if (hasFerrata && hasNormalRoute) {
    return 'EE';
  }
  if (hasFerrata) {
    return 'EEA';
  }
  if (_containsAny(haystack, [
    ' ee ',
    'escursionisti esperti',
    'sentiero alpinistico',
    'impegnativa',
    'impegnativo',
    'challenging',
    'difficult',
    'alta montagna',
    'zahtevna',
    'zelo zahtevna',
  ])) {
    return 'EE';
  }
  if (_containsAny(haystack, [
    'escursione',
    'escursionismo',
    'hiking',
    'trekking',
    'pohod',
    'planinska pot',
  ])) {
    return 'E';
  }
  return null;
}

String _inferViaFerrata(_SearchCacheEntry cacheEntry) {
  final haystack = _searchHaystack(cacheEntry);
  final hasFerrata = _containsAny(haystack, [
    'via ferrata',
    ' ferrata',
    'attrezzat',
    'zavarovana plezalna pot',
  ]);
  final hasNormalRoute = _containsAny(haystack, [
    'via normale',
    'normal route',
    'non richiede attrezzatura',
    'does not require special equipment',
    'brez posebne opreme',
  ]);
  if (hasFerrata && hasNormalRoute) {
    return 'Optional';
  }
  if (hasFerrata) {
    return 'Yes';
  }
  return 'No';
}

String? _inferNotes({required _RankedPeak rankedPeak}) {
  for (final result in rankedPeak.cacheEntry.results) {
    final note = _noteFromSnippet(result.snippet);
    if (note != null) {
      return note;
    }
  }

  if (rankedPeak.peak.alternateNames.isNotEmpty) {
    return 'Also known as ${rankedPeak.peak.alternateNames.first}';
  }

  return null;
}

String? _noteFromSnippet(String snippet) {
  final trimmed = snippet.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (_highestPeakNote != null &&
      _containsAny(trimmed.toLowerCase(), _highestPeakNeedles)) {
    return _highestPeakNote;
  }

  final shortened = trimmed
      .split(
        RegExp(
          r'(Scarica la traccia GPS|Download its GPS track)',
          caseSensitive: false,
        ),
      )
      .first
      .trim();
  final cleaned = shortened
      .replaceAll(RegExp(r'^(Percorso|Route)\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.length < 24) {
    return null;
  }
  return cleaned.length <= 110
      ? cleaned
      : '${cleaned.substring(0, 107).trim()}...';
}

String _searchHaystack(_SearchCacheEntry cacheEntry) {
  return cacheEntry.results
      .map((result) => '${result.title} ${result.snippet}'.toLowerCase())
      .join(' ');
}

bool _containsAny(String haystack, List<String> needles) {
  for (final needle in needles) {
    if (haystack.contains(needle)) {
      return true;
    }
  }
  return false;
}

String? _normalizeProvinceLabel(String rawCounty) {
  final normalized = rawCounty.toLowerCase();
  for (final province in _provinceIsoNames.values) {
    if (normalized.contains(province.toLowerCase())) {
      return province;
    }
  }
  return null;
}

({double score, String label})? _weightedDomainScore(String domain) {
  for (final entry in _weightedDomains.entries) {
    if (domain == entry.key || domain.endsWith('.${entry.key}')) {
      return entry.value;
    }
  }
  return null;
}

int _countKeywordHits(String haystack, List<String> keywords) {
  var count = 0;
  for (final keyword in keywords) {
    if (haystack.contains(keyword)) {
      count++;
    }
  }
  return count;
}

List<String> _collectNames(Map<String, dynamic> tags) {
  final seen = <String>{};
  final names = <String>[];
  for (final key in _nameKeyOrder) {
    final value = tags[key];
    if (value is! String || value.trim().isEmpty) {
      continue;
    }
    for (final candidate in value.split(';')) {
      final trimmed = candidate.trim();
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) {
        continue;
      }
      names.add(trimmed);
    }
  }
  return names;
}

String _searchName(Map<String, dynamic> tags, String fallback) {
  var preferred = fallback;
  for (final key in _nameKeyOrder) {
    final value = tags[key];
    if (value is String && value.trim().isNotEmpty) {
      preferred = value;
      break;
    }
  }
  final cleaned = preferred.split(' / ').first.split(' - ').first.trim();
  return cleaned.isEmpty ? fallback : cleaned;
}

double? _toDouble(Object? value) {
  if (value == null) {
    return null;
  }
  if (value is num) {
    return value.toDouble();
  }
  if (value is! String) {
    return null;
  }
  final normalized = value.replaceAll(',', '.');
  final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
  return match == null ? null : double.tryParse(match.group(0)!);
}

String _normalizeDomain(String value) {
  final uri = Uri.tryParse(value.startsWith('http') ? value : 'https://$value');
  if (uri == null) {
    return '';
  }
  var host = uri.host.toLowerCase();
  if (host.startsWith('www.')) {
    host = host.substring(4);
  }
  return host;
}

String _normalizeSearchText(String value) {
  var normalized = value;
  _searchCharacterReplacements.forEach((source, target) {
    normalized = normalized.replaceAll(source, target);
  });
  return normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String _normalizeText(String value) {
  return _normalizeSearchText(
    value,
  ).toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

String _nextArgValue(List<String> args, int index, String option) {
  if (index >= args.length) {
    throw ArgumentError('Missing value for $option');
  }
  return args[index];
}

int _parsePositiveInt(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed <= 0) {
    throw ArgumentError('$option must be a positive integer');
  }
  return parsed;
}

int _parseNonNegativeInt(String value, String option) {
  final parsed = int.tryParse(value);
  if (parsed == null || parsed < 0) {
    throw ArgumentError('$option must be a non-negative integer');
  }
  return parsed;
}

String _toCsvRow(List<Object?> values) {
  return values.map(_toCsvCell).join(',');
}

String _toCsvCell(Object? value) {
  if (value == null) {
    return '';
  }
  final text = value.toString();
  final escaped = text.replaceAll('"', '""');
  if (escaped.contains(',') ||
      escaped.contains('"') ||
      escaped.contains('\n')) {
    return '"$escaped"';
  }
  return escaped;
}
