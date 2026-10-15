import 'mapping_store_core.dart';
import 'mapping_store_resolver.dart';

class MappingStoreOperationException implements Exception {
  MappingStoreOperationException({required Iterable<String> paths, this.cause})
    : paths = List.unmodifiable(_operationPaths(paths));
  final List<String> paths;
  final Object? cause;
  @override
  String toString() => cause == null
      ? 'Mapping data store operation failed: ${paths.join(', ')}'
      : 'Mapping data store operation failed: $cause';
}

List<String> _operationPaths(Iterable<String> paths) {
  final unique = <String>{};
  for (final path in paths) {
    if (path.isNotEmpty) {
      unique.add(path);
    }
  }
  if (unique.isEmpty) {
    throw ArgumentError.value(paths, 'paths', 'must not be empty');
  }
  return unique.toList(growable: false);
}

/// Pure read boundary shared by app operations and the background validator.
class MappingStoreOperationFileAccess {
  MappingStoreOperationFileAccess({
    required MappingCatalog catalog,
    MappingStoreFileSystem fileSystem = const IoMappingStoreFileSystem(),
  }) : _resolver = MappingStoreReadResolver.catalog(
         catalog: catalog,
         fileSystem: fileSystem,
       );
  MappingStoreOperationFileAccess.test({
    required String rootPath,
    required MappingStoreFileSystem fileSystem,
    required Iterable<String> paths,
  }) : _resolver = MappingStoreReadResolver.test(
         rootPath: rootPath,
         fileSystem: fileSystem,
         paths: paths,
       );
  final MappingStoreReadResolver _resolver;
  Future<T> open<T>({
    required String relativePath,
    required Future<T> Function(String canonicalPath) opener,
  }) async {
    try {
      return await _resolver.open(relativePath: relativePath, opener: opener);
    } on MappingStoreFailure catch (error) {
      throw MappingStoreOperationException(paths: error.paths, cause: error);
    }
  }

  Future<String> readText(String relativePath) async {
    try {
      return await _resolver.readText(relativePath);
    } on Object catch (error) {
      throw MappingStoreOperationException(paths: [relativePath], cause: error);
    }
  }
}
