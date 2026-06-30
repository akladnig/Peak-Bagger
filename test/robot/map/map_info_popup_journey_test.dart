import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:peak_bagger/providers/map_provider.dart';

import '../../harness/test_tasmap_repository.dart';
import '../gpx_tracks/gpx_tracks_robot.dart';

void main() {
  testWidgets('map info popup opens and closes via button and keyboard', (
    tester,
  ) async {
    final repository = await TestTasmapRepository.create();
    addTearDown(repository.dispose);

    final robot = GpxTracksRobot(
      tester,
      MapState(
        center: const LatLng(-41.5, 146.5),
        zoom: 15,
        basemap: Basemap.tracestrack,
      ),
      tasmapRepository: repository,
    );

    await robot.pumpApp();

    await robot.openMapInfoPopup();
    robot.expectMapInfoPopupVisible();

    await robot.closeMapInfoPopup();
    robot.expectMapInfoPopupHidden();

    await robot.openMapInfoPopup();
    robot.expectMapInfoPopupVisible();

    await robot.dismissMapInfoPopupWithEscape();
    robot.expectMapInfoPopupHidden();

    await robot.openMapInfoPopup();
    robot.expectMapInfoPopupVisible();

    await robot.dismissMapInfoPopupWithCtrlC();
    robot.expectMapInfoPopupHidden();
  });
}
