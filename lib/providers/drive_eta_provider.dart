import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_planner_provider.dart';
import 'package:peak_bagger/services/live_location_service.dart';
import 'package:peak_bagger/services/open_route_service.dart';
import 'package:peak_bagger/services/route_graph_drive_eta_hit_service.dart';
import 'package:peak_bagger/services/route_graph_store.dart';

final liveLocationServiceProvider = Provider<LiveLocationService>((ref) {
  return const GeolocatorLiveLocationService();
});

final openRouteServiceProvider = Provider<OpenRouteService>((ref) {
  return HttpOpenRouteService(
    apiKey: const String.fromEnvironment('OPENROUTESERVICE_API_KEY'),
  );
});

final routeGraphDriveEtaHitServiceProvider =
    Provider<RouteGraphDriveEtaHitService?>((ref) {
      final queryService = ref.read(routeGraphQueryServiceProvider);
      if (queryService == null) {
        return null;
      }
      return RouteGraphDriveEtaHitService(queryService);
    });

final driveEtaRouteGraphUnavailableReasonProvider = Provider<String?>((ref) {
  final readiness = ref.read(routeGraphReadinessProvider);
  if (readiness.status == RouteGraphReadinessStatus.failed) {
    return readiness.error ?? 'Route graph data is unavailable.';
  }

  RouteGraphStore store;
  try {
    store = ref.read(routeGraphStoreProvider);
  } catch (_) {
    return 'Route graph data is unavailable.';
  }

  if (store is! RouteGraphRepositoryProvider) {
    return 'Route graph data is unavailable.';
  }

  final repository = (store as RouteGraphRepositoryProvider).repository;
  if (repository == null || !repository.hasUsableActiveGeneration) {
    return 'Route graph data is unavailable.';
  }

  return null;
});
