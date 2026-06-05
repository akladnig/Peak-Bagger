import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/number_formatters.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';

void main() {
  testWidgets('MapZoomReadout renders ruler layout with preserved key', (
    tester,
  ) async {
    const zoom = 15.0;
    const latitude = -41.5;
    final selection = selectMapRulerScale(zoom: zoom, latitude: latitude);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapZoomReadout(zoom: zoom, latitude: latitude),
        ),
      ),
    );

    expect(find.byKey(const Key('map-zoom-readout')), findsOneWidget);
    expect(find.byKey(const Key('map-ruler-distance-text')), findsOneWidget);
    expect(find.byKey(const Key('map-ruler-bar')), findsOneWidget);
    expect(find.byKey(const Key('map-ruler-left-cap')), findsOneWidget);
    expect(find.byKey(const Key('map-ruler-right-cap')), findsOneWidget);
    expect(find.byKey(const Key('map-ruler-zoom-text')), findsOneWidget);
    expect(
      find.text(formatDistance(selection.distanceMeters.toDouble())),
      findsOneWidget,
    );

    expect(
      tester.getSize(find.byKey(const Key('map-ruler-bar'))).width,
      closeTo(selection.barWidth, 0.1),
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('map-ruler-zoom-text')))
          .textAlign,
      TextAlign.center,
    );
    expect(
      tester
          .widget<Text>(find.byKey(const Key('map-ruler-distance-text')))
          .textAlign,
      TextAlign.center,
    );
    expect(
      tester.getCenter(find.byKey(const Key('map-ruler-distance-text'))).dx,
      closeTo(tester.getCenter(find.byKey(const Key('map-ruler-bar'))).dx, 0.1),
    );
    expect(
      tester.getCenter(find.byKey(const Key('map-ruler-zoom-text'))).dx,
      closeTo(tester.getCenter(find.byKey(const Key('map-ruler-bar'))).dx, 0.1),
    );
    expect(
      tester.getCenter(find.byKey(const Key('map-ruler-distance-text'))).dy,
      lessThan(
        tester.getCenter(find.byKey(const Key('map-ruler-left-cap'))).dy,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('map-ruler-distance-text'))).dy,
      closeTo(
        tester.getTopLeft(find.byKey(const Key('map-ruler-left-cap'))).dy,
        0.1,
      ),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('map-ruler-zoom-text'))).dy -
          tester.getBottomLeft(find.byKey(const Key('map-ruler-bar'))).dy,
      closeTo(0, 0.1),
    );
    expect(
      tester.getSize(find.byKey(const Key('map-ruler-left-cap'))).height,
      greaterThan(
        tester.getSize(find.byKey(const Key('map-ruler-bar'))).height,
      ),
    );
    expect(
      tester.getSize(find.byKey(const Key('map-ruler-right-cap'))).height,
      greaterThan(
        tester.getSize(find.byKey(const Key('map-ruler-bar'))).height,
      ),
    );
  });

  testWidgets('MapZoomReadout shows large-scale distance labels at low zoom', (
    tester,
  ) async {
    const zoom = 2.0;
    const latitude = -41.5;
    final selection = selectMapRulerScale(zoom: zoom, latitude: latitude);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapZoomReadout(zoom: zoom, latitude: latitude),
        ),
      ),
    );

    expect(selection.distanceMeters, 3000000);
    expect(find.text('3000 km'), findsOneWidget);
    expect(
      find.text(formatDistance(selection.distanceMeters.toDouble())),
      findsOneWidget,
    );
  });
}
