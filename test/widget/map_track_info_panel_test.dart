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
    expect(find.byType(ElevationProfileChart), findsOneWidget);
  });
}
