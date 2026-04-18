import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/gpx_importer.dart';
import 'package:peak_bagger/services/gpx_track_statistics_calculator.dart';

class TestMapNotifier extends MapNotifier {
  TestMapNotifier(
    this.initialState, {
    this.rescanStatus =
        'Imported 1, replaced 0, unchanged 0, non-Tasmanian 2, errors 0',
    this.rescanWarning,
    this.rescanSnackbarMessage,
    this.recalcUpdatedCount = 1,
    this.recalcSkippedCount = 0,
    this.recalcWarning,
    this.recalcTracks,
    Set<int> correlatedPeakIds = const {},
  }) : _correlatedPeakIds = correlatedPeakIds;

  final MapState initialState;
  final String rescanStatus;
  final String? rescanWarning;
  final String? rescanSnackbarMessage;
  final int recalcUpdatedCount;
  final int recalcSkippedCount;
  final String? recalcWarning;
  final List<GpxTrack>? recalcTracks;
  final Set<int> _correlatedPeakIds;
  bool _snackbarConsumed = false;
  String? _trackSnackbarMessage;

  @override
  MapState build() => initialState;

  @override
  Set<int> get correlatedPeakIds => _correlatedPeakIds;

  @override
  void toggleTracks() {
    if (state.tracks.isEmpty ||
        state.isLoadingTracks ||
        state.hasTrackRecoveryIssue) {
      return;
    }
    state = state.copyWith(
      showTracks: !state.showTracks,
      clearHoveredTrackId: true,
      clearSelectedTrackId: state.showTracks,
    );
  }

  @override
  void updatePosition(LatLng center, double zoom) {
    state = state.copyWith(
      center: center,
      zoom: zoom,
      clearHoveredTrackId: true,
    );
  }

  @override
  void searchPeaks(String query) {
    final lowered = query.toLowerCase();
    final results = state.peaks
        .where((peak) {
          final nameMatch = peak.name.toLowerCase().contains(lowered);
          final elevMatch =
              peak.elevation != null &&
              peak.elevation!.toString().contains(query);
          return query.isEmpty || nameMatch || elevMatch;
        })
        .toList(growable: false);

    state = state.copyWith(searchQuery: query, searchResults: results);
  }

  @override
  void clearSearch() {
    state = state.copyWith(searchQuery: '', searchResults: const []);
  }

  @override
  void toggleInfoPopup() {
    final isVisible = state.showInfoPopup;
    state = state.copyWith(
      showInfoPopup: !isVisible,
      clearInfoPopup: isVisible,
    );
  }

  @override
  void centerOnPeak(Peak peak) {
    state = state.copyWith(
      center: LatLng(peak.latitude, peak.longitude),
      zoom: 15,
      syncEnabled: true,
      selectedPeaks: [peak],
      clearHoveredTrackId: true,
    );
  }

  @override
  Future<void> rescanTracks() async {
    _trackSnackbarMessage = rescanSnackbarMessage ?? rescanStatus;
    state = state.copyWith(
      trackOperationStatus: rescanStatus,
      trackOperationWarning: rescanWarning,
      clearSelectedTrackId: true,
    );
  }

  @override
  Future<TrackImportResult?> resetTrackData() async {
    state = state.copyWith(
      hasTrackRecoveryIssue: false,
      showTracks: false,
      tracks: const [],
      trackOperationStatus:
          'Imported 1, replaced 0, unchanged 0, non-Tasmanian 0, errors 0',
      trackOperationWarning: null,
      clearHoveredTrackId: true,
      clearSelectedTrackId: true,
    );
    _snackbarConsumed = false;
    return const TrackImportResult(
      tracks: [],
      importedCount: 1,
      replacedCount: 0,
      unchangedCount: 0,
      nonTasmanianCount: 0,
      errorSkippedCount: 0,
    );
  }

  @override
  Future<TrackStatisticsRecalcResult?> recalculateTrackStatistics() async {
    state = state.copyWith(
      isLoadingTracks: false,
      tracks: recalcTracks ?? state.tracks,
      trackOperationStatus:
          'Updated $recalcUpdatedCount tracks, refreshed peak correlation, skipped $recalcSkippedCount tracks',
      trackOperationWarning: recalcWarning,
      clearSelectedTrackId: true,
    );
    return TrackStatisticsRecalcResult(
      updatedCount: recalcUpdatedCount,
      skippedCount: recalcSkippedCount,
      warning: recalcWarning,
    );
  }

  @override
  bool consumeRecoverySnackbarSignal() {
    if (!state.hasTrackRecoveryIssue || _snackbarConsumed) {
      return false;
    }
    _snackbarConsumed = true;
    return true;
  }

  @override
  String? consumeTrackSnackbarMessage() {
    final message = _trackSnackbarMessage;
    _trackSnackbarMessage = null;
    return message;
  }
}
