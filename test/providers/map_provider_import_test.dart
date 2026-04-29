import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/gpx_track.dart';
import 'package:peak_bagger/models/peak.dart';
import 'package:peak_bagger/providers/map_provider.dart';
import 'package:peak_bagger/services/track_display_cache_builder.dart';

void main() {
  test('correlated peak ids derive from current tracks', () {
    final peak = Peak(
      osmId: 6406,
      name: 'Bonnet Hill',
      latitude: -43.0,
      longitude: 147.0,
    );
    final track = GpxTrack(
      contentHash: 'hash',
      trackName: 'Correlated Track',
      gpxFile: '<gpx></gpx>',
      displayTrackPointsByZoom: TrackDisplayCacheBuilder.buildJson([
        [const LatLng(-43.0, 147.0), const LatLng(-42.9, 147.1)],
      ]),
      peakCorrelationProcessed: true,
    )..peaks.add(peak);

    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _TestMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);

    expect(notifier.correlatedPeakIds, isEmpty);

    notifier.state = notifier.state.copyWith(tracks: [track]);

    expect(notifier.correlatedPeakIds, {6406});
  });
}

class _TestMapNotifier extends MapNotifier {
  _TestMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}
