import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/main.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/services/peak_list_import_service.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/tassy_full_peak_list_sync_service.dart';
import 'package:peak_bagger/widgets/peak_list_import_dialog.dart';

final peakListRepositoryProvider = Provider<PeakListRepository>((ref) {
  throw UnimplementedError('peakListRepositoryProvider must be overridden');
});

final peakListMutationRepositoryProvider = Provider<PeakListRepository>((ref) {
  final repository = ref.watch(peakListRepositoryProvider);
  return _AutoRefreshingPeakListRepository(
    repository,
    onTassyFullRefreshed: () {
      ref.read(peakListRevisionProvider.notifier).increment();
      ref.read(mapProvider.notifier).reconcileSelectedPeakList();
    },
  );
});

final peaksBaggedRepositoryProvider = Provider<PeaksBaggedRepository>((ref) {
  return PeaksBaggedRepository(objectboxStore);
});

final peakListImportServiceProvider = Provider<PeakListImportService>((ref) {
  return PeakListImportService(
    peakRepository: ref.watch(peakRepositoryProvider),
    peakListRepository: ref.watch(peakListMutationRepositoryProvider),
  );
});

final peakListImportRunnerProvider = Provider<PeakListImportRunner>((ref) {
  final service = ref.watch(peakListImportServiceProvider);
  return ({required String listName, required String csvPath}) async {
    final result = await service.importPeakList(
      listName: listName,
      csvPath: csvPath,
    );
    ref.read(peakListRevisionProvider.notifier).increment();
    ref.read(mapProvider.notifier).reconcileSelectedPeakList();
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

class _AutoRefreshingPeakListRepository extends PeakListRepository {
  _AutoRefreshingPeakListRepository(
    PeakListRepository base, {
    required void Function() onTassyFullRefreshed,
  }) : _onTassyFullRefreshed = onTassyFullRefreshed,
       super.test(base.storage);

  static const String _tassyFullName = TassyFullPeakListSyncService.targetName;

  final void Function() _onTassyFullRefreshed;

  @override
  Future<PeakList> save(
    PeakList peakList, {
    void Function()? beforePutForTest,
  }) async {
    final saved = await super.save(
      peakList,
      beforePutForTest: beforePutForTest,
    );
    await _refreshAfterMutation(saved.name);
    return saved;
  }

  @override
  Future<void> delete(int peakListId) async {
    await super.delete(peakListId);
    await _refreshTassyFull();
  }

  Future<void> _refreshAfterMutation(String peakListName) async {
    if (peakListName == _tassyFullName) {
      return;
    }

    await _refreshTassyFull();
  }

  Future<void> _refreshTassyFull() async {
    try {
      await refreshTassyFullPeakList();
      _onTassyFullRefreshed();
    } catch (error, stackTrace) {
      developer.log(
        'Failed to refresh Tassy Full peak list after mutation.',
        error: error,
        stackTrace: stackTrace,
        name: 'peak_list_provider',
      );
    }
  }
}
