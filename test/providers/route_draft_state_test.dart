import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';

void main() {
  test('route draft starts clean and clears selected map state', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
            MapState(
              center: const LatLng(-41.5, 146.5),
              zoom: 15,
              basemap: Basemap.tracestrack,
              selectedLocation: const LatLng(-41.6, 146.6),
              selectedTrackId: 7,
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(mapProvider.notifier);
    notifier.beginRouteDraft();

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isTrue);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
    expect(state.selectedLocation, isNull);
    expect(state.selectedTrackId, isNull);
  });

  test('route draft markers append in tap order', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
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
    notifier.beginRouteDraft();
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));
    notifier.addRouteDraftMarker(const LatLng(-41.6, 146.6));

    expect(
      container.read(mapProvider).routeDraftMarkers,
      [const LatLng(-41.5, 146.5), const LatLng(-41.6, 146.6)],
    );
  });

  test('route draft end clears draft state', () {
    final container = ProviderContainer(
      overrides: [
        mapProvider.overrideWith(
          () => _InitialStateMapNotifier(
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
    notifier.beginRouteDraft();
    notifier.setRouteDraftName('Test route');
    notifier.setRouteDraftMode(RouteMode.straightLine);
    notifier.addRouteDraftMarker(const LatLng(-41.5, 146.5));

    notifier.endRouteDraft();

    final state = container.read(mapProvider);
    expect(state.isRouteDrafting, isFalse);
    expect(state.routeDraftMode, RouteMode.snapToTrail);
    expect(state.routeDraftName, isEmpty);
    expect(state.routeDraftMarkers, isEmpty);
  });
}

class _InitialStateMapNotifier extends MapNotifier {
  _InitialStateMapNotifier(this.initialState);

  final MapState initialState;

  @override
  MapState build() => initialState;
}
