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
      tester.widget<Text>(find.byKey(const Key('map-ruler-zoom-text'))).textAlign,
      TextAlign.right,
    );
  });
}
