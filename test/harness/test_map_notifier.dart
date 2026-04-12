import 'package:peak_bagger/providers/map_provider.dart';

class TestMapNotifier extends MapNotifier {
  TestMapNotifier(this.initialState);

  final MapState initialState;
  bool _snackbarConsumed = false;

  @override
  MapState build() => initialState;

  @override
  void toggleTracks() {
    if (state.tracks.isEmpty ||
        state.isLoadingTracks ||
        state.hasTrackRecoveryIssue) {
      return;
    }
    state = state.copyWith(showTracks: !state.showTracks);
  }

  @override
  Future<void> rescanTracks() async {
    state = state.copyWith(
      trackOperationStatus:
          'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 0',
      trackOperationWarning: null,
    );
  }

  @override
  Future<void> resetTrackData() async {
    state = state.copyWith(
      hasTrackRecoveryIssue: false,
      showTracks: false,
      tracks: const [],
      trackOperationStatus:
          'Imported 1, replaced 0, unchanged 0, non-Tasmanian 0, errors 0',
      trackOperationWarning: null,
    );
    _snackbarConsumed = false;
  }

  @override
  bool consumeRecoverySnackbarSignal() {
    if (!state.hasTrackRecoveryIssue || _snackbarConsumed) {
      return false;
    }
    _snackbarConsumed = true;
    return true;
  }
}
