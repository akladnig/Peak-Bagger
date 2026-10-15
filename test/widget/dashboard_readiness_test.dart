import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/dashboard_layout_provider.dart';
import 'package:peak_bagger/providers/dashboard_readiness_provider.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/my_ascents_summary_provider.dart';
import 'package:peak_bagger/providers/peak_provider.dart';
import 'package:peak_bagger/providers/peak_marker_info_settings_provider.dart';
import 'package:peak_bagger/screens/dashboard_screen.dart';
import 'package:peak_bagger/services/performance_measurement.dart';
import 'package:peak_bagger/services/peak_repository.dart';
import 'package:peak_bagger/services/my_ascents_summary_service.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/widgets/dashboard/latest_walk_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';
import '../harness/mapping_catalog_fixture.dart';

void main() {
  testWidgets('a cached saved layout is painted before the marker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      dashboardCardOrderStorageKey: ['my-ascents'],
    });
    final events = <Map<String, Object?>>[];
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(
            sink: (record) {
              events.add(record);
              if (record['event'] == 'dashboard.local_data_ready.frame') {
                expect(
                  find.byKey(const Key('dashboard-card-my-ascents')),
                  findsOneWidget,
                );
              }
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dashboardLayoutReadProvider.future);
    await container.read(peakMarkerInfoHydrationProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
  testWidgets(
    'saved settings are applied in the marked frame, not fallback defaults',
    (tester) async {
      SharedPreferences.setMockInitialValues({peakMarkerInfoKey: true});
      final events = <Map<String, Object?>>[];
      late ProviderContainer container;
      container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(
              sink: (record) {
                events.add(record);
                if (record['event'] == 'dashboard.local_data_ready.frame') {
                  expect(
                    container.read(peakMarkerInfoSettingsProvider),
                    isTrue,
                  );
                }
              },
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(dashboardLayoutProvider.notifier).load();
      await container.read(peakMarkerInfoReadProvider.future);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        hasLength(1),
      );
    },
  );
  testWidgets('already loaded empty data marks its first qualifying frame', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final events = <Map<String, Object?>>[];
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(sink: events.add),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(dashboardLayoutProvider.notifier).load();
    await container.read(peakMarkerInfoHydrationProvider.future);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    expect(find.byKey(const Key('elevation-empty-state')), findsOneWidget);
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
  testWidgets(
    'offstage dashboard qualifies only after returning to a shown frame',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final events = <Map<String, Object?>>[];
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(sink: events.add),
          ),
        ],
      );
      addTearDown(container.dispose);
      Widget app(bool enabled) => UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: TickerMode(enabled: enabled, child: const DashboardScreen()),
        ),
      );
      await tester.pumpWidget(app(false));
      await tester.pumpAndSettle();
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        isEmpty,
      );
      await tester.pumpWidget(app(true));
      await tester.pumpAndSettle();
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'failed saved settings retain the UI fallback and suppress readiness',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final events = <Map<String, Object?>>[];
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
          peakMarkerInfoPreferencesLoaderProvider.overrideWithValue(
            () async => throw StateError('settings failed'),
          ),
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(sink: events.add),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(container.read(peakMarkerInfoSettingsProvider), isFalse);
      expect(find.byKey(const Key('dashboard-board')), findsOneWidget);
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        isEmpty,
      );
      expect(
        events.where(
          (e) =>
              e['event'] == 'dashboard.dependency.failed' &&
              e['dependency'] == 'peak-info-settings',
        ),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'pending remote tiles do not delay successfully loaded local content',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final events = <Map<String, Object?>>[];
      final tiles = _PendingTiles();
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
                tracks: [
                  GpxTrack(
                    gpxTrackId: 1,
                    contentHash: 'fixture',
                    trackName: 'Local walk',
                    trackDate: DateTime(2026, 10, 1),
                    startDateTime: DateTime(2026, 10, 1),
                    gpxFile: '<gpx></gpx>',
                    displayTrackPointsByZoom:
                        TrackDisplayCacheBuilder.buildJson([
                          [
                            const LatLng(-41.5, 146.5),
                            const LatLng(-41.51, 146.51),
                          ],
                        ]),
                  ),
                ],
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
          latestWalkTileProviderFactoryProvider.overrideWithValue(() => tiles),
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(sink: events.add),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1600, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tiles.requests, greaterThan(0));
      expect(find.text('Local walk'), findsOneWidget);
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        hasLength(1),
      );
    },
  );
  testWidgets('marker sees the loaded track and current visible summary', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final events = <Map<String, Object?>>[];
    final track = GpxTrack(
      gpxTrackId: 1,
      contentHash: 'fixture',
      trackName: 'Loaded walk',
      trackDate: DateTime(2026, 10, 1),
      startDateTime: DateTime(2026, 10, 1),
      ascent: 1234,
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-41.5, 146.5), const LatLng(-41.51, 146.51)],
      ]),
    );
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
              tracks: [track],
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(
            sink: (event) {
              events.add(event);
              if (event['event'] == 'dashboard.local_data_ready.frame') {
                expect(find.text('Loaded walk'), findsOneWidget);
                expect(
                  find.descendant(
                    of: find.byKey(
                      const Key('dashboard-card-elevation-drag-handle'),
                    ),
                    matching: find.text('Total: 1234 m'),
                  ),
                  findsOneWidget,
                );
              }
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(1600, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: DashboardScreen(now: DateTime(2026, 10, 11))),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
  testWidgets('pending off-screen data blocks readiness until it succeeds', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final events = <Map<String, Object?>>[];
    var outcome = const AsyncValue<MyAscentsDataset>.loading();
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        myAscentsSummaryReadProvider.overrideWith((ref) => outcome),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(sink: events.add),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(1024, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      isEmpty,
    );
    outcome = const AsyncData(MyAscentsDataset.empty());
    container.invalidate(myAscentsSummaryReadProvider);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-ascents-card')), findsNothing);
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
  testWidgets(
    'failed off-screen ascents suppress readiness and name the dependency',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final events = <Map<String, Object?>>[];
      final container = ProviderContainer(
        overrides: [
          ...mappingCatalogTestOverrides,
          mapProvider.overrideWith(
            () => TestMapNotifier(
              const MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tracestrack,
              ),
            ),
          ),
          peakRepositoryProvider.overrideWithValue(
            PeakRepository.test(InMemoryPeakStorage()),
          ),
          mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
          myAscentsSummaryReadProvider.overrideWith(
            (ref) => AsyncError(
              StateError('ascent read failed'),
              StackTrace.current,
            ),
          ),
          performanceMeasurementProvider.overrideWithValue(
            PerformanceMeasurement(sink: events.add),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.binding.setSurfaceSize(const Size(1024, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my-ascents-card')), findsNothing);
      expect(container.read(myAscentsSummaryProvider).baggedRows, isEmpty);
      expect(
        events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
        isEmpty,
      );
      expect(
        events.where(
          (e) =>
              e['event'] == 'dashboard.dependency.failed' &&
              e['dependency'] == 'my-ascents',
        ),
        hasLength(1),
      );
    },
  );
  testWidgets('off-screen ascent reads qualify without constructing the card', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final events = <Map<String, Object?>>[];
    var readCount = 0;
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        myAscentsSummaryReadProvider.overrideWith((ref) {
          readCount++;
          return const AsyncData(MyAscentsDataset.empty());
        }),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(sink: events.add),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(1024, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('my-ascents-card')), findsNothing);
    expect(readCount, 1);
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
  testWidgets('pending saved layout suppresses the dashboard frame marker', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final gate = Completer<SharedPreferences>();
    final events = <Map<String, Object?>>[];
    final container = ProviderContainer(
      overrides: [
        ...mappingCatalogTestOverrides,
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 10,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
        peakRepositoryProvider.overrideWithValue(
          PeakRepository.test(InMemoryPeakStorage()),
        ),
        mapDashboardLoadProvider.overrideWith(LoadedMapDashboard.new),
        dashboardPreferencesLoaderProvider.overrideWithValue(() => gate.future),
        performanceMeasurementProvider.overrideWithValue(
          PerformanceMeasurement(sink: events.add),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pump();
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      isEmpty,
    );
    gate.complete(await SharedPreferences.getInstance());
    await tester.pumpAndSettle();
    expect(
      events.where((e) => e['event'] == 'dashboard.local_data_ready.frame'),
      hasLength(1),
    );
  });
}

class LoadedMapDashboard extends MapDashboardLoadNotifier {
  @override
  AsyncValue<void> build() => const AsyncData(null);
}

class _PendingTiles extends TileProvider {
  int requests = 0;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    requests++;
    return const _PendingImage();
  }
}

class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) async =>
      this;
  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
