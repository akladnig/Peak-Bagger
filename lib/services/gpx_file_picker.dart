import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_path_helpers.dart';

abstract class GpxFilePicker {
  Future<String> resolveImportRoot();

  Future<List<String>?> pickGpxFiles();
}

final gpxFilePickerProvider = Provider<GpxFilePicker>((ref) {
  return PlatformGpxFilePicker();
});

class PlatformGpxFilePicker implements GpxFilePicker {
  @override
  Future<List<String>?> pickGpxFiles() async {
    final initialDirectory = await resolveImportRoot();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      dialogTitle: 'Select GPX Files',
      initialDirectory: initialDirectory,
      type: FileType.custom,
      allowedExtensions: const ['gpx'],
    );

    if (result == null || result.files.isEmpty) {
      return null;
    }

    return result.files.map((f) => f.path).whereType<String>().toList();
  }

  @override
  Future<String> resolveImportRoot() async {
    return resolveBushwalkingRoot();
  }
}
