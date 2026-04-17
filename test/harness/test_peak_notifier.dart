import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/peak_refresh_result.dart';

class TestPeakNotifier extends MapNotifier {
  TestPeakNotifier(
    this.initialState, {
    Future<PeakRefreshResult> Function()? refreshHandler,
  }) : _refreshHandler =
           refreshHandler ??
           (() async =>
               const PeakRefreshResult(importedCount: 1, skippedCount: 0));

  final MapState initialState;
  final Future<PeakRefreshResult> Function() _refreshHandler;
  int refreshCallCount = 0;

  @override
  MapState build() => initialState;

  @override
  Future<PeakRefreshResult> refreshPeaks() {
    refreshCallCount += 1;
    return _refreshHandler();
  }
}
