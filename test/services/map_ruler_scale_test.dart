import 'package:flutter_test/flutter_test.dart';
import 'package:peak_bagger/core/constants.dart';
import 'package:peak_bagger/services/map_ruler_scale.dart';

void main() {
  test('grid interval follows configured ruler thresholds', () {
    expect(
      mapMgrsGridIntervalForRulerMeters(2999),
      MapMgrsGridInterval.oneKilometer,
    );
    expect(
      mapMgrsGridIntervalForRulerMeters(3000),
      MapMgrsGridInterval.tenKilometers,
    );
    expect(
      mapMgrsGridIntervalForRulerMeters(29999),
      MapMgrsGridInterval.tenKilometers,
    );
    expect(
      mapMgrsGridIntervalForRulerMeters(30000),
      MapMgrsGridInterval.hundredKilometers,
    );
  });

  test('ruler selection prefers the largest step within width band', () {
    final selection = selectMapRulerScale(zoom: 15, latitude: -41.5);

    expect(
      selection.barWidth,
      inInclusiveRange(
        MapConstants.mapRulerMinBarWidth,
        MapConstants.mapRulerMaxBarWidth,
      ),
    );

    final nextStep = selectMapRulerScale(zoom: 14, latitude: -41.5);
    expect(nextStep.distanceMeters, greaterThanOrEqualTo(selection.distanceMeters));
  });

  test('ruler selection clamps when no step fits width band', () {
    final selection = selectMapRulerScale(zoom: 2, latitude: -41.5);

    expect(selection.distanceMeters, 100000);
    expect(selection.barWidth, lessThan(MapConstants.mapRulerMinBarWidth));
  });
}
