import 'package:path_provider/path_provider.dart';

import 'mapping_data_store.dart';
import 'mapping_runtime_config.dart';
import 'mapping_runtime_selection.dart';
import 'performance_measurement.dart';

/// Local-only launch boundary. Never dispatches the refresh pipeline/transport.
class MappingRuntimeLauncher {
  MappingRuntimeLauncher({
    this.supportDirectory = applicationSupportPath,
    this.isLocal,
    this.loadCatalog = loadRuntimeCatalog,
  });
  final Future<String> Function() supportDirectory;
  final Future<bool> Function(String)? isLocal;
  final Future<MappingCatalog> Function(String) loadCatalog;
  final List<MappingRuntimeSession> _sessions = [];

  static Future<String> applicationSupportPath() async =>
      (await getApplicationSupportDirectory()).path;

  Future<MappingCatalog> launch() async {
    final support = await supportDirectory();
    final config = await MappingRuntimeConfiguration.load(
      support,
      isLocal: isLocal,
    );
    performanceMeasurement.context['filesystem_transport'] =
        config.mode == MappingRuntimeMode.replica
        ? 'local-replica'
        : 'local-attached-canonical';
    if (config.mode == MappingRuntimeMode.canonical) {
      try {
        return await loadCatalog(config.rootPath);
      } catch (error) {
        throw MappingRuntimeUnavailable(
          rootPath: config.rootPath,
          paths: error is MappingStoreFailure ? error.paths : ['$error'],
          diagnostic: 'Canonical Mapping data store validation failed.',
          isReplica: false,
        );
      }
    }
    try {
      final session = await MappingRuntimeSelector(config.rootPath).launch();
      _sessions.add(session);
      return session.catalog;
    } on MappingRuntimeUnavailable {
      rethrow;
    } catch (error) {
      throw MappingRuntimeUnavailable(
        rootPath: config.rootPath,
        paths: [config.rootPath, '$error'],
        diagnostic: 'Local replica validation or selection failed.',
      );
    }
  }

  void close() {
    for (final session in _sessions) {
      session.close();
    }
  }
}
