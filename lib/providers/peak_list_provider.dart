import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  throw UnimplementedError('peakListRepositoryProvider must be overridden');
});

final peaksBaggedRepositoryProvider = Provider<PeaksBaggedRepository>((ref) {
  return PeaksBaggedRepository(objectboxStore);
});

final peakListImportServiceProvider = Provider<PeakListImportService>((ref) {
  return PeakListImportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListRepositoryProvider),
  );
});

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  final service = ref.watch(peakListImportServiceProvider);
  return ({required String listName, required String csvPath}) async {
    final result = await service.importPeakList(
      listName: listName,
      csvPath: csvPath,
    );
    return PeakListImportPresentationResult(
      updated: result.updated,
      importedCount: result.importedCount,
      skippedCount: result.skippedCount,
      warningCount: result.warningEntries.length,
      warningMessage: result.warningMessage,
      peakListId: result.peakListId,
      listName: listName.trim(),
    );
  };
});

final peakListDuplicateNameCheckerProvider =
    Provider<PeakListDuplicateNameChecker>((ref) {
      final repository = ref.watch(peakListRepositoryProvider);
      return (name) async => repository.findByName(name.trim()) != null;
    });
