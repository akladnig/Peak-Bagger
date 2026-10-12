import '../providers/map_provider.dart';
import 'dart:developer' as developer;

/// One accepted placement. The screen owns its lifetime and only emits after
/// a frame whose geometry and statistics still match the current request.
class RoutePlacementMeasurement {
  RoutePlacementMeasurement({
    required this.mode,
    required this.ordinaryStart,
    required this.beforeDistanceMeters,
    required this.beforeGeometryVersion,
    this.modeAction = false,
  }) : clock = Stopwatch()..start(),
       acceptedDartUs = developer.Timeline.now;

  final Stopwatch clock;
  final int acceptedDartUs;
  final RouteMode mode;
  final bool ordinaryStart;
  final double beforeDistanceMeters;
  final int beforeGeometryVersion;
  final bool modeAction;
  bool frameScheduled = false;

  bool isComplete(MapState state) {
    if (!state.isRouteDrafting ||
        state.routeDraftStage != RouteDraftStage.awaitingNextPoint) {
      return false;
    }
    if (ordinaryStart) return state.routeDraftControlEndpoints.isNotEmpty;
    final summary = state.routeDraftElevationSummary;
    return state.routeDraftCommittedPoints.length >= 2 &&
        state.routeDraftGeometryVersion > beforeGeometryVersion &&
        !state.routeDraftElevationLoading &&
        state.routeDraftElevationError == null &&
        summary != null &&
        summary.requestId == state.routeDraftElevationRequestId &&
        summary.geometryVersion == state.routeDraftGeometryVersion &&
        state.routeDraftPointElevations.length ==
            state.routeDraftCommittedPoints.length;
  }
}
