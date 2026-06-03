import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/widgets/elevation_profile_chart.dart';

void main() {
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
