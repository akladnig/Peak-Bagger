import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_list_csv_export_service.dart';

typedef PeakListCsvExportRunner = Future<PeakListCsvExportResult> Function();

final peakListCsvExportServiceProvider = Provider<PeakListCsvExportService>((
  ref,
) {
  return PeakListCsvExportService(
    peakListRepository: ref.watch(peakListRepositoryProvider),
    peakRepository: ref.watch(peakRepositoryProvider),
  );
});

final peakListCsvExportRunnerProvider = Provider<PeakListCsvExportRunner>((
  ref,
) {
  final service = ref.watch(peakListCsvExportServiceProvider);
  return service.exportPeakLists;
});
