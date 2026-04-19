import 'package:peak_bagger/services/peak_list_file_picker.dart';

class TestPeakListFilePicker implements PeakListFilePicker {
  TestPeakListFilePicker({
    this.selectedFilePath,
    this.importRoot = '/Users/test/Documents/Bushwalking',
  });

  final String? selectedFilePath;
  final String importRoot;

  int pickCallCount = 0;

  @override
  Future<String?> pickCsvFile() async {
    pickCallCount += 1;
    return selectedFilePath;
  }

  @override
  Future<String> resolveImportRoot() async {
    return importRoot;
  }
}
