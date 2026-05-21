import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/import_path_helpers.dart';

const _openDataManifestUrl =
    'https://listdata.thelist.tas.gov.au/opendata/resources/opendata.js';
const _downloadBaseUrl = 'https://listdata.thelist.tas.gov.au/opendata/data/';
const _usage = '''
Downloads and merges theLIST Tasmania 25m DEM municipality zips.

What it does:
- fetches theLIST open-data manifest
- discovers all LIST_DEM_25M_*.zip municipality archives
- downloads them under your Bushwalking root
- extracts them
- builds a statewide VRT
- optionally writes a merged GeoTIFF

Default output:
- ~/Documents/Bushwalking/DEM/Tasmania/thelist_25m
- falls back to your home dir if Documents/Bushwalking does not exist

Usage:
  dart run tool/download_tasmania_thelist_dem.dart
  dart run tool/download_tasmania_thelist_dem.dart --list-only
  dart run tool/download_tasmania_thelist_dem.dart --skip-merge
  dart run tool/download_tasmania_thelist_dem.dart --output-dir /path/to/output
''';

final _municipalityBlockPattern = RegExp(
  r'var mun = \[(.*?)\]\s*;',
  dotAll: true,
);
final _municipalityNamePattern = RegExp(r'\["([^"]+)",\s*"\d+"\]');
final _demDatasetPrefixSuffixPattern = RegExp(r',"([^"]+)"\]\s*,?$');
const _rasterExtensions = <String>{'.tif', '.tiff', '.asc', '.img'};

Future<void> main(List<String> args) async {
  final options = _CliOptions.parse(args);
  if (options.showHelp) {
    stdout.write(_usage);
    return;
  }

  final zipUrls = await _discoverZipUrls();
  if (options.listOnly) {
    for (final url in zipUrls) {
      stdout.writeln(url);
    }
    return;
  }

  final outputDirectory =
      options.outputDirectory ??
      p.join(resolveBushwalkingRoot(), 'DEM', 'Tasmania', 'thelist_25m');

  final workspace = _Workspace.fromRoot(outputDirectory);
  await workspace.ensureExists();

  await _requireCommand('unzip');
  await _requireCommand('gdalbuildvrt');
  if (!options.skipMerge) {
    await _requireCommand('gdal_translate');
  }

  stdout.writeln('Found ${zipUrls.length} municipality archives.');

  for (final url in zipUrls) {
    await _downloadIfMissing(url, workspace.rawZipPath(url));
  }

  for (final zipFile in await workspace.listRawZips()) {
    await _extractIfMissing(zipFile, workspace.extractionPath(zipFile));
  }

  final rasters = await workspace.findRasters();
  if (rasters.isEmpty) {
    throw StateError('No rasters found after extraction.');
  }

  await workspace.writeRasterList(rasters);
  await _runCommand('gdalbuildvrt', [
    '-input_file_list',
    workspace.rasterListPath,
    workspace.vrtPath,
  ]);

  if (!options.skipMerge) {
    await _runCommand('gdal_translate', [
      workspace.vrtPath,
      workspace.geoTiffPath,
      '-co',
      'TILED=YES',
      '-co',
      'COMPRESS=DEFLATE',
      '-co',
      'BIGTIFF=IF_SAFER',
    ]);
  }

  stdout.writeln('Done.');
  stdout.writeln('VRT: ${workspace.vrtPath}');
  if (!options.skipMerge) {
    stdout.writeln('GeoTIFF: ${workspace.geoTiffPath}');
  }
}

class _CliOptions {
  const _CliOptions({
    required this.showHelp,
    required this.listOnly,
    required this.skipMerge,
    this.outputDirectory,
  });

  final bool showHelp;
  final bool listOnly;
  final bool skipMerge;
  final String? outputDirectory;

  static _CliOptions parse(List<String> args) {
    var showHelp = false;
    var listOnly = false;
    var skipMerge = false;
    String? outputDirectory;

    for (var index = 0; index < args.length; index++) {
      final arg = args[index];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
        continue;
      }
      if (arg == '--skip-merge') {
        skipMerge = true;
        continue;
      }
      if (arg == '--list-only') {
        listOnly = true;
        continue;
      }
      if (arg.startsWith('--output-dir=')) {
        outputDirectory = arg.substring('--output-dir='.length);
        continue;
      }
      if (arg == '--output-dir') {
        if (index + 1 >= args.length) {
          throw ArgumentError('Missing value for --output-dir');
        }
        outputDirectory = args[++index];
        continue;
      }
      throw ArgumentError('Unknown argument: $arg');
    }

    return _CliOptions(
      showHelp: showHelp,
      listOnly: listOnly,
      skipMerge: skipMerge,
      outputDirectory: outputDirectory,
    );
  }
}

class _Workspace {
  const _Workspace._({
    required this.root,
    required this.rawZips,
    required this.extracted,
    required this.rasterList,
    required this.vrt,
    required this.geoTiff,
  });

  factory _Workspace.fromRoot(String rootPath) {
    return _Workspace._(
      root: Directory(rootPath),
      rawZips: Directory(p.join(rootPath, 'raw_zips')),
      extracted: Directory(p.join(rootPath, 'extracted')),
      rasterList: File(p.join(rootPath, 'rasters.txt')),
      vrt: File(p.join(rootPath, 'tasmania_dem_25m.vrt')),
      geoTiff: File(p.join(rootPath, 'tasmania_dem_25m.tif')),
    );
  }

  final Directory root;
  final Directory rawZips;
  final Directory extracted;
  final File rasterList;
  final File vrt;
  final File geoTiff;

  String get rasterListPath => rasterList.path;
  String get vrtPath => vrt.path;
  String get geoTiffPath => geoTiff.path;

  Future<void> ensureExists() async {
    await root.create(recursive: true);
    await rawZips.create(recursive: true);
    await extracted.create(recursive: true);
  }

  File rawZipPath(String url) {
    return File(p.join(rawZips.path, p.basename(Uri.parse(url).path)));
  }

  Directory extractionPath(File zipFile) {
    return Directory(
      p.join(extracted.path, p.basenameWithoutExtension(zipFile.path)),
    );
  }

  Future<List<File>> listRawZips() async {
    final entries = await rawZips
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.zip'))
        .cast<File>()
        .toList();
    entries.sort((left, right) => left.path.compareTo(right.path));
    return entries;
  }

  Future<List<File>> findRasters() async {
    final rasters = <File>[];
    await for (final entity in extracted.list(recursive: true)) {
      if (entity is! File) {
        continue;
      }

      final extension = p.extension(entity.path).toLowerCase();
      if (_rasterExtensions.contains(extension)) {
        rasters.add(entity);
      }
    }

    rasters.sort((left, right) => left.path.compareTo(right.path));
    return rasters;
  }

  Future<void> writeRasterList(List<File> rasters) async {
    final contents = rasters.map((file) => file.absolute.path).join('\n');
    await rasterList.writeAsString('$contents\n');
  }
}

Future<List<String>> _discoverZipUrls() async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(_openDataManifestUrl));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to load open data manifest (${response.statusCode})',
        uri: Uri.parse(_openDataManifestUrl),
      );
    }

    final manifest = await response.transform(utf8.decoder).join();
    final datasetPrefix = _extractDemDatasetPrefix(manifest);
    final municipalitySuffixes = _extractMunicipalitySuffixes(manifest);

    final zipNames =
        municipalitySuffixes
            .map((suffix) => '${datasetPrefix}_$suffix.zip')
            .toList()
          ..sort();

    return zipNames.map((name) => '$_downloadBaseUrl$name').toList();
  } finally {
    client.close(force: true);
  }
}

String _extractDemDatasetPrefix(String manifest) {
  final datasetLine = const LineSplitter()
      .convert(manifest)
      .firstWhere(
        (line) =>
            line.contains('"LIST Tasmania 25 Metre Digital Elevation Model"'),
        orElse: () => '',
      );
  final prefix = _demDatasetPrefixSuffixPattern
      .firstMatch(datasetLine)
      ?.group(1);
  if (prefix == null || prefix.isEmpty) {
    throw StateError(
      'Could not find LIST Tasmania 25 Metre Digital Elevation Model prefix in open data manifest.',
    );
  }
  return prefix;
}

List<String> _extractMunicipalitySuffixes(String manifest) {
  final blockMatch = _municipalityBlockPattern.firstMatch(manifest);
  final municipalityBlock = blockMatch?.group(1);
  if (municipalityBlock == null || municipalityBlock.isEmpty) {
    throw StateError('Could not find municipality list in open data manifest.');
  }

  final suffixes =
      _municipalityNamePattern
          .allMatches(municipalityBlock)
          .map((match) => _normalizeMunicipalityName(match.group(1)!))
          .toSet()
          .toList()
        ..sort();

  if (suffixes.isEmpty) {
    throw StateError('No municipalities found in open data manifest.');
  }

  return suffixes;
}

String _normalizeMunicipalityName(String municipalityName) {
  return municipalityName.toUpperCase().replaceAll(RegExp(r"( |'|-|/)+"), '_');
}

Future<void> _downloadIfMissing(String url, File destination) async {
  if (await destination.exists() && await destination.length() > 0) {
    stdout.writeln('Skipping download: ${p.basename(destination.path)}');
    return;
  }

  stdout.writeln('Downloading: $url');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Failed to download $url (${response.statusCode})',
        uri: Uri.parse(url),
      );
    }

    await destination.parent.create(recursive: true);
    final sink = destination.openWrite();
    await response.pipe(sink);
  } finally {
    client.close(force: true);
  }
}

Future<void> _extractIfMissing(File zipFile, Directory destination) async {
  if (await destination.exists()) {
    stdout.writeln('Skipping extract: ${p.basename(zipFile.path)}');
    return;
  }

  await destination.create(recursive: true);
  stdout.writeln('Extracting: ${p.basename(zipFile.path)}');
  await _runCommand('unzip', ['-q', zipFile.path, '-d', destination.path]);
}

Future<void> _requireCommand(String command) async {
  final result = await Process.run('which', [command]);
  if (result.exitCode != 0) {
    throw StateError('Required command not found on PATH: $command');
  }
}

Future<void> _runCommand(String executable, List<String> arguments) async {
  stdout.writeln('+ $executable ${arguments.join(' ')}');
  final result = await Process.run(executable, arguments);
  if (result.exitCode == 0) {
    if (result.stdout is String &&
        (result.stdout as String).trim().isNotEmpty) {
      stdout.write(result.stdout as String);
    }
    return;
  }

  final stderrOutput = result.stderr.toString().trim();
  throw ProcessException(
    executable,
    arguments,
    stderrOutput.isEmpty ? result.stdout.toString() : stderrOutput,
    result.exitCode,
  );
}
