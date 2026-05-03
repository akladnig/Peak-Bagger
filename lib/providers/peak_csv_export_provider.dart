import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_csv_export_service.dart';

typedef PeakCsvExportRunner = Future<PeakCsvExportResult> Function();

final peakCsvExportServiceProvider = Provider<PeakCsvExportService>((ref) {
  return PeakCsvExportService(
    peakRepository: ref.watch(peakRepositoryProvider),
  );
});

final peakCsvExportRunnerProvider = Provider<PeakCsvExportRunner>((ref) {
  final service = ref.watch(peakCsvExportServiceProvider);
  return service.exportPeaks;
});
