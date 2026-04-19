import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

abstract class PeakListFilePicker {
  Future<String> resolveImportRoot();

  Future<String?> pickCsvFile();
}

final peakListFilePickerProvider = Provider<PeakListFilePicker>((ref) {
  return PlatformPeakListFilePicker();
});

class PlatformPeakListFilePicker implements PeakListFilePicker {
  @override
  Future<String?> pickCsvFile() async {
    final initialDirectory = await resolveImportRoot();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      dialogTitle: 'Select Peak Lists',
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: const ['csv'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.single.path;
  }

  @override
  Future<String> resolveImportRoot() async {
    final home = _resolveHomeDirectory();
    if (home == null) {
      return Directory.current.path;
    }

    final documentsBushwalking = p.join(home, 'Documents', 'Bushwalking');
    if (Directory(documentsBushwalking).existsSync()) {
      return documentsBushwalking;
    }

    return home;
  }

  String? _resolveHomeDirectory() {
    final home = Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      return home;
    }

    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.isNotEmpty) {
      return userProfile;
    }

    return null;
  }
}
