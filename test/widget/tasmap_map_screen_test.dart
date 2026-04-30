import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/models/tasmap50k.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/providers/tasmap_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/screens/map_screen.dart';
import 'package:peak_bagger/services/gpx_track_repository.dart';
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
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

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

  testWidgets('selected map fits to extent on mount', (tester) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final expectedCenter = repository.getMapCenter(map)!;
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-39.0, 140.0),
        zoom: 8,
        basemap: Basemap.tracestrack,
        selectedMap: map,
        tasmapDisplayMode: TasmapDisplayMode.selectedMap,
      ),
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
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      notifier.state.center.latitude,
      moreOrLessEquals(expectedCenter.latitude, epsilon: 0.001),
    );
    expect(
      notifier.state.center.longitude,
      moreOrLessEquals(expectedCenter.longitude, epsilon: 0.001),
    );
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);
  });

  testWidgets('selecting a map after mount refits the map screen', (
    tester,
  ) async {
    final map = _adamsons();
    final repository = await TestTasmapRepository.create(maps: [map]);
    final expectedCenter = repository.getMapCenter(map)!;
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-39.0, 140.0),
        zoom: 8,
        basemap: Basemap.tracestrack,
      ),
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
    notifier.selectMap(map);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      notifier.state.center.latitude,
      moreOrLessEquals(expectedCenter.latitude, epsilon: 0.001),
    );
    expect(
      notifier.state.center.longitude,
      moreOrLessEquals(expectedCenter.longitude, epsilon: 0.001),
    );
    expect(find.byType(TasmapOutlineLayer), findsOneWidget);
  });

  testWidgets('selected track fits to extent on mount', (tester) async {
    final track = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash',
      trackName: 'Ridge Walk',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-43.1, 146.9), const LatLng(-43.3, 147.3)],
      ]),
    );
    final repository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-39.0, 140.0),
        zoom: 8,
        basemap: Basemap.tracestrack,
        selectedLocation: const LatLng(-42.0, 147.0),
        selectedTrackId: 10,
        showTracks: true,
        tracks: [track],
      ),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([track]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
        ],
        child: const MaterialApp(home: MapScreen()),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(notifier.state.selectedLocation, isNotNull);
    expect(notifier.state.selectedLocation!.latitude, closeTo(-42.0, 0.001));
    expect(notifier.state.selectedLocation!.longitude, closeTo(147.0, 0.001));
    expect(notifier.state.center.latitude, closeTo(-43.2, 0.01));
    expect(notifier.state.center.longitude, closeTo(147.1, 0.01));
    expect(notifier.state.zoom, greaterThan(8));
  });

  testWidgets('selected track refits after returning from another branch', (
    tester,
  ) async {
    final firstTrack = GpxTrack(
      gpxTrackId: 10,
      contentHash: 'hash-1',
      trackName: 'First Track',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-43.1, 146.9), const LatLng(-43.3, 147.3)],
      ]),
    );
    final secondTrack = GpxTrack(
      gpxTrackId: 20,
      contentHash: 'hash-2',
      trackName: 'Second Track',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-41.4, 145.8), const LatLng(-41.6, 146.0)],
      ]),
    );
    final repository = await TestTasmapRepository.create();
    final notifier = TestMapNotifier(
      MapState(
        center: const LatLng(-39.0, 140.0),
        zoom: 8,
        basemap: Basemap.tracestrack,
        tracks: [firstTrack, secondTrack],
      ),
    );
    final gpxTrackRepository = GpxTrackRepository.test(
      InMemoryGpxTrackStorage([firstTrack, secondTrack]),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(() => notifier),
          tasmapStateProvider.overrideWith(
            () => TestTasmapNotifier(repository),
          ),
          tasmapRepositoryProvider.overrideWithValue(repository),
          gpxTrackRepositoryProvider.overrideWithValue(gpxTrackRepository),
        ],
        child: const App(),
      ),
    );

    await tester.pump();
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    router.go('/');
    await tester.pumpAndSettle();

    notifier.showTrack(10, selectedLocation: const LatLng(-43.0, 147.0));
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(notifier.state.center.latitude, closeTo(-43.2, 0.01));
    expect(notifier.state.center.longitude, closeTo(147.1, 0.01));

    router.go('/');
    await tester.pumpAndSettle();

    notifier.showTrack(20, selectedLocation: const LatLng(-41.5, 145.9));
    router.go('/map');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));

    expect(notifier.state.selectedTrackId, 20);
    expect(notifier.state.selectedLocation, const LatLng(-41.5, 145.9));
    expect(notifier.state.center.latitude, closeTo(-41.5, 0.01));
    expect(notifier.state.center.longitude, closeTo(145.9, 0.01));
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
    final assetNames = markerLayer.markers.map(_peakMarkerAssetName).toList();

    expect(
      assetNames,
      contains('SvgAssetLoader(assets/peak_marker_ticked.svg)'),
    );
    expect(assetNames, contains('SvgAssetLoader(assets/peak_marker.svg)'));
    expect(
      assetNames.indexOf('SvgAssetLoader(assets/peak_marker.svg)'),
      lessThan(
        assetNames.indexOf('SvgAssetLoader(assets/peak_marker_ticked.svg)'),
      ),
    );
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

  testWidgets('imported correlated peaks render as ticked markers', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mapProvider.overrideWith(
            () => _DerivedPeakMapNotifier(
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
                      trackName: 'Correlated Track',
                      gpxFile: '<gpx></gpx>',
                      displayTrackPointsByZoom:
                          TrackDisplayCacheBuilder.buildJson([
                            [
                              const LatLng(-43.0, 147.0),
                              const LatLng(-42.9, 147.1),
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

    final markerLayer = tester.widget<MarkerLayer>(
      find.byKey(const Key('peak-marker-layer')),
    );
    final assetNames = markerLayer.markers.map(_peakMarkerAssetName).toList();

    expect(
      assetNames,
      contains('SvgAssetLoader(assets/peak_marker_ticked.svg)'),
    );
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

String _peakMarkerAssetName(Marker marker) {
  final child = marker.child;
  final visualMarker = child is KeyedSubtree ? child.child : child;
  return (visualMarker as SvgPicture).bytesLoader.toString();
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

class _DerivedPeakMapNotifier extends MapNotifier {
  _DerivedPeakMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}
