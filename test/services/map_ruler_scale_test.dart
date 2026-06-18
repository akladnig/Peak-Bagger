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
    expect(
      mapMgrsGridIntervalForRulerMeters(299999),
      MapMgrsGridInterval.hundredKilometers,
    );
    expect(
      mapMgrsGridIntervalForRulerMeters(300000),
      MapMgrsGridInterval.thousandKilometers,
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
    expect(
      nextStep.distanceMeters,
      greaterThanOrEqualTo(selection.distanceMeters),
    );
  });

  test('ruler selection keeps scaling up at far zoom levels', () {
    final midScaleSelection = selectMapRulerScale(zoom: 6, latitude: -41.5);
    final tasmaniaSelection = selectMapRulerScale(zoom: 2, latitude: -41.5);
    final worldSelection = selectMapRulerScale(zoom: -1, latitude: 0);

    expect(midScaleSelection.distanceMeters, 200000);
    expect(
      midScaleSelection.barWidth,
      inInclusiveRange(
        MapConstants.mapRulerMinBarWidth,
        MapConstants.mapRulerMaxBarWidth,
      ),
    );
    expect(tasmaniaSelection.distanceMeters, 3000000);
    expect(
      tasmaniaSelection.barWidth,
      inInclusiveRange(
        MapConstants.mapRulerMinBarWidth,
        MapConstants.mapRulerMaxBarWidth,
      ),
    );
    expect(worldSelection.distanceMeters, 50000000);
    expect(
      worldSelection.barWidth,
      inInclusiveRange(
        MapConstants.mapRulerMinBarWidth,
        MapConstants.mapRulerMaxBarWidth,
      ),
    );
  });
}
