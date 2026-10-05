import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:peak_bagger/services/mapping_data_store.dart';

const polygonText = 'none\n1\n0 0\n1 0\n1 1\n0 0\nEND\nEND\n';

/// Separate metadata/read seams prove optional files are untouched at startup.
class PolygonMappingStore implements MappingStoreFileSystem {
  PolygonMappingStore() {
    for (final path in ['region_manifest.json', 'Polygons/manifest.json']) {
      files['$root/$path'] = File(
        'test/fixtures/mapping_store/v1/$path',
      ).readAsStringSync();
    }
    final manifest = jsonDecode(files['$root/region_manifest.json']!) as Map;
    void addSources(Object? value) {
      if (value is Map) {
        for (final child in value.values) {
          addSources(child);
        }
      } else if (value is List) {
        for (final child in value) {
          addSources(child);
        }
      } else if (value is String &&
          ['.poly', '.json', '.csv', '.tif'].any(value.endsWith)) {
        files['$root/$value'] = value.endsWith('.poly') ? polygonText : '';
      }
    }

    addSources(manifest);
    final paths = jsonDecode(files['$root/Polygons/manifest.json']!) as List;
    files['$root/Polygons/manifest.json'] = jsonEncode([
      ...paths,
      optionalPath,
      secondPath,
    ]);
  }

  static const root = '/mapping-test';
  static const optionalPath = 'Polygons/optional.poly';
  static const secondPath = 'Polygons/second.poly';
  final Map<String, String> files = {};
  final Map<String, String> symlinks = {};
  final Set<String> unreadable = {};
  final List<String> resolutions = [];
  final List<String> checks = [];
  final List<String> reads = [];
  Completer<String>? optionalRead;
  Object? optionalReadError;

  Future<MappingCatalog> loadCatalog() => MappingDataStore(
    rootPath: root,
    fileSystem: this,
    cacheDirectoryResolver: () async => null,
  ).loadCatalog();

  void repairOptional() => files['$root/$optionalPath'] = polygonText;

  @override
  Future<String> canonicalize(String absolutePath) async {
    resolutions.add(absolutePath);
    return symlinks[absolutePath] ?? absolutePath;
  }

  @override
  Future<void> checkReadable(String absolutePath) async {
    checks.add(absolutePath);
    if (unreadable.contains(absolutePath)) {
      throw StateError('Unreadable source');
    }
  }

  @override
  Future<bool> fileExists(String absolutePath) async =>
      files.containsKey(absolutePath);

  @override
  Future<MappingStoreFileMetadata> metadata(String absolutePath) async =>
      MappingStoreFileMetadata(
        size: files[absolutePath]!.length,
        modifiedMillis: 1,
      );

  @override
  Future<String> readText(String absolutePath) async {
    reads.add(absolutePath);
    if (absolutePath == '$root/$optionalPath' && optionalReadError != null) {
      throw optionalReadError!;
    }
    if (absolutePath == '$root/$optionalPath' && optionalRead != null) {
      return optionalRead!.future;
    }
    final text = files[absolutePath];
    if (text == null) throw StateError('Missing source $absolutePath');
    return text;
  }
}
