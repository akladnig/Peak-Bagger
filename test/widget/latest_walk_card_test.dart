import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:peak_bagger/widgets/dashboard/latest_walk_card.dart';

void main() {
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
    expect(find.text('12.4 km'), findsOneWidget);
    expect(find.text('638 m'), findsOneWidget);
    expect(find.byKey(const Key('latest-walk-mini-map')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
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
}) {
  return GpxTrack(
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
  );
}
