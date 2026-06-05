import 'dart:math' as math;

import 'package:peak_bagger/core/constants.dart';

enum MapMgrsGridInterval {
  oneKilometer(1000),
  tenKilometers(10000),
  hundredKilometers(100000);

  const MapMgrsGridInterval(this.meters);

  final int meters;
}

class MapRulerScaleSelection {
  const MapRulerScaleSelection({
    required this.distanceMeters,
    required this.barWidth,
  });

  final int distanceMeters;
  final double barWidth;
}

double mapMetersPerPixel({required double zoom, required double latitude}) {
  final latitudeRadians = latitude * math.pi / 180.0;
  return 156543.03392 * math.cos(latitudeRadians) / math.pow(2.0, zoom);
}

MapMgrsGridInterval mapMgrsGridIntervalForRulerMeters(int rulerMeters) {
  final rulerKilometers = rulerMeters / 1000.0;
  if (rulerKilometers >= MapConstants.mapMgrsGridHundredKilometerThreshold) {
    return MapMgrsGridInterval.hundredKilometers;
  }
  if (rulerKilometers >= MapConstants.mapMgrsGridTenKilometerThreshold) {
    return MapMgrsGridInterval.tenKilometers;
  }
  return MapMgrsGridInterval.oneKilometer;
}

MapRulerScaleSelection selectMapRulerScale({
  required double zoom,
  required double latitude,
}) {
  final metersPerPixel = mapMetersPerPixel(zoom: zoom, latitude: latitude);
  MapRulerScaleSelection? bestInBand;
  MapRulerScaleSelection? closest;
  var closestDelta = double.infinity;

  for (final distanceMeters in _supportedRulerStepMeters) {
    final barWidth = distanceMeters / metersPerPixel;
    final selection = MapRulerScaleSelection(
      distanceMeters: distanceMeters,
      barWidth: barWidth,
    );

    if (barWidth >= MapConstants.mapRulerMinBarWidth &&
        barWidth <= MapConstants.mapRulerMaxBarWidth) {
      bestInBand = selection;
    }

    final delta = _widthDeltaFromBand(barWidth);
    if (delta < closestDelta) {
      closestDelta = delta;
      closest = selection;
    }
  }

  return bestInBand ?? closest!;
}

double _widthDeltaFromBand(double barWidth) {
  if (barWidth < MapConstants.mapRulerMinBarWidth) {
    return MapConstants.mapRulerMinBarWidth - barWidth;
  }
  if (barWidth > MapConstants.mapRulerMaxBarWidth) {
    return barWidth - MapConstants.mapRulerMaxBarWidth;
  }
  return 0;
}

const _supportedRulerStepMeters = <int>[
  1,
  2,
  3,
  5,
  10,
  20,
  30,
  50,
  100,
  200,
  300,
  500,
  1000,
  2000,
  3000,
  5000,
  10000,
  20000,
  30000,
  50000,
  100000,
  200000,
  300000,
  500000,
  1000000,
  2000000,
  3000000,
  5000000,
  10000000,
  20000000,
  30000000,
  50000000,
];
