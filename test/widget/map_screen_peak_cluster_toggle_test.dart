import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/peak_ownership_ring_segment.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/peak_list_provider.dart';
import 'package:peak_bagger/providers/peak_list_selection_provider.dart';
import 'package:peak_bagger/providers/peak_ownership_ring_settings_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/screens/map_screen_peak_layer.dart';
import 'package:peak_bagger/services/peak_list_repository.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
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
    'cluster ring keeps ownership metadata and count overlay when individual rings are off',
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
                correlatedPeakIds: {7000},
              ),
            ),
            peakListSelectionRefreshSchedulerProvider.overrideWithValue((
              task,
            ) async {
              await task();
            }),
            peakOwnershipRingSettingsProvider.overrideWith(
              _StaticPeakOwnershipRingOffNotifier.new,
            ),
            peakActiveOwnershipSegmentsProvider.overrideWithValue(const {
              6406: [
                PeakOwnershipRingSegment(
                  peakListId: 7,
                  colourValue: 0xFF4C8BF5,
                ),
              ],
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

      final painter =
          tester
                  .widget<CustomPaint>(
                    find.byKey(const Key('peak-marker-paint')),
                  )
                  .painter!
              as PeakViewportPainter;
      expect(painter.clusters, hasLength(1));
      expect(
        painter.clusters.single.untickedOwnershipRingSegments.map(
          (segment) => segment.peakListId,
        ),
        [7],
      );
      expect(find.byKey(const Key('peak-cluster-layer')), findsOneWidget);
      expect(find.byKey(const Key('peak-cluster-count-0')), findsOneWidget);
    },
  );

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

class _StaticPeakOwnershipRingOffNotifier
    extends PeakOwnershipRingSettingsNotifier {
  @override
  bool build() => false;
}
