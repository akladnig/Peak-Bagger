import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/models/route_marker_display.dart';
import 'package:peak_bagger/screens/map_screen_layers.dart';

void main() {
  Widget host(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('draft marker layer renders RouteMarker widgets in order', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      host(
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [markers[0].child, markers[1].child],
        ),
      ),
    );

    expect(find.byKey(const Key('route-marker-circle')), findsOneWidget);
    expect(find.byKey(const Key('route-marker-target-ring')), findsOneWidget);
    expect(find.byKey(const Key('route-marker-target-dot')), findsOneWidget);
  });

  testWidgets('draft marker layer keeps a middle target unnumbered', (
    tester,
  ) async {
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

    expect(markers[2].width, RouteUI.markerNumberedSize);
    expect(markers[2].height, RouteUI.markerNumberedSize);

    await tester.pumpWidget(host(markers[1].child));

    expect(find.byKey(const Key('route-marker-target-ring')), findsOneWidget);
    expect(find.byKey(const Key('route-marker-target-dot')), findsOneWidget);
    expect(find.byKey(const Key('route-marker-numbered-label')), findsNothing);
  });

  testWidgets('hovered numbered marker scales and keeps its label', (
    tester,
  ) async {
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
          kind: RouteMarkerKind.numbered,
          number: 1,
        ),
      ],
      colour: 0xFFFF0000,
      hoveredMarkerId: '1',
    );

    expect(markers[1].width, RouteUI.markerNumberedSize * RouteUI.markerZoom);
    expect(markers[1].height, RouteUI.markerNumberedSize * RouteUI.markerZoom);

    await tester.pumpWidget(host(markers[1].child));

    expect(find.byKey(const Key('route-draft-marker-hover-1')), findsOneWidget);
    expect(
      find.byKey(const Key('route-marker-numbered-label')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('route-marker-numbered-label')))
          .data,
      '01',
    );
  });

  testWidgets('hovered circle marker scales and shows the hover shell', (
    tester,
  ) async {
    final markers = buildRouteDraftMarkers(
      markers: const [
        RouteMarkerDisplay(
          id: '0',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.circle,
        ),
      ],
      colour: 0xFF3366FF,
      hoveredMarkerId: '0',
    );

    expect(markers.single.width, RouteUI.markerSize * RouteUI.markerZoom);
    expect(markers.single.height, RouteUI.markerSize * RouteUI.markerZoom);

    await tester.pumpWidget(host(markers.single.child));

    expect(find.byKey(const Key('route-draft-marker-hover-0')), findsOneWidget);
    expect(find.byKey(const Key('route-marker-circle')), findsOneWidget);
  });

  testWidgets('hovered draft segment renders a placement preview marker', (
    tester,
  ) async {
    final markers = buildRouteDraftMarkers(
      markers: const [
        RouteMarkerDisplay(
          id: '0',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.circle,
        ),
        RouteMarkerDisplay(
          id: '1',
          point: LatLng(-41.55, 146.55),
          kind: RouteMarkerKind.numbered,
          number: 1,
        ),
        RouteMarkerDisplay(
          id: '2',
          point: LatLng(-41.6, 146.6),
          kind: RouteMarkerKind.target,
        ),
      ],
      colour: 0xFF3366FF,
      hoveredSegmentIndex: 1,
      hoveredSegmentPoint: const LatLng(-41.575, 146.575),
    );

    expect(markers, hasLength(4));
    expect(markers.last.key, const Key('route-draft-segment-hover-1'));
    expect(markers.last.width, RouteUI.markerNumberedSize);
    expect(markers.last.height, RouteUI.markerNumberedSize);

    await tester.pumpWidget(host(markers.last.child));

    expect(find.byKey(const Key('route-marker-circle')), findsOneWidget);
  });

  test('draft marker keys stay unique when ids repeat', () {
    final markers = buildRouteDraftMarkers(
      markers: const [
        RouteMarkerDisplay(
          id: '3',
          point: LatLng(-41.5, 146.5),
          kind: RouteMarkerKind.circle,
        ),
        RouteMarkerDisplay(
          id: '3',
          point: LatLng(-41.55, 146.55),
          kind: RouteMarkerKind.target,
        ),
      ],
      colour: 0xFFFF0000,
    );

    expect(markers, hasLength(2));
    expect(markers[0].key, const Key('route-draft-marker-3'));
    expect(markers[1].key, const Key('route-draft-marker-3-1'));
  });
}
