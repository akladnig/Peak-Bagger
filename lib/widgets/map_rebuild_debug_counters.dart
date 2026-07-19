abstract final class MapRebuildDebugCounters {
  static int routeRootBuilds = 0;
  static int actionRailBuilds = 0;
  static int polygonAssetLayerBuilds = 0;
  static int peakListDerivedRefreshes = 0;

  static void reset() {
    routeRootBuilds = 0;
    actionRailBuilds = 0;
    polygonAssetLayerBuilds = 0;
    peakListDerivedRefreshes = 0;
  }

  static void recordRouteRootBuild() {
    routeRootBuilds += 1;
  }

  static void recordActionRailBuild() {
    actionRailBuilds += 1;
  }

  static void recordPolygonAssetLayerBuild() {
    polygonAssetLayerBuilds += 1;
  }

  static void recordPeakListDerivedRefresh() {
    peakListDerivedRefreshes += 1;
  }
}
