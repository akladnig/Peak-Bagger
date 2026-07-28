import 'dart:io';

import 'package:path/path.dart' as p;

typedef DirectoryPathLoader = Future<String> Function();

Future<String?> resolveMacosApplicationSupportSubdirectory({
  required String directoryName,
  bool? isMacOS,
  DirectoryPathLoader? applicationSupportDirectoryPathLoader,
}) async {
  if (!(isMacOS ?? Platform.isMacOS)) {
    return null;
  }

  final loadApplicationSupportDirectoryPath =
      applicationSupportDirectoryPathLoader ??
      () async => throw UnimplementedError();
  final applicationSupportDirectoryPath =
      await loadApplicationSupportDirectoryPath();
  return p.join(applicationSupportDirectoryPath, directoryName);
}

Future<void> prepareMacosDirectoryCopyMigration({
  required String legacyDirectory,
  required String targetDirectory,
  required String directoryLabel,
  void Function(String message)? log,
}) async {
  if (legacyDirectory == targetDirectory) {
    return;
  }

  final target = Directory(targetDirectory);
  if (await target.exists()) {
    log?.call(
      '$directoryLabel migration skipped because target already exists: '
      '$targetDirectory',
    );
    return;
  }

  final legacy = Directory(legacyDirectory);
  if (!await legacy.exists()) {
    log?.call(
      '$directoryLabel migration skipped because legacy store was not found: '
      '$legacyDirectory',
    );
    return;
  }

  log?.call(
    'Migrating $directoryLabel from $legacyDirectory to $targetDirectory',
  );
  try {
    await copyDirectoryRecursively(source: legacy, destination: target);
  } catch (_) {
    if (await target.exists()) {
      await target.delete(recursive: true);
    }
    rethrow;
  }
  log?.call('Finished $directoryLabel migration');
}

Future<void> copyDirectoryRecursively({
  required Directory source,
  required Directory destination,
}) async {
  await destination.create(recursive: true);

  await for (final entity in source.list(followLinks: false)) {
    final targetPath = p.join(destination.path, p.basename(entity.path));
    if (entity is Directory) {
      await copyDirectoryRecursively(
        source: entity,
        destination: Directory(targetPath),
      );
      continue;
    }
    if (entity is File) {
      await entity.copy(targetPath);
      continue;
    }

    throw UnsupportedError(
      'Unsupported filesystem entity in directory migration: ${entity.path}',
    );
  }
}
