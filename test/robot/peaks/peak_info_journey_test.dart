import 'package:flutter_test/flutter_test.dart';

import 'peak_info_robot.dart';

void main() {
  testWidgets('peak info journey hover shows click cursor and halo', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    r.expectPeakMarkerSelectors(6406);
    await r.hoverPeak(6406);

    r.expectPeakHover(6406);
  });

  testWidgets('peak info journey click opens popup content and close button', (
    tester,
  ) async {
    final r = PeakInfoRobot(tester);
    addTearDown(r.dispose);

    await r.pumpMap();

    await r.clickPeak(6406);
    r.expectPeakPopupWithContent('Bonnet Hill');

    await r.closePeakPopup();
    r.expectNoPeakPopup();
  });

  testWidgets(
    'peak info journey background click closes popup and selects map',
    (tester) async {
      final r = PeakInfoRobot(tester);
      addTearDown(r.dispose);

      await r.pumpMap();

      await r.clickPeak(6406);
      r.expectPeakPopupWithContent('Bonnet Hill');

      await r.clickMapBackground();

      r.expectNoPeakPopup();
      r.expectSelectedLocation();
    },
  );
}
