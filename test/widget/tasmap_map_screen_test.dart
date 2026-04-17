import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/widgets/tasmap_outline_layer.dart';

import '../harness/test_map_notifier.dart';
import '../harness/test_tasmap_notifier.dart';
import '../harness/test_tasmap_repository.dart';

void main() {
  testWidgets('selected map label renders on one Tasmap layer', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final center = repository.getMapCenter(map)!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
                zoom: 10,
                basemap: Basemap.tracestrack,
                selectedMap: map,
                tasmapDisplayMode: TasmapDisplayMode.selectedMap,
              ),
            ),
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
    await tester.pump(const Duration(milliseconds: 100));

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);

    final textFinder = find.descendant(
      of: labelLayerFinder,
      matching: find.text('Adamsons\nTS07'),
    );
    expect(textFinder, findsOneWidget);

    final text = tester.widget<Text>(textFinder);
    expect(text.textAlign, TextAlign.left);
  });

  testWidgets('overlay labels render without selected map layer', (
    tester,
  ) async {
    final maps = [_adamsons(), _wellingtonTwin()];
    final repository = await TestTasmapRepository.create(maps: maps);
    final center = repository.getMapCenter(maps[0])!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
                zoom: 10,
                basemap: Basemap.tracestrack,
                tasmapDisplayMode: TasmapDisplayMode.overlay,
              ),
            ),
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(TasmapOutlineLayer), findsNothing);

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);

    expect(
      find.descendant(
        of: labelLayerFinder,
        matching: find.text('Adamsons\nTS07'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: labelLayerFinder,
        matching: find.text('Wellington\nTQ08'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Tasmap labels hide below zoom 10', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final center = repository.getMapCenter(map)!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: center,
                zoom: 9,
                basemap: Basemap.tracestrack,
                selectedMap: map,
                tasmapDisplayMode: TasmapDisplayMode.selectedMap,
              ),
            ),
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
    await tester.pump(const Duration(milliseconds: 100));

    final labelLayerFinder = find.byKey(const Key('tasmap-label-layer'));
    expect(labelLayerFinder, findsOneWidget);

    expect(
      find.descendant(of: labelLayerFinder, matching: find.byType(Text)),
      findsNothing,
    );
  });

  testWidgets('Tasmanian basemaps use cached tile endpoints', (tester) async {
    final repository = await TestTasmapRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: LatLng(-41.5, 146.5),
                zoom: 10,
                basemap: Basemap.tasmapTopo,
              ),
            ),
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

    expect(
      tester.widget<TileLayer>(find.byType(TileLayer)).urlTemplate,
      'https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/Topographic/MapServer/tile/{z}/{y}/{x}',
    );
  });

  testWidgets('peak layer defaults on and toggles off', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 12,
        basemap: Basemap.tracestrack,
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
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
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

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pump();

    expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
  });

  test('correlated peak ids dedupe by osmId', () {
    final tracks = [
      GpxTrack(
          contentHash: 'hash-1',
          trackName: 'Track 1',
          gpxFile: '<gpx></gpx>',
          peakCorrelationProcessed: true,
        )
        ..peaks.addAll([
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
          Peak(
            osmId: 6406,
            name: 'Bonnet Hill',
            latitude: -43.0,
            longitude: 147.0,
          ),
        ]),
      GpxTrack(
          contentHash: 'hash-2',
          trackName: 'Track 2',
          gpxFile: '<gpx></gpx>',
          peakCorrelationProcessed: false,
        )
        ..peaks.add(
          Peak(
            osmId: 9999,
            name: 'Ignored Peak',
            latitude: -42.0,
            longitude: 146.0,
          ),
        ),
    ];

    expect(buildCorrelatedPeakIds(tracks), {6406});
  });

  testWidgets('peak layer renders ticked and unticked markers', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
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
                    latitude: -42.9,
                    longitude: 147.1,
                  ),
                ],
              ),
              correlatedPeakIds: {6406},
            ),
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

    final markerLayer = tester.widget<MarkerLayer>(
      find.byKey(const Key('peak-marker-layer')),
    );
    final assetNames = markerLayer.markers
        .map((marker) => (marker.child as SvgPicture).bytesLoader.toString())
        .toList();

    expect(
      assetNames,
      contains('SvgAssetLoader(assets/peak_marker_ticked.svg)'),
    );
    expect(assetNames, contains('SvgAssetLoader(assets/peak_marker.svg)'));
  });

  testWidgets('Show Peaks toggle hides peak layer', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
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

    await tester.tap(find.byKey(const Key('show-peaks-fab')));
    await tester.pump();

    expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
  });

  testWidgets('peak layer hides below zoom 9', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 8,
                basemap: Basemap.tracestrack,
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
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();

    expect(find.byKey(const Key('peak-marker-layer')), findsNothing);
  });

  testWidgets('peak layer renders above track polylines', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => TestMapNotifier(
              MapState(
                center: const LatLng(-41.5, 146.5),
                zoom: 12,
                basemap: Basemap.tracestrack,
                peaks: [
                  Peak(
                    osmId: 6406,
                    name: 'Bonnet Hill',
                    latitude: -43.0,
                    longitude: 147.0,
                  ),
                ],
                tracks: [
                  GpxTrack(
                      contentHash: 'hash',
                      trackName: 'Track',
                      gpxFile: '<gpx></gpx>',
                      displayTrackPointsByZoom:
                          TrackDisplayCacheBuilder.buildJson([
                            [
                              const LatLng(-43.1, 146.9),
                              const LatLng(-43.0, 147.0),
                            ],
                          ]),
                      peakCorrelationProcessed: true,
                    )
                    ..peaks.add(
                      Peak(
                        osmId: 6406,
                        name: 'Bonnet Hill',
                        latitude: -43.0,
                        longitude: 147.0,
                      ),
                    ),
                ],
                showTracks: true,
              ),
              correlatedPeakIds: {6406},
            ),
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

    final flutterMap = tester.widget<FlutterMap>(find.byType(FlutterMap));
    final children = flutterMap.children;
    final trackIndex = children.indexWhere((child) => child is PolylineLayer);
    final peakIndex = children.indexWhere(
      (child) =>
          child is MarkerLayer && child.key == const Key('peak-marker-layer'),
    );

    expect(trackIndex, greaterThanOrEqualTo(0));
    expect(peakIndex, greaterThan(trackIndex));
  });
}

Tasmap50k _adamsons() {
  return Tasmap50k(
    series: 'TS07',
    name: 'Adamsons',
    parentSeries: '8211',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}

Tasmap50k _wellingtonTwin() {
  return Tasmap50k(
    series: 'TQ08',
    name: 'Wellington',
    parentSeries: '8312',
    mgrs100kIds: 'DM DN',
    eastingMin: 60000,
    eastingMax: 99999,
    northingMin: 80000,
    northingMax: 9999,
    mgrsMid: 'DM',
    eastingMid: 80000,
    northingMid: 95000,
    p1: 'DN6000009999',
    p2: 'DN9999909999',
    p3: 'DM6000080000',
    p4: 'DM9999980000',
  );
}
