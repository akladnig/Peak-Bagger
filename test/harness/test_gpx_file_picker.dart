import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/services/gpx_file_picker.dart';

class FakeGpxFilePicker implements GpxFilePicker {
  FakeGpxFilePicker({
    this.filesToReturn,
    this.importRoot = '/tmp',
    this.errorToThrow,
  });

  final List<String>? filesToReturn;
  final String importRoot;
  final Object? errorToThrow;
  bool pickGpxFilesCalled = false;

  @override
  Future<List<String>?> pickGpxFiles() async {
    pickGpxFilesCalled = true;
    if (errorToThrow != null) {
      throw errorToThrow!;
    }
    return filesToReturn;
  }

  @override
  Future<String> resolveImportRoot() async => importRoot;
}

Provider<GpxFilePicker> fakeGpxFilePickerProvider({
  List<String>? filesToReturn,
  String importRoot = '/tmp',
  Object? errorToThrow,
}) {
  return Provider<GpxFilePicker>(
    (_) => FakeGpxFilePicker(
      filesToReturn: filesToReturn,
      importRoot: importRoot,
      errorToThrow: errorToThrow,
    ),
  );
}
