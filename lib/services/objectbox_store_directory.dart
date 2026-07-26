import 'dart:io';

import 'package:objectbox/objectbox.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:peak_bagger/services/directory_migration.dart';

Future<String?> resolvePrimaryObjectBoxDirectory({
  bool? isMacOS,
  DirectoryPathLoader? applicationSupportDirectoryPathLoader,
}) async {
  if (!(isMacOS ?? Platform.isMacOS)) {
    return null;
  }

  return resolveMacosApplicationSupportSubdirectory(
    directoryName: Store.defaultDirectoryPath,
    isMacOS: true,
    applicationSupportDirectoryPathLoader:
        applicationSupportDirectoryPathLoader ??
        () async => (await getApplicationSupportDirectory()).path,
  );
}

Future<String?> preparePrimaryObjectBoxDirectory({
  bool? isMacOS,
  DirectoryPathLoader? applicationSupportDirectoryPathLoader,
  DirectoryPathLoader? applicationDocumentsDirectoryPathLoader,
  void Function(String message)? log,
}) async {
  final targetDirectory = await resolvePrimaryObjectBoxDirectory(
    isMacOS: isMacOS,
    applicationSupportDirectoryPathLoader:
        applicationSupportDirectoryPathLoader,
  );
  if (targetDirectory == null) {
    return null;
  }

  final loadApplicationDocumentsDirectoryPath =
      applicationDocumentsDirectoryPathLoader ??
      () async => (await getApplicationDocumentsDirectory()).path;
  final legacyDirectory = p.join(
    await loadApplicationDocumentsDirectoryPath(),
    Store.defaultDirectoryPath,
  );
  await prepareMacosDirectoryCopyMigration(
    legacyDirectory: legacyDirectory,
    targetDirectory: targetDirectory,
    directoryLabel: 'Primary ObjectBox store',
    log: log,
  );
  return targetDirectory;
}
