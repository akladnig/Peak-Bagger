import 'dart:io';

import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/gpx_importer.dart';

/// The sole managed-file mutation boundary used by selective Track imports.
abstract interface class GpxManagedFileOperations {
  Future<String> resolveReplacementDestination({
    required String sourcePath,
    required GpxTrack replacementTrack,
  });

  Future<void> backupManagedFile({
    required String destinationPath,
    required String backupPath,
  });

  Future<void> moveIncomingFile({
    required String sourcePath,
    required String destinationPath,
  });

  Future<void> restoreIncomingFile({
    required String destinationPath,
    required String sourcePath,
  });

  Future<void> restoreManagedFile({
    required String backupPath,
    required String destinationPath,
  });

  Future<void> removeBackup(String backupPath);

  bool fileExists(String path);
}

class IoGpxManagedFileOperations implements GpxManagedFileOperations {
  IoGpxManagedFileOperations(this._importer);

  final GpxImporter _importer;

  @override
  Future<String> resolveReplacementDestination({
    required String sourcePath,
    required GpxTrack replacementTrack,
  }) =>
      _importer.resolveReplacementDestinationPath(sourcePath, replacementTrack);

  @override
  Future<void> backupManagedFile({
    required String destinationPath,
    required String backupPath,
  }) async {
    final destination = File(destinationPath);
    await destination.copy(backupPath);
    await destination.delete();
  }

  @override
  Future<void> moveIncomingFile({
    required String sourcePath,
    required String destinationPath,
  }) async {
    await File(sourcePath).rename(destinationPath);
  }

  @override
  Future<void> restoreIncomingFile({
    required String destinationPath,
    required String sourcePath,
  }) async {
    final destination = File(destinationPath);
    if (destination.existsSync()) {
      await destination.rename(sourcePath);
    }
  }

  @override
  Future<void> restoreManagedFile({
    required String backupPath,
    required String destinationPath,
  }) async {
    final destination = File(destinationPath);
    if (destination.existsSync()) {
      await destination.delete();
    }
    final backup = File(backupPath);
    if (backup.existsSync()) {
      await backup.rename(destinationPath);
    }
  }

  @override
  Future<void> removeBackup(String backupPath) => File(backupPath).delete();

  @override
  bool fileExists(String path) => File(path).existsSync();
}
