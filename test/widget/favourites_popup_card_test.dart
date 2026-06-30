import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/models/waypoints.dart';
import 'package:peak_bagger/screens/map_screen_panels.dart';

void main() {
  testWidgets('favourites popup exposes an explicit close affordance', (
    tester,
  ) async {
    var closed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FavouritesPopupCard(
            favourites: [
              Waypoints(
                id: 1,
                name: 'South Ridge',
                type: Waypoints.typeFavourite,
                latitude: -41.5,
                longitude: 146.5,
                mgrs: '55G EN 10000 10000',
              ),
            ],
            onClose: () {
              closed = true;
            },
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('favourites-popup-close')), findsOneWidget);

    await tester.tap(find.byKey(const Key('favourites-popup-close')));
    await tester.pumpAndSettle();

    expect(closed, isTrue);
  });
}
