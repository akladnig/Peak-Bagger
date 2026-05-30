import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/route.dart' as app_route;
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/widgets/map_tracks_routes_drawer.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('whole-row tap toggles tracks and routes when available', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        tracks: [
          GpxTrack(contentHash: 'hash', trackName: 'Track 1', gpxFile: '<gpx></gpx>'),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(
              InMemoryRouteStorage([app_route.Route(name: 'Route 1')]),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Show Tracks'));
    await tester.pump();
    expect(notifier.state.showTracks, isTrue);

    await tester.tap(find.text('Show Routes'));
    await tester.pump();
    expect(notifier.state.showRoutes, isTrue);

    await tester.tap(find.text('Show Trails'));
    await tester.pump();
    expect(notifier.state.showTrails, isTrue);
  });

  testWidgets('disabled switches keep stored values and show helper text', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
        showTracks: true,
        showRoutes: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(InMemoryRouteStorage()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No tracks loaded'), findsOneWidget);
    expect(find.text('No routes available'), findsOneWidget);

    final tracksSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-tracks-switch')),
    );
    final routesSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-routes-switch')),
    );
    expect(tracksSwitch.value, isTrue);
    expect(tracksSwitch.onChanged, isNull);
    expect(routesSwitch.value, isTrue);
    expect(routesSwitch.onChanged, isNull);
  });

  testWidgets('show trails is disabled when route graph is unavailable', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeGraphReadinessProvider.overrideWith(
            () => _FailedRouteGraphReadinessNotifier(),
          ),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(InMemoryRouteStorage()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.text('Route graph unavailable. Use Refresh Route Graph to retry.'),
      findsOneWidget,
    );

    final trailsSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-trails-switch')),
    );
    expect(trailsSwitch.value, isFalse);
    expect(trailsSwitch.onChanged, isNull);
  });

  testWidgets('show trails stays enabled while route graph is preloading', (
    tester,
  ) async {
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          routeGraphReadinessProvider.overrideWith(
            () => _PreloadingRouteGraphReadinessNotifier(),
          ),
          routeRepositoryProvider.overrideWithValue(
            RouteRepository.test(InMemoryRouteStorage()),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: MapTracksRoutesDrawer()),
        ),
      ),
    );
    await tester.pump();

    final trailsSwitch = tester.widget<Switch>(
      find.byKey(const Key('show-trails-switch')),
    );
    expect(trailsSwitch.onChanged, isNotNull);
  });
}

class _FailedRouteGraphReadinessNotifier extends RouteGraphReadinessNotifier {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.failed('route graph unavailable');
  }
}

class _PreloadingRouteGraphReadinessNotifier
    extends RouteGraphReadinessNotifier {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.preloading();
  }
}
