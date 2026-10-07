import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_region_asset_import_service.dart';

class TestPeakNotifier extends MapNotifier {
  TestPeakNotifier(
    this.initialState, {
    Future<PeakRegionAssetImportResult> Function()? updateHandler,
  }) : _updateHandler =
           updateHandler ??
           (() async => const PeakRegionAssetImportResult(
             importedRegions: ['tasmania'],
             importedPeakCount: 1,
             skippedPeakCount: 0,
           ));

  final MapState initialState;
  final Future<PeakRegionAssetImportResult> Function() _updateHandler;
  int refreshCallCount = 0;
  int reloadPeakMarkersCallCount = 0;

  @override
  MapState build() => initialState.copyWith(catalog: mappingCatalog);

  @override
  Future<void> reloadPeakMarkers() async {
    reloadPeakMarkersCallCount += 1;
    state = state.copyWith(isLoadingPeaks: false, clearError: true);
    reconcileSelectedPeakList();
  }

  @override
  Future<PeakRegionAssetImportResult> updatePeaks() {
    refreshCallCount += 1;
    return _updateHandler();
  }
}
