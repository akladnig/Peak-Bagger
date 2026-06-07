import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import '../harness/test_map_notifier.dart';

void main() {
  test('centerOnLocation zooms to default zoom', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => TestMapNotifier(
            const MapState(
              center: LatLng(-41.5, 146.5),
              zoom: 11,
              basemap: Basemap.tracestrack,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);

    container.read(mapProvider);

    notifier.centerOnLocation(const LatLng(-41.6, 146.6));

    final pending = container.read(mapProvider).pendingCameraRequest;
    expect(pending?.center, const LatLng(-41.6, 146.6));
    expect(pending?.zoom, MapConstants.defaultZoom);
    expect(pending?.selectedLocation, const LatLng(-41.6, 146.6));
  });
}
