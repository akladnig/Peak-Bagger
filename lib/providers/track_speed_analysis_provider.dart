import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_planner_provider.dart';
import 'package:peak_bagger/services/track_speed_analysis_service.dart';

final trackSpeedAnalysisServiceProvider = Provider<TrackSpeedAnalysisService?>(
  (ref) {
    final routeGraphQueryService = ref.watch(routeGraphQueryServiceProvider);
    if (routeGraphQueryService == null) {
      return null;
    }

    return TrackSpeedAnalysisService(
      gpxTrackRepository: ref.watch(gpxTrackRepositoryProvider),
      routeGraphQueryService: routeGraphQueryService,
    );
  },
);

final trackSpeedAnalysisRunnerProvider = Provider<TrackSpeedAnalysisRunner>((
  ref,
) {
  final service = ref.watch(trackSpeedAnalysisServiceProvider);
  if (service == null) {
    return const _UnavailableTrackSpeedAnalysisRunner();
  }
  return _TrackSpeedAnalysisServiceRunner(service);
});

abstract interface class TrackSpeedAnalysisRunner {
  Future<TrackSpeedAnalysisReport> analyze({
    void Function(TrackSpeedAnalysisProgress progress)? onProgress,
  });
}

class TrackSpeedAnalysisUnavailableException implements Exception {
  const TrackSpeedAnalysisUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

class _TrackSpeedAnalysisServiceRunner implements TrackSpeedAnalysisRunner {
  const _TrackSpeedAnalysisServiceRunner(this._service);

  final TrackSpeedAnalysisService _service;

  @override
  Future<TrackSpeedAnalysisReport> analyze({
    void Function(TrackSpeedAnalysisProgress progress)? onProgress,
  }) {
    return _service.analyzeWithProgress(onProgress: onProgress);
  }
}

class _UnavailableTrackSpeedAnalysisRunner implements TrackSpeedAnalysisRunner {
  const _UnavailableTrackSpeedAnalysisRunner();

  @override
  Future<TrackSpeedAnalysisReport> analyze({
    void Function(TrackSpeedAnalysisProgress progress)? onProgress,
  }) {
    return Future<TrackSpeedAnalysisReport>.error(
      const TrackSpeedAnalysisUnavailableException(
        'Track speed analysis is unavailable.',
      ),
    );
  }
}
