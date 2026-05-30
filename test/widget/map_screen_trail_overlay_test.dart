import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/models/route_graph_chunk.dart';
import 'package:peak_bagger/models/route_graph_manifest.dart';
import 'package:peak_bagger/models/route_graph_trail_display_chunk.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/route_graph_readiness_provider.dart';
import 'package:peak_bagger/providers/route_repository_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';
import 'package:peak_bagger/services/route_graph_repository.dart';
import 'package:peak_bagger/services/route_graph_store.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/theme.dart';
import 'package:trip_routing/trip_routing.dart' as trip_routing;

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('map screen uses rounded cache zoom for trail overlay', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final mapNotifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15.6,
        basemap: Basemap.tracestrack,
      ),
    );

    await _pumpMapScreen(
      tester,
      mapNotifier: mapNotifier,
      routeGraphStore: _TrailCacheRouteGraphStore(),
      tasmapRepository: repository,
    );

    mapNotifier.setShowTrails(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final layer = tester.widget<PolylineLayer>(
      find.byKey(const Key('trail-polyline-layer')),
    );
    expect(layer.polylines, hasLength(2));
    expect(layer.polylines.first.points, const [
      LatLng(-41.5, 146.5),
      LatLng(-41.55, 146.55),
      LatLng(-41.6, 146.6),
    ]);
  });

  testWidgets('map screen hides trails when route graph is not ready', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();

    await _pumpMapScreen(
      tester,
      mapNotifier: TestMapNotifier(
        MapState(
          center: const LatLng(-41.5, 146.5),
          zoom: 15.6,
          basemap: Basemap.tracestrack,
          showTrails: true,
        ),
      ),
      routeGraphStore: _TrailCacheRouteGraphStore(),
      tasmapRepository: repository,
      readinessOverride: () => _FailedRouteGraphReadinessNotifier(),
    );

    expect(find.byKey(const Key('trail-polyline-layer')), findsNothing);
  });
}

Future<void> _pumpMapScreen(
  WidgetTester tester, {
  required TestMapNotifier mapNotifier,
  required RouteGraphStore routeGraphStore,
  required TestTasmapRepository tasmapRepository,
  RouteGraphReadinessNotifier Function()? readinessOverride,
}) async {
  await tester.binding.setSurfaceSize(const Size(1600, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(() => mapNotifier),
        routeGraphStoreProvider.overrideWithValue(routeGraphStore),
        routeRepositoryProvider.overrideWithValue(
          RouteRepository.test(InMemoryRouteStorage()),
        ),
        peakListRepositoryProvider.overrideWithValue(
          PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapRepositoryProvider.overrideWithValue(tasmapRepository),
        tasmapStateProvider.overrideWith(() => TestTasmapNotifier(tasmapRepository)),
        gpxTrackRepositoryProvider.overrideWithValue(
          GpxTrackRepository.test(InMemoryGpxTrackStorage()),
        ),
        if (readinessOverride != null)
          routeGraphReadinessProvider.overrideWith(readinessOverride),
      ],
      child: MaterialApp(theme: CatppuccinColors.dark, home: MapScreen()),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

class _TrailCacheRouteGraphStore
    implements RouteGraphStore, RouteGraphRepositoryProvider {
  _TrailCacheRouteGraphStore()
    : repository = RouteGraphRepository.test(
        InMemoryRouteGraphStorage(
          manifest: RouteGraphManifest(
            activeGeneration: 1,
            readinessState: RouteGraphManifest.readinessReady,
          ),
          chunks: [
            RouteGraphChunk(
              recordKey: '1|0_0',
              chunkKey: '0_0',
              generation: 1,
              minLat: -42.0,
              minLon: 146.0,
              maxLat: -41.0,
              maxLon: 147.0,
              elementCount: 0,
              payloadJson: '{"elements":[]}',
            ),
          ],
          trailDisplayChunks: [
            RouteGraphTrailDisplayChunk(
              recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
                generation: 1,
                cacheZoom: 15,
                chunkKey: '0_0',
              ),
              generation: 1,
              cacheZoom: 15,
              chunkKey: '0_0',
              payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
                const RouteGraphTrailDisplayWay(
                  osmWayId: 10,
                  points: [
                    LatLng(-41.5, 146.5),
                    LatLng(-41.6, 146.6),
                  ],
                ),
              ]),
            ),
            RouteGraphTrailDisplayChunk(
              recordKey: RouteGraphTrailDisplayChunk.recordKeyFor(
                generation: 1,
                cacheZoom: 16,
                chunkKey: '0_0',
              ),
              generation: 1,
              cacheZoom: 16,
              chunkKey: '0_0',
              payloadJson: RouteGraphTrailDisplayChunk.encodeWays([
                const RouteGraphTrailDisplayWay(
                  osmWayId: 10,
                  points: [
                    LatLng(-41.5, 146.5),
                    LatLng(-41.55, 146.55),
                    LatLng(-41.6, 146.6),
                  ],
                ),
              ]),
            ),
          ],
        ),
      );

  @override
  final RouteGraphRepository repository;

  @override
  Future<trip_routing.TripService> preload() async => trip_routing.TripService();

  @override
  Future<trip_routing.TripService> reload() async => trip_routing.TripService();

  @override
  Future<void> replaceSnapshot(String rawJson) async {}

  @override
  Future<File> snapshotFile() => throw UnimplementedError();
}

class _FailedRouteGraphReadinessNotifier extends RouteGraphReadinessNotifier {
  @override
  RouteGraphReadinessState build() {
    return const RouteGraphReadinessState.failed('route graph unavailable');
  }
}
