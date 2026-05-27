import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';
import 'package:peak_bagger/widgets/route_marker.dart';

void main() {
  test('draft marker layer renders RouteMarker widgets in order', () {
    final markers = buildRouteDraftMarkers(
      markers: const [
        RouteMarkerDisplay(
          id: '0',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.circle,
        ),
        RouteMarkerDisplay(
          id: '1',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.target,
        ),
      ],
      colour: 0xFFFF0000,
    );

    expect(markers, hasLength(2));
    expect(markers[0].width, RouteUI.markerSize);
    expect(markers[0].height, RouteUI.markerSize);
    expect(markers[0].child, isA<RouteMarker>());
    expect((markers[0].child as RouteMarker).kind, RouteMarkerKind.circle);
    expect((markers[1].child as RouteMarker).kind, RouteMarkerKind.target);
  });

  test('draft marker layer keeps a middle target unnumbered', () {
    final markers = buildRouteDraftMarkers(
      markers: const [
        RouteMarkerDisplay(
          id: '0',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.circle,
        ),
        RouteMarkerDisplay(
          id: 'peak',
          point: LatLng(-41.55, 146.55),
          kind: RouteMarkerKind.target,
        ),
        RouteMarkerDisplay(
          id: '1',
          point: LatLng(-41.6, 146.6),
          kind: RouteMarkerKind.numbered,
          number: 1,
        ),
        RouteMarkerDisplay(
          id: '2',
          point: LatLng(-41.65, 146.65),
          kind: RouteMarkerKind.target,
        ),
      ],
      colour: 0xFF3366FF,
    );

    expect((markers[1].child as RouteMarker).kind, RouteMarkerKind.target);
    expect((markers[2].child as RouteMarker).kind, RouteMarkerKind.numbered);
    expect(markers[2].width, RouteUI.markerNumberedSize);
    expect(markers[2].height, RouteUI.markerNumberedSize);
  });
}
