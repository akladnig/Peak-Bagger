import 'package:peak_bagger/models/map_polygon_asset.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/polygon_geometry.dart';

typedef PolygonAssetLoader = Future<String> Function(String assetPath);

class PolygonParseResult {
  const PolygonParseResult.success(this.asset) : error = null;

  const PolygonParseResult.failure(this.error) : asset = null;

  final MapPolygonAsset? asset;
  final String? error;

  bool get isSuccess => asset != null;
}

class PolygonAssetRepository {
  PolygonAssetRepository({
    required MappingCatalog catalog,
    MappingStoreFileSystem? fileSystem,
  }) : paths = catalog.polygonDisplayPaths,
       _assetLoader = MappingStoreOperationFileAccess(
         rootPath: catalog.rootPath,
         fileSystem: fileSystem ?? const IoMappingStoreFileSystem(),
       ).readText;

  /// Deterministic source seam; production always uses the store boundary.
  PolygonAssetRepository.test({
    required Iterable<String> paths,
    required PolygonAssetLoader assetLoader,
  }) : paths = Set.unmodifiable(paths),
       // Keep the source seam private; callers must use allowlisted reads.
       // ignore: prefer_initializing_formals
       _assetLoader = assetLoader;

  final Set<String> paths;
  final PolygonAssetLoader _assetLoader;

  String validatePath(String path) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.contains('\\') ||
        !path.endsWith('.poly') ||
        path
            .split('/')
            .any((part) => part.isEmpty || part == '.' || part == '..') ||
        !paths.contains(path)) {
      throw MappingStoreOperationException(
        paths: [path.isEmpty ? 'Polygons/manifest.json' : path],
        cause: const FormatException('Polygon is not a safe manifest entry.'),
      );
    }
    return path;
  }

  Future<MapPolygonAsset> loadPolygon(String path) async {
    validatePath(path);
    try {
      final contents = await _assetLoader(path);
      final result = parsePolygonAsset(contents, assetPath: path);
      if (!result.isSuccess) {
        throw FormatException(result.error!);
      }
      return result.asset!;
    } on MappingStoreOperationException {
      rethrow;
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: [path], cause: error);
    }
  }

  Future<List<MapPolygonAsset>> loadPolygons() async {
    final sortedPaths = paths.toList()..sort();
    return [for (final path in sortedPaths) await loadPolygon(path)];
  }
}

PolygonParseResult parsePolygonAsset(
  String contents, {
  required String assetPath,
}) {
  final parseResult = parsePolygonText(contents);
  if (!parseResult.isSuccess) {
    return PolygonParseResult.failure(
      _assetErrorMessage(assetPath, parseResult.error!),
    );
  }

  return PolygonParseResult.success(
    MapPolygonAsset(
      assetPath: assetPath,
      name: parseResult.polygon!.name,
      points: parseResult.polygon!.vertices,
    ),
  );
}

String _assetErrorMessage(String assetPath, String error) {
  const prefix = 'Polygon text';
  if (error.startsWith(prefix)) {
    return 'Polygon asset $assetPath${error.substring(prefix.length)}';
  }

  return 'Polygon asset $assetPath: $error';
}
