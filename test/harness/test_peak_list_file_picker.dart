import 'package:peak_bagger/services/peak_list_file_picker.dart';

class TestPeakListFilePicker implements PeakListFilePicker {
  TestPeakListFilePicker({
    this.selectedFilePath,
    this.importRoot = '/Users/test/Documents/Bushwalking',
    this.pickError,
  });

  final String? selectedFilePath;
  final String importRoot;
  final Object? pickError;

  int pickCallCount = 0;

  @override
  Future<String?> pickCsvFile() async {
    pickCallCount += 1;
    if (pickError != null) {
      throw pickError!;
    }
    return selectedFilePath;
  }

  @override
  Future<String> resolveImportRoot() async {
    return importRoot;
  }
}
