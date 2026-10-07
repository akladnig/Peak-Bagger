import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:peak_bagger/services/mapping_store_core.dart';

export 'package:peak_bagger/services/mapping_store_core.dart';

final mappingCatalogProvider = Provider<MappingCatalog>((_) {
  throw StateError(
    'MappingCatalog is only available in the ready ProviderScope.',
  );
});

Future<String?> defaultMappingCatalogCacheDirectory() async {
  try {
    final directory = await getApplicationSupportDirectory();
    return p.join(directory.path, 'MappingCatalogCache');
  } on Object {
    return null;
  }
}

/// Flutter adapter; schema and source I/O also work in standalone Dart tools.
class MappingDataStore extends MappingDataStoreCore {
  MappingDataStore({
    super.rootPath,
    super.fileSystem,
    super.textReader,
    super.cache,
    MappingCatalogCacheDirectoryResolver? cacheDirectoryResolver,
  }) : super(
         cacheDirectoryResolver:
             cacheDirectoryResolver ?? defaultMappingCatalogCacheDirectory,
       );
}
