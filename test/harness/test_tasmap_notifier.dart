import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/services/csv_importer.dart';
import 'package:peak_bagger/services/tasmap_repository.dart';

class TestTasmapNotifier extends TasmapNotifier {
  TestTasmapNotifier(this.repository);

  final TasmapRepository repository;

  @override
  TasmapState build() => const TasmapState();

  @override
  Future<TasmapCsvImportResult> resetAndReimport() async {
    state = state.copyWith(
      mapCount: repository.mapCount,
      tasmapRevision: state.tasmapRevision + 1,
    );
    return TasmapCsvImportResult(
      maps: repository.getAllMaps(),
      importedCount: repository.mapCount,
      skippedCount: 0,
    );
  }
}
