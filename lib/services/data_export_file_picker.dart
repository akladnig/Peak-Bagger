import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

abstract class DataExportFilePicker {
  Future<String> resolveDefaultExportRoot();

  Future<String?> pickOutputDirectory();
}

class PlatformDataExportFilePicker implements DataExportFilePicker {
  @override
  Future<String?> pickOutputDirectory() async {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select Export Folder',
      initialDirectory: await resolveDefaultExportRoot(),
    );
  }

  @override
  Future<String> resolveDefaultExportRoot() async {
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
