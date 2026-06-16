import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/elevation_profile_series_builder.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
  testWidgets('renders combined distance metric for a track', (tester) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      distance2d: 12400,
      distance3d: 0,
      ascent: 638,
      totalTimeMillis: 5400000,
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Distance (2d/3d)'), findsOneWidget);
    expect(find.text('12.4 / 0.0 km'), findsOneWidget);
  });

  testWidgets('renders elevation profile chart for a track', (tester) async {
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('elevation-profile-chart')), findsOneWidget);
    final chart = tester.widget<ElevationProfileChart>(
      find.byType(ElevationProfileChart),
    );
    expect(chart.minElevation, track.lowestElevation);
    expect(chart.maxElevation, track.highestElevation);
  });

  testWidgets('forwards track chart hover callback', (tester) async {
    final hoverEvents = <ElevationProfileChartHoverSample?>[];
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Test Track',
      lowestElevation: 1022,
      highestElevation: 1377,
      elevationProfile: '''
[
  {"segmentIndex":0,"pointIndex":0,"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"segmentIndex":0,"pointIndex":1,"distanceMeters":12,"elevationMeters":null,"timeLocal":null},
  {"segmentIndex":1,"pointIndex":0,"distanceMeters":24,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            child: MapTrackInfoPanel(
              track: track,
              onClose: () {},
              onExport: () {},
              onElevationProfileHoverChanged: hoverEvents.add,
            ),
          ),
        ),
      ),
    );

    final chart = tester.widget<ElevationProfileChart>(
      find.byType(ElevationProfileChart),
    );
    final sample = ElevationProfileChartHoverSample(
      sampleIndex: 2,
      sample: ElevationProfileSample(
        segmentIndex: 1,
        pointIndex: 0,
        distanceMeters: 24,
        elevationMeters: 120,
        timeLocal: DateTime.utc(2024, 1, 15, 8, 10),
      ),
      xValue: 24,
      axisMode: ElevationProfileAxisMode.distance,
    );

    chart.onHoverChanged?.call(sample);

    expect(hoverEvents.last, isNotNull);
    expect(hoverEvents.last!.sampleIndex, 2);
    expect(hoverEvents.last!.sample.segmentIndex, 1);
    expect(hoverEvents.last!.sample.pointIndex, 0);
  });

  testWidgets('renders a visibility row for a track', (tester) async {
    var visible = true;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              final track = GpxTrack(
                contentHash: 'hash',
                trackName: 'Test Track',
                visible: visible,
                lowestElevation: 1022,
                highestElevation: 1377,
                elevationProfile: '''
[
  {"distanceMeters":0,"elevationMeters":100,"timeLocal":"2024-01-15T08:00:00.000"},
  {"distanceMeters":100,"elevationMeters":120,"timeLocal":"2024-01-15T08:10:00.000"}
]
''',
              );

              return SizedBox(
                width: 600,
                child: MapTrackInfoPanel(
                  track: track,
                  onClose: () {},
                  onExport: () {},
                  onVisibilityChanged: (value) {
                    setState(() {
                      visible = value;
                    });
                  },
                ),
              );
            },
          ),
        ),
      ),
    );

    final switchFinder = find.byKey(
      const Key('track-info-panel-visibility-switch'),
    );
    expect(find.text('Hide this track on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isTrue);

    final label = find.text('Hide this track on the map');
    expect(
      tester.getRect(label).left,
      lessThan(tester.getRect(switchFinder).left),
    );
    expect(
      (tester.getRect(label).center.dy - tester.getRect(switchFinder).center.dy)
          .abs(),
      lessThan(1),
    );

    await tester.ensureVisible(switchFinder);
    await tester.pumpAndSettle();
    await tester.tap(switchFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Show this track on the map'), findsOneWidget);
    expect(tester.widget<Switch>(switchFinder).value, isFalse);
  });
}
