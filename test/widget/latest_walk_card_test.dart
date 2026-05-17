import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_tile_caching/flutter_map_tile_caching.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/widgets/dashboard/latest_walk_card.dart';

void main() {
  test('buildLatestWalkTileProvider returns cached provider when available', () {
    expect(buildLatestWalkTileProvider(cacheAvailable: false), isA<NetworkTileProvider>());
    expect(buildLatestWalkTileProvider(cacheAvailable: true), isA<FMTCTileProvider>());
  });

  testWidgets('renders empty placeholder when no usable track exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(tracks: []),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('latest-walk-card')), findsOneWidget);
    expect(find.byKey(const Key('latest-walk-empty-state')), findsOneWidget);
    expect(find.text('No walks yet'), findsOneWidget);
  });

  testWidgets('renders newest track details and mini-map', (tester) async {
    final tracks = [
      _track(
        10,
        DateTime.utc(2026, 5, 14, 10),
        segments: [
          [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
        ],
      ),
      _track(
        20,
        DateTime.utc(2026, 5, 15, 10),
        segments: [
          [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
        ],
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(tracks: tracks),
          ),
        ),
      ),
    );

    expect(find.text('Track 20'), findsOneWidget);
    expect(find.text('12 km'), findsOneWidget);
    expect(find.text('638 m'), findsOneWidget);
    expect(find.byKey(const Key('latest-walk-mini-map')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    expect(find.byKey(const Key('latest-walk-prev-track')), findsOneWidget);
    expect(find.byKey(const Key('latest-walk-next-track')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-prev-track'))).tooltip,
      'Previous track',
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-next-track'))).tooltip,
      'Next track',
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-next-track'))).onPressed,
      isNull,
    );
    expect(find.byKey(const ValueKey('latest-walk-map-20')), findsOneWidget);
  });

  testWidgets('paginates tracks with next disabled at latest', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(
              tracks: [
                _track(
                  10,
                  DateTime.utc(2026, 5, 14, 10),
                  segments: [
                    [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
                  ],
                ),
                _track(
                  20,
                  DateTime.utc(2026, 5, 15, 10),
                  segments: [
                    [const LatLng(-41.6, 146.6), const LatLng(-41.7, 146.7)],
                  ],
                ),
                _track(
                  30,
                  DateTime.utc(2026, 5, 13, 10),
                  segments: [
                    [const LatLng(-41.8, 146.8), const LatLng(-41.9, 146.9)],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('Track 20'), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-next-track'))).onPressed,
      isNull,
    );
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-prev-track'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('latest-walk-prev-track')));
    await tester.pumpAndSettle();

    expect(find.text('Track 10'), findsOneWidget);
    expect(find.byKey(const ValueKey('latest-walk-map-10')), findsOneWidget);
    expect(
      tester.widget<IconButton>(find.byKey(const Key('latest-walk-next-track'))).onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('latest-walk-next-track')));
    await tester.pumpAndSettle();

    expect(find.text('Track 20'), findsOneWidget);
    expect(find.byKey(const ValueKey('latest-walk-map-20')), findsOneWidget);
  });

  testWidgets('renders peak markers for correlated peaks', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(
              tracks: [
                _track(
                  10,
                  DateTime.utc(2026, 5, 14, 10),
                  segments: [
                    [const LatLng(-41.5, 146.5), const LatLng(-41.4, 146.6)],
                  ],
                  peaks: [
                    Peak(osmId: 501, name: 'Alpha Peak', latitude: -41.45, longitude: 146.55),
                  ],
                  peakCorrelationProcessed: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final markerLayer = tester.widget<MarkerLayer>(find.byType(MarkerLayer));
    expect(markerLayer.markers, hasLength(1));
    expect(markerLayer.markers.single.key, const Key('peak-marker-hitbox-501'));
    expect(
      markerLayer.markers.single.point,
      const LatLng(-41.45, 146.55),
    );
  });

  testWidgets('frames one-point tracks with default zoom', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(
              tracks: [
                _track(
                  10,
                  DateTime.utc(2026, 5, 14, 10),
                  segments: [
                    [const LatLng(-41.5, 146.5)],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCenter, const LatLng(-41.5, 146.5));
    expect(map.options.initialZoom, MapConstants.defaultMapZoom);
    expect(find.byType(CircleLayer), findsOneWidget);
  });

  testWidgets('frames multi-point tracks with bounds fit', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 420,
            height: 320,
            child: LatestWalkCard(
              tracks: [
                _track(
                  10,
                  DateTime.utc(2026, 5, 14, 10),
                  segments: [
                    [
                      const LatLng(-41.5, 146.5),
                      const LatLng(-41.4, 146.6),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.initialCameraFit, isNotNull);
    expect(find.byType(PolylineLayer), findsOneWidget);
  });
}

GpxTrack _track(
  int id,
  DateTime? startDateTime, {
  List<List<LatLng>> segments = const [],
  List<Peak> peaks = const [],
  bool peakCorrelationProcessed = false,
}) {
  final track = GpxTrack(
    gpxTrackId: id,
    contentHash: 'hash-$id',
    trackName: 'Track $id',
    trackDate: startDateTime,
    startDateTime: startDateTime,
    distance2d: 12400,
    ascent: 638,
    gpxFile: segments.isEmpty ? '' : '<gpx></gpx>',
    displayTrackPointsByZoom: segments.isEmpty
        ? '{}'
        : TrackDisplayCacheBuilder.buildJson(segments),
    peakCorrelationProcessed: peakCorrelationProcessed,
  );

  track.peaks.addAll(peaks);
  return track;
}
