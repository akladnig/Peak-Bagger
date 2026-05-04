import 'dart:ui' show Size;

import 'package:latlong2/latlong.dart';

abstract final class MapConstants {
  static const defaultCenter = LatLng(-41.5, 146.5);
  static const defaultZoom = 15.0;
  static const searchRadiusMeters = 100.0;
  static const peakMinZoom = 6;
  static const peakMaxZoom = 18;
}

abstract final class GeoConstants {
  static const tasmaniaLatMin = -44.0;
  static const tasmaniaLatMax = -39.0;
  static const tasmaniaLngMin = 143.0;
  static const tasmaniaLngMax = 149.0;
}

abstract final class GpxConstants {
  static const maxSpeedMetersPerSecond = 12.0;
  static const maxJumpMeters = 2500.0;
  static const defaultHampelWindow = 5;
  static const defaultElevationWindow = 5;
  static const defaultPositionWindow = 5;
  static const defaultOutlierFilter = 'none';
  static const defaultElevationSmoother = 'none';
  static const defaultPositionSmoother = 'none';
}

abstract final class PeakCorrelationConstants {
  static const defaultDistanceMeters = 50;
  static const distanceOptions = <int>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
}

abstract final class RouterConstants {
  static const shellBreakpoint = 720.0;
  static const wideNavigationWidth = 132.0;
  static const themeActionRightInset = 16.0;
}

abstract final class UiConstants {
  static const scrollSpeed = 0.001;
  static const scrollInterval = Duration(milliseconds: 16);
  static const peakInfoPopupSize = Size(320, 140);
  static const dialogMargin = 24.0;
  static const dividerWidth = 1.0;
  static const preferredLeftWidth = 320.0;
  static const preferredRightWidth = 360.0;
  static const minimumMiniMapAspectWidth = 294.0;
  static const columnCellHorizontalPadding = 12.0;
  static const headerLabelGap = 12.0;
  static const rowHorizontalPadding = 40.0;
  static const columnGap = 12.0;
  static const headerIconWidth = 18.0;
  static const railSpacing = 8.0;
  static const primaryColumnWidth = 144.0;
  static const actionsColumnWidth = 72.0;
}
