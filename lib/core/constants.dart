import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

abstract final class MapConstants {
  static const defaultCenter = LatLng(-41.5, 146.5);
  static const defaultZoom = 15.0;
  static const defaultMapZoom = 12.0;
  static const singlePointZoom = 15.0;
  static const cameraSaveDebounce = Duration(milliseconds: 150);
  static const cameraEpsilon = 0.000001;
  static const searchRadiusMeters = 100.0;
  static const peakMinZoom = 8;
  static const peakMaxZoom = 18;
  static const trackMinZoom = 6;
  static const trackMaxZoom = 18;
  static const clearPeakInfo = 8;
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
  static const wideNavigationWidth = 132.0;
  static const themeActionRightInset = 16.0;
}

abstract final class UiConstants {
  static const scrollSpeed = 0.001;
  static const scrollInterval = Duration(milliseconds: 16);
  static const peakInfoPopupSize = Size(320, 140);
  static const dialogMargin = 24.0;
  static const dividerWidth = 1.0;
  static const preferredLeftWidth = 360.0;
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
  static const sideMenuColumnWidth = 70.0;
}

abstract final class DashboardUI {
  static final cardBorderRadius = BorderRadius.circular(12);
  static const fullHeightLabelGuides = true;
  static const yAxisLabelWidth = 72.0;

  static double columnWidthFor({
    required double availableWidth,
    required int visibleColumnCount,
  }) {
    if (visibleColumnCount <= 0) {
      return availableWidth;
    }

    return availableWidth / visibleColumnCount;
  }

  static double rodWidthFor(double columnWidth) => columnWidth * 0.8;

  static const rodRadius = 2.0;
}

abstract final class ChartUI {
  static const barWidth = 2.0;
  static const radius = 3.0;
  static const radiusSelected = 5.0;
  static const colour = Color(0xFF2E7D32);
  static const colourSelected = Color(0xD92E7D32);
  static const strokeColor = Color(0x00000000);
  static const strokeColorSelected = Color(0x00000000);
  static const strokeWidth = 2.0;
}
