import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';

/// A read capability, never an unrestricted path resolver. The injected opener
/// is a trusted binary adapter; only its opaque result reaches the caller.
class MappingStoreReadResolver {
  MappingStoreReadResolver._({
    required this._rootPath,
    required Iterable<String> paths,
    required this._fileSystem,
  }) : _paths = Set.unmodifiable(paths);

  factory MappingStoreReadResolver.runtime({
    required MappingStorePreflight preflight,
    MappingStoreFileSystem fileSystem = const IoMappingStoreFileSystem(),
  }) => MappingStoreReadResolver._(
    rootPath: preflight.root,
    paths: preflight.authorizedPaths,
    fileSystem: fileSystem,
  );

  /// Catalogs are constructed from validated manifests in the ready scope.
  factory MappingStoreReadResolver.catalog({
    required MappingCatalog catalog,
    MappingStoreFileSystem fileSystem = const IoMappingStoreFileSystem(),
  }) => MappingStoreReadResolver._(
    rootPath: catalog.rootPath,
    paths: catalog.authorizedPaths,
    fileSystem: fileSystem,
  );

  final String _rootPath;
  final MappingStoreFileSystem _fileSystem;
  final Set<String> _paths;

  /// Deterministic test seam. Production permissions come from a validated
  /// preflight or its ready-scope catalog.
  factory MappingStoreReadResolver.test({
    required String rootPath,
    required Iterable<String> paths,
    required MappingStoreFileSystem fileSystem,
  }) => MappingStoreReadResolver._(
    rootPath: rootPath,
    paths: paths,
    fileSystem: fileSystem,
  );

  Future<String> readText(String relativePath) =>
      open(relativePath: relativePath, opener: _fileSystem.readText);

  Future<T> open<T>({
    required String relativePath,
    required Future<T> Function(String canonicalPath) opener,
  }) async {
    if (relativePath == mappingToolManifestPath ||
        !_paths.contains(relativePath) ||
        !isSafeMappingStorePath(relativePath)) {
      throw MappingStoreFailure([relativePath]);
    }
    late final String target;
    try {
      final root = await _fileSystem.canonicalize(_rootPath);
      target = await _fileSystem.canonicalize(p.join(root, relativePath));
      if (!p.isWithin(root, target) ||
          p.equals(target, p.join(root, mappingToolManifestPath)) ||
          !await _fileSystem.fileExists(target)) {
        throw MappingStoreFailure([relativePath]);
      }
      await _fileSystem.checkReadable(target);
    } on MappingStoreFailure {
      rethrow;
    } on Object {
      throw MappingStoreFailure([relativePath]);
    }
    // Feature-owned binary adapters preserve their own typed errors.
    return opener(target);
  }
}
