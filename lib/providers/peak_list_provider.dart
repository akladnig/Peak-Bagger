import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

typedef PeakListImportBackgroundRunner =
    Future<PeakListImportPresentationResult> Function({
      required String listName,
      required String csvPath,
      PeakListImportProgressCallback? onProgress,
    });

typedef PeakListMembershipRefreshRunner = void Function();

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  return PeakListRepository.test(InMemoryPeakListStorage());
});

final peakListMutationRepositoryProvider = Provider<PeakListRepository>((ref) {
  return ref.watch(peakListRepositoryProvider);
});

final peaksBaggedRepositoryProvider = Provider<PeaksBaggedRepository>((ref) {
  return PeaksBaggedRepository(objectboxStore);
});

final peaksBaggedRevisionProvider =
    NotifierProvider<PeaksBaggedRevisionNotifier, int>(
      PeaksBaggedRevisionNotifier.new,
    );

final peakListImportServiceProvider = Provider<PeakListImportService>((ref) {
  return PeakListImportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListMutationRepositoryProvider),
  );
});

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  final backgroundRunner = ref.watch(peakListImportBackgroundRunnerProvider);
  return ({required String listName, required String csvPath}) async {
    return backgroundRunner(listName: listName, csvPath: csvPath);
  };
});

final peakListImportBackgroundRunnerProvider =
    Provider<PeakListImportBackgroundRunner>((ref) {
      final service = ref.watch(peakListImportServiceProvider);
      return ({
        required String listName,
        required String csvPath,
        PeakListImportProgressCallback? onProgress,
      }) async {
        final result = await service.importPeakList(
          listName: listName,
          csvPath: csvPath,
          onProgress: onProgress,
        );
        ref.read(peakListRevisionProvider.notifier).increment();
        await ref.read(mapProvider.notifier).reloadPeakMarkers();
        return PeakListImportPresentationResult(
          updated: result.updated,
          importedCount: result.importedCount,
          skippedCount: result.skippedCount,
          matchedCount: result.matchedCount,
          ambiguousCount: result.ambiguousCount,
          warningCount: result.warningEntries.length,
          warningMessage: result.warningMessage,
          logEntryCount: result.logEntries.length,
          importLogNote: result.logEntries.isEmpty
              ? null
              : (result.warningMessage ?? 'See import.log for details.'),
          peakListId: result.peakListId,
          listName: listName.trim(),
        );
      };
    });

final peakListMembershipRefreshRunnerProvider =
    Provider<PeakListMembershipRefreshRunner>((ref) {
      return () {
        ref.read(peakListRevisionProvider.notifier).increment();
        final mapNotifier = ref.read(mapProvider.notifier);
        mapNotifier.reconcileSelectedPeakList();
        mapNotifier.refreshPeakInfoPopupContent();
      };
    });

final peakListDuplicateNameCheckerProvider =
    Provider<PeakListDuplicateNameChecker>((ref) {
      final repository = ref.watch(peakListRepositoryProvider);
      return (name) async => repository.findByName(name.trim()) != null;
    });

class PeaksBaggedRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void increment() {
    state += 1;
  }
}
