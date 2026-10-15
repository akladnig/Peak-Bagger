import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:peak_bagger/services/mapping_store_core.dart';

/// Narrow snapshot-read/export-write adapter; callers supply resolver-authorized
/// source opens. No publication or deletion API targets the canonical store.
class MappingSourceIo {
  Future<void> copy(
    String source,
    String destination, {
    required String sourceRoot,
  }) async {
    await requireNonMappingPath(destination, rootPath: sourceRoot);
    await requireNonMappingPath(destination);
    final checkout = Platform.script.path.endsWith('.dart')
        ? p.normalize(p.join(p.dirname(Platform.script.toFilePath()), '..'))
        : Directory.current.path;
    if (p.equals(checkout, destination) || p.isWithin(checkout, destination)) {
      throw StateError(
        'Export target is under the source checkout: $destination',
      );
    }
    for (final parent in [
      p.dirname(checkout),
      '${Platform.environment['HOME']}/Development/mapping',
      '/Volumes/Development/mapping',
    ]) {
      for (final name in [
        'peak_bagger',
        'trip_routing',
        'flutter_map_tile_caching',
      ]) {
        final workspace = p.join(parent, name);
        if (p.equals(workspace, destination) ||
            p.isWithin(workspace, destination)) {
          throw StateError(
            'Export target is under a source-workspace synchronization root: $destination',
          );
        }
      }
    }
    await rejectLinks(destination);
    await Directory(p.dirname(destination)).create(recursive: true);
    if (await FileSystemEntity.type(destination, followLinks: false) !=
        FileSystemEntityType.notFound) {
      throw StateError('Capture target already exists: $destination');
    }
    await File(source).copy(destination);
    final handle = await File(destination).open(mode: FileMode.append);
    try {
      await handle.flush();
    } finally {
      await handle.close();
    }
  }

  Future<void> rejectLinks(String target) async {
    var current = p.absolute(target);
    while (true) {
      if (await FileSystemEntity.type(current, followLinks: false) ==
          FileSystemEntityType.link) {
        throw FileSystemException('Export path contains symlink', current);
      }
      final parent = p.dirname(current);
      if (parent == current) break;
      current = parent;
    }
  }
}
