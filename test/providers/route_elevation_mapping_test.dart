import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/mapping_store_operation_provider.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
import 'package:peak_bagger/services/mapping_data_store.dart';
import 'package:peak_bagger/services/mapping_store_operation_coordinator.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/peaks_bagged_repository.dart';
import 'package:peak_bagger/services/route_elevation_sampler.dart';
import 'package:peak_bagger/services/route_planner.dart';
import 'package:peak_bagger/services/route_repository.dart';
import 'package:peak_bagger/widgets/map_route_bottom_sheet.dart';

import '../harness/route_elevation_fixture.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  test(
    'default sampler requires the ready-scope catalog but opens no DEM at construction',
    () {
      final container = ProviderContainer(
        overrides: [
          mappingCatalogProvider.overrideWithValue(elevationMappingCatalog),
        ],
      );
      addTearDown(container.dispose);
      expect(
        container.read(routeElevationSamplerProvider),
        isA<RegionAwareRouteElevationSampler>(),
      );
    },
  );

  for (final failure in FakeDemAccessFailure.values) {
    test(
      'draft $failure failure retains route state and retries original geometry',
      () async {
        final fs = FakeDemFileSystem()..failure = failure;
        final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
        final container = await _container(_sampler(fs, opener));
        addTearDown(container.dispose);
        final notifier = container.read(mapProvider.notifier);
        final coordinator = container.read(
          mappingStoreOperationCoordinatorProvider,
        );
        _startRoute(notifier);
        await _settle();

        final state = container.read(mapProvider);
        expect(state.routeDraftElevationLoading, isFalse);
        expect(state.routeDraftElevationError, contains(elvisRuntimePath));
        expect(state.routeDraftCommittedPoints, elevationRoutePoints);
        expect(state.routeDraftDistanceMeters, greaterThan(0));
        expect(state.routeDraftPointElevations, isEmpty);
        expect(opener.openedPaths, isEmpty);
        final failureEntry = coordinator.activeFailure!;
        expect(failureEntry.key.kind, MappingStoreOperationKind.demRead);
        expect(failureEntry.key.parameters, {
          'demSourceKey': 'elvisRuntime',
          'routeGeometryIdentity': '[[-41.5,146.5],[-41.501,146.501]]',
          'geometryVersion': '${state.routeDraftGeometryVersion}',
        });
        expect(failureEntry.paths, [elvisRuntimePath]);

        await coordinator.retryActive();
        expect(coordinator.failures, hasLength(1));
        expect(coordinator.activeFailure!.key, failureEntry.key);
        coordinator.dismissActive();
        expect(coordinator.activeFailure, isNull);
        expect(
          container.read(routeDraftElevationMappingFailureProvider)!.key,
          failureEntry.key,
        );
        expect(container.read(mapProvider).routeDraftElevationError, isNotNull);

        fs.failure = null;
        await notifier.retryRouteDraftElevationMapping();
        final repaired = container.read(mapProvider);
        expect(coordinator.failureFor(failureEntry.key), isNull);
        expect(
          container.read(routeDraftElevationMappingFailureProvider),
          isNull,
        );
        expect(repaired.routeDraftElevationError, isNull);
        expect(repaired.routeDraftElevationLoading, isFalse);
        expect(repaired.routeDraftCommittedPoints, elevationRoutePoints);
        expect(repaired.routeDraftPointElevations, [100, 100]);
        expect(
          repaired.routeDraftGeometryVersion,
          state.routeDraftGeometryVersion,
        );
        expect(
          repaired.routeDraftElevationRequestId,
          state.routeDraftElevationRequestId,
        );
        expect(
          repaired.routeDraftElevationSummary!.geometryVersion,
          state.routeDraftGeometryVersion,
        );
        expect(opener.openedPaths, ['/mapping/$elvisRuntimePath']);
      },
    );
  }

  test(
    'raster failure preserves prior samples and retry cannot overwrite newer geometry',
    () async {
      final fs = FakeDemFileSystem();
      var malformed = false;
      final opener = FakeDemDatasetOpener(
        LookupDemDataset((point) {
          if (malformed && point != elevationRoutePoints.first) {
            throw const FormatException('Raster read failed');
          }
          return 100;
        }),
      );
      final container = await _container(_sampler(fs, opener));
      addTearDown(container.dispose);
      final notifier = container.read(mapProvider.notifier);
      final coordinator = container.read(
        mappingStoreOperationCoordinatorProvider,
      );
      _startRoute(notifier);
      await _settle();
      final prior = container.read(mapProvider);
      malformed = true;
      notifier.addRouteDraftMarker(
        const LatLng(-41.502, 146.502),
        straightLine: true,
      );
      await _settle();
      final failure = coordinator.activeFailure!;
      final failed = container.read(mapProvider);
      expect(
        failed.routeDraftElevationSummary,
        same(prior.routeDraftElevationSummary),
      );
      expect(failed.routeDraftPointElevations, prior.routeDraftPointElevations);
      expect(failed.routeDraftCommittedPoints, hasLength(3));

      malformed = false;
      notifier.addRouteDraftMarker(
        const LatLng(-41.503, 146.503),
        straightLine: true,
      );
      await _settle();
      final newer = container.read(mapProvider);
      expect(newer.routeDraftPointElevations, hasLength(4));
      await failure.retry();
      final afterStaleRetry = container.read(mapProvider);
      expect(
        afterStaleRetry.routeDraftCommittedPoints,
        newer.routeDraftCommittedPoints,
      );
      expect(
        afterStaleRetry.routeDraftElevationSummary,
        same(newer.routeDraftElevationSummary),
      );
      expect(
        afterStaleRetry.routeDraftPointElevations,
        newer.routeDraftPointElevations,
      );
      expect(coordinator.activeFailure, isNull);
      expect(opener.openedPaths.toSet(), {'/mapping/$elvisRuntimePath'});
    },
  );

  for (final error in <Object>[
    StateError('Missing library'),
    ArgumentError('Incompatible library'),
  ]) {
    test(
      'provider keeps host-library failure lazy and outside the Mapping queue: $error',
      () async {
        var libraryResolutions = 0;
        final sampler = RegionAwareRouteElevationSampler(
          catalog: elevationMappingCatalog,
          fileSystem: FakeDemFileSystem(),
          datasetOpener: GdalDemDatasetOpener(
            libraryPathResolver: () {
              libraryResolutions++;
              return '/host/gdal';
            },
            libraryLoader: (_) => throw error,
          ),
        );
        final container = await _container(sampler);
        addTearDown(container.dispose);
        expect(libraryResolutions, 0);
        final notifier = container.read(mapProvider.notifier);
        _startRoute(notifier);
        await _settle();
        expect(libraryResolutions, 1);
        expect(
          container.read(mapProvider).routeDraftElevationError,
          RouteElevationMessages.tasmaniaDataUnavailable,
        );
        expect(container.read(mapProvider).routeDraftElevationLoading, isFalse);
        expect(
          container.read(mappingStoreOperationCoordinatorProvider).failures,
          isEmpty,
        );
      },
    );
  }

  testWidgets(
    'dismissed DEM failure retains stable unavailable controls and retries',
    (tester) async {
      final fs = FakeDemFileSystem()..failure = FakeDemAccessFailure.missing;
      final opener = FakeDemDatasetOpener(LookupDemDataset((_) => 100));
      final container = (await tester.runAsync(
        () => _container(_sampler(fs, opener)),
      ))!;
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: RouteDraftGraphOverlay()),
          ),
        ),
      );
      _startRoute(container.read(mapProvider.notifier));
      await tester.pumpAndSettle();
      container.read(mappingStoreOperationCoordinatorProvider).dismissActive();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('route-planning-mapping-unavailable')),
        findsOneWidget,
      );
      fs.failure = null;
      await tester.tap(
        find.byKey(const Key('route-planning-mapping-unavailable-retry')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('route-planning-mapping-unavailable')),
        findsNothing,
      );
      expect(container.read(mapProvider).routeDraftElevationSummary, isNotNull);
    },
  );
}

RegionAwareRouteElevationSampler _sampler(
  FakeDemFileSystem fs,
  DemDatasetOpener opener,
) => RegionAwareRouteElevationSampler(
  catalog: elevationMappingCatalog,
  fileSystem: fs,
  datasetOpener: opener,
);

Future<ProviderContainer> _container(RouteElevationSampler sampler) async {
  final notifier = MapNotifier(
    mappingCatalog: elevationMappingCatalog,
    peakRepository: PeakRepository.test(InMemoryPeakStorage()),
    tasmapRepository: await TestTasmapRepository.create(),
    gpxTrackRepository: GpxTrackRepository.test(InMemoryGpxTrackStorage()),
    routeRepository: RouteRepository.test(InMemoryRouteStorage()),
    routeElevationSampler: sampler,
    routePlanner: _UnusedRoutePlanner(),
    peaksBaggedRepository: PeaksBaggedRepository.test(
      InMemoryPeaksBaggedStorage(),
    ),
    loadPositionOnBuild: false,
    loadPeaksOnBuild: false,
    loadTracksOnBuild: false,
  );
  final container = ProviderContainer(
    overrides: [
      mappingCatalogProvider.overrideWithValue(elevationMappingCatalog),
      mapProvider.overrideWith(() => notifier),
    ],
  );
  container.read(mapProvider);
  await _settle();
  return container;
}

void _startRoute(MapNotifier notifier) {
  notifier.beginRouteDraft();
  notifier.addRouteDraftMarker(elevationRoutePoints.first, straightLine: true);
  notifier.addRouteDraftMarker(elevationRoutePoints.last, straightLine: true);
}

Future<void> _settle() async {
  for (var i = 0; i < 4; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _UnusedRoutePlanner extends RoutePlanner {
  @override
  Future<RoutePlanningResult> planSegmentResult({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50,
  }) => throw StateError('Elevation tests use straight-line routes');

  @override
  Future<RouteEndpointProbeResult> probeEndpoint({
    required LatLng point,
    double maxSnapDistanceMeters = 50,
  }) => throw StateError('Elevation tests use straight-line routes');

  @override
  Future<PlannedRouteSegment> planSegment({
    required LatLng start,
    required LatLng end,
    double maxSnapDistanceMeters = 50,
  }) => throw StateError('Elevation tests use straight-line routes');
}
