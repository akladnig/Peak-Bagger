import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/data_export_file_picker.dart';
import 'package:peak_bagger/services/data_export_service.dart';

final dataExportFilePickerProvider = Provider<DataExportFilePicker>((ref) {
  return PlatformDataExportFilePicker();
});

final dataExportFileSystemProvider = Provider<DataExportFileSystem>((ref) {
  return LocalDataExportFileSystem();
});

final dataExportClockProvider = Provider<DateTime Function()>((ref) {
  return DateTime.now;
});

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  return DefaultDataExportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListRepositoryProvider),
    fileSystem: ref.watch(dataExportFileSystemProvider),
    clock: ref.watch(dataExportClockProvider),
  );
});
