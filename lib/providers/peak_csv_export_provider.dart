import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_csv_export_service.dart';

typedef PeakCsvExportRunner = Future<PeakCsvExportResult> Function();
typedef PeakCsvExportBackgroundRunner =
    Future<PeakCsvExportResult> Function({
      PeakCsvExportProgressCallback? onProgress,
    });

final peakCsvExportServiceProvider = Provider<PeakCsvExportService>((ref) {
  return PeakCsvExportService(
    peakRepository: ref.watch(peakRepositoryProvider),
  );
});

final peakCsvExportRunnerProvider = Provider<PeakCsvExportRunner>((ref) {
  final backgroundRunner = ref.watch(peakCsvExportBackgroundRunnerProvider);
  return () => backgroundRunner();
});

final peakCsvExportBackgroundRunnerProvider =
    Provider<PeakCsvExportBackgroundRunner>((ref) {
  final service = ref.watch(peakCsvExportServiceProvider);
  return ({PeakCsvExportProgressCallback? onProgress}) {
    return service.exportPeaks(onProgress: onProgress);
  };
});
