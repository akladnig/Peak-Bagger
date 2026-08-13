import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_list.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_peak_layer.dart';
import 'package:peak_bagger/services/peak_metadata_rules.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('All Peaks clusters use proportional ticked and unticked rings', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();

    await _pumpMap(
      tester,
      repository: repository,
      state: _clusteredMapState(),
      correlatedPeakIds: const {4},
    );

    final painter = _peakPainter(tester);

    expect(
      painter.clusterRingStyle,
      PeakClusterRingStyle.proportionalTickedUnticked,
    );
    expect(painter.clusters, hasLength(1));
    expect(painter.clusters.single.untickedFraction, 0.75);
    expect(painter.clusters.single.tickedFraction, 0.25);
  });

  testWidgets(
    'All Peaks metadata filters update clustered members and fractions',
    (tester) async {
      final repository = await TestTasmapRepository.create();
      final notifier = TestMapNotifier(
        _clusteredMapState(
          peaks: [
            _clusterPeak(1, rating: 4.0),
            _clusterPeak(2, rating: 4.5),
            _clusterPeak(3, rating: 4.5),
          ],
        ),
        correlatedPeakIds: const {3},
      );

      await _pumpMap(tester, repository: repository, notifier: notifier);

      notifier.setPeakRatingFilter(PeakRatingFilterOption.atLeast4_5);
      await tester.pump();

      final painter = _peakPainter(tester);

      expect(
        painter.clusterRingStyle,
        PeakClusterRingStyle.proportionalTickedUnticked,
      );
      expect(painter.clusters, hasLength(1));
      expect(
        painter.clusters.single.members.map((member) => member.peak.osmId),
        [2, 3],
      );
      expect(painter.clusters.single.untickedFraction, 0.5);
      expect(painter.clusters.single.tickedFraction, 0.5);
    },
  );

  testWidgets('specific peak-list clusters retain ownership hybrid rings', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    final peakList = PeakList(peakListId: 1, name: 'Nearby peaks');
    final peakListRepository = PeakListRepository.test(
      InMemoryPeakListStorage([peakList]),
      itemStorage: InMemoryPeakListItemEntityStorage([
        for (final peakId in [1, 2, 3])
          PeakListItemEntity(id: peakId, points: 0)
            ..peakList.target = peakList
            ..peak.target = _clusterPeak(peakId),
      ]),
    );

    await _pumpMap(
      tester,
      repository: repository,
      state: _clusteredMapState().copyWith(
        peakListSelectionMode: PeakListSelectionMode.specificList,
        selectedPeakListIds: {1},
        previousSpecificPeakListIds: {1},
      ),
      peakListRepository: peakListRepository,
    );

    expect(
      _peakPainter(tester).clusterRingStyle,
      PeakClusterRingStyle.ownershipHybrid,
    );
  });

  testWidgets('main map hides clusters when map cluster toggle is off', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-43.0, 147.0),
                zoom: 8,
                basemap: Basemap.tracestrack,
                peakVisibilityMode: PeakVisibilityMode.showPeaks,
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                  Peak(
                    osmId: 7000,
                    name: 'Other Peak',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                ],
              ),
              correlatedPeakIds: {6406},
            ),
          ),
          peakListSelectionRefreshSchedulerProvider.overrideWithValue((
            task,
          ) async {
            await task();
          }),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('peak-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('peak-cluster-layer')), findsNothing);
    expect(find.byKey(const Key('peak-marker-hover-6406')), findsNothing);
  });

  testWidgets('main map shows clusters when map cluster toggle is on', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-43.0, 147.0),
                zoom: 8,
                basemap: Basemap.tracestrack,
                peakVisibilityMode: PeakVisibilityMode.showPeakClusters,
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                  Peak(
                    osmId: 7000,
                    name: 'Other Peak',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                ],
              ),
              correlatedPeakIds: {6406},
            ),
          ),
          peakListSelectionRefreshSchedulerProvider.overrideWithValue((
            task,
          ) async {
            await task();
          }),
          peakListRepositoryProvider.overrideWithValue(
            PeakListRepository.test(InMemoryPeakListStorage()),
          ),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('peak-marker-layer')), findsOneWidget);
    expect(find.byKey(const Key('peak-cluster-layer')), findsOneWidget);
  });

  testWidgets(
    'hidden peak visibility mode skips peak provider work and map tap hit testing',
    (tester) async {
      final repository = await TestTasmapRepository.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestMapNotifier(
                MapState(
                  center: const LatLng(-43.0, 147.0),
                  zoom: 8,
                  basemap: Basemap.tracestrack,
                  peakVisibilityMode: PeakVisibilityMode.hidePeaks,
                  peakListSelectionMode: PeakListSelectionMode.none,
                  peaks: [
                    Peak(
                      osmId: 6406,
                      name: 'Bonnet Hill',
                      latitude: -43.0,
                      longitude: 147.0,
                    ),
                  ],
                ),
                correlatedPeakIds: {6406},
              ),
            ),
            peakListSelectionRefreshSchedulerProvider.overrideWithValue((
              task,
            ) async {
              await task();
            }),
            filteredPeaksProvider.overrideWith((ref) {
              throw StateError('filteredPeaksProvider should not be watched');
            }),
            peakMarkerColourAssignmentsProvider.overrideWith((ref) {
              throw StateError(
                'peakMarkerColourAssignmentsProvider should not be watched',
              );
            }),
            peakActiveOwnershipSegmentsProvider.overrideWith((ref) {
              throw StateError(
                'peakActiveOwnershipSegmentsProvider should not be watched',
              );
            }),
            peakOwnershipRingSegmentsProvider.overrideWith((ref) {
              throw StateError(
                'peakOwnershipRingSegmentsProvider should not be watched',
              );
            }),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(InMemoryPeakListStorage()),
            ),
            tasmapStateProvider.overrideWith(
              () => TestTasmapNotifier(repository),
            ),
            tasmapRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
      expect(find.byKey(const Key('peak-cluster-layer')), findsNothing);

      await tester.tap(find.byKey(const Key('map-interaction-region')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
    },
  );

  testWidgets(
    'low zoom keeps peak layers hidden while the visibility mode changes',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repository = await TestTasmapRepository.create();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mapProvider.overrideWith(
              () => TestMapNotifier(
                MapState(
                  center: const LatLng(-43.0, 147.0),
                  zoom: MapConstants.peakMinZoom - 1,
                  basemap: Basemap.tracestrack,
                  peakVisibilityMode: PeakVisibilityMode.showPeakClusters,
                  peaks: [
                    Peak(
                      osmId: 6406,
                      name: 'Bonnet Hill',
                      latitude: -43.0,
                      longitude: 147.0,
                    ),
                  ],
                ),
                correlatedPeakIds: {6406},
              ),
            ),
            peakListSelectionRefreshSchedulerProvider.overrideWithValue((
              task,
            ) async {
              await task();
            }),
            peakListRepositoryProvider.overrideWithValue(
              PeakListRepository.test(InMemoryPeakListStorage()),
            ),
            tasmapStateProvider.overrideWith(
              () => TestTasmapNotifier(repository),
            ),
            tasmapRepositoryProvider.overrideWithValue(repository),
          ],
          child: const MaterialApp(home: MapScreen()),
        ),
      );

      await tester.pump();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(MapScreen)),
      );
      expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
      expect(find.byKey(const Key('peak-cluster-layer')), findsNothing);

      final peakVisibilityFab = find.byKey(
        const Key('peak-visibility-mode-fab'),
      );
      await tester.ensureVisible(peakVisibilityFab);
      await tester.pumpAndSettle();
      await tester.tap(peakVisibilityFab);
      await tester.pump();

      expect(
        container.read(mapProvider).peakVisibilityMode,
        PeakVisibilityMode.showPeaks,
      );
      expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
      expect(find.byKey(const Key('peak-cluster-layer')), findsNothing);
    },
  );
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required TestTasmapRepository repository,
  MapState? state,
  TestMapNotifier? notifier,
  Set<int> correlatedPeakIds = const {},
  PeakListRepository? peakListRepository,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mapProvider.overrideWith(
          () =>
              notifier ??
              TestMapNotifier(state!, correlatedPeakIds: correlatedPeakIds),
        ),
        peakListSelectionRefreshSchedulerProvider.overrideWithValue((
          task,
        ) async {
          await task();
        }),
        peakListRepositoryProvider.overrideWithValue(
          peakListRepository ??
              PeakListRepository.test(InMemoryPeakListStorage()),
        ),
        tasmapStateProvider.overrideWith(() => TestTasmapNotifier(repository)),
        tasmapRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: MapScreen()),
    ),
  );
  await tester.pump();
}

PeakViewportPainter _peakPainter(WidgetTester tester) {
  return tester
          .widget<CustomPaint>(find.byKey(const Key('peak-marker-paint')))
          .painter!
      as PeakViewportPainter;
}

MapState _clusteredMapState({List<Peak>? peaks}) {
  return MapState(
    center: const LatLng(-43.0, 147.0),
    zoom: 8,
    basemap: Basemap.tracestrack,
    peakVisibilityMode: PeakVisibilityMode.showPeakClusters,
    peakListSelectionMode: PeakListSelectionMode.allPeaks,
    peaks:
        peaks ??
        [
          for (final peakId in [1, 2, 3, 4]) _clusterPeak(peakId),
        ],
  );
}

Peak _clusterPeak(int osmId, {double? rating}) {
  return Peak(
    osmId: osmId,
    name: 'Nearby peak $osmId',
    latitude: -43.0,
    longitude: 147.0,
    rating: rating,
  );
}
