import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/app.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/router.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../harness/test_map_notifier.dart';

void main() {
  testWidgets('selected track renders stacked highlight last', (tester) async {
    final state = MapState(
      center: const LatLng(-41.5, 146.5),
      zoom: 15,
      basemap: Basemap.tracestrack,
      showTracks: true,
      tracks: [
        GpxTrack(
          gpxTrackId: 1,
          contentHash: 'hash-1',
          trackName: 'Track 1',
          gpxFile: '<gpx></gpx>',
          displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
            [const LatLng(-41.5, 146.4), const LatLng(-41.5, 146.45)],
          ]),
          trackColour: 0xFF112233,
        ),
        GpxTrack(
          gpxTrackId: 2,
          contentHash: 'hash-2',
          trackName: 'Track 2',
          gpxFile: '<gpx></gpx>',
          displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
            [const LatLng(-41.5, 146.5), const LatLng(-41.5, 146.55)],
          ]),
          trackColour: 0xFF445566,
        ),
      ],
      selectedTrackId: 2,
      hoveredTrackId: 2,
    );

    await _pumpMapApp(tester, state);

    final layer = tester.widget<PolylineLayer>(find.byType(PolylineLayer));

    expect(layer.polylines, hasLength(3));
    expect(layer.polylines.first.color, const Color(0xFF112233));
    expect(layer.polylines[1].color, const Color(0xFF445566));
    expect(layer.polylines[1].strokeWidth, 4.0);
    expect(layer.polylines[1].borderStrokeWidth, 2.0);
    expect(layer.polylines[1].borderColor, const Color(0x66000000));
    expect(layer.polylines.last.color, Colors.white);
    expect(layer.polylines.last.strokeWidth, 1.5);
  });
}

Future<void> _pumpMapApp(WidgetTester tester, MapState state) async {
  SharedPreferences.setMockInitialValues({});
  await tester.pumpWidget(
    ProviderScope(
      overrides: [mapProvider.overrideWith(() => TestMapNotifier(state))],
      child: const App(),
    ),
  );
  await tester.pump();
  router.go('/map');
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}
