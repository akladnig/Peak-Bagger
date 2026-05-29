# Goal
-  Replace placeholder route ascent/descent with values calculated from plotted route polylines using gdal_dart.

Some work has already been developed for this, so examine this file and to determine what is complete and what needs to be carried out and develop a spec.

# Constraints & Preferences
-  Flutter app.
-  Prefer gdal_dart over geoimage.
-  Remove the Ascent/Descent placeholder text from the route sheet.
-  Preserve existing route drafting behavior, including snap-to-trail/off-track straight-line fallback.
-  Need actual elevation data source; gdal_dart alone is not enough.

# In Progress
-  Determine elevation source for route ascent/descent.
-  Wire route save/UI to real ascent/descent once elevation sampling is available.
## Blocked
-  No DEM/GeoTIFF/terrain raster source is available in the repo/workspace.
-  gdal_dart can sample rasters, but there is currently nothing to sample.
## Key Decisions
-  gdal_dart is the better choice than geoimage for geospatial elevation sampling.
-  Route already has ascent/descent fields in lib/models/route.dart, but saveRouteDraft() currently only sets distance2d.
-  Placeholder route metrics were temporarily added in lib/widgets/map_route_bottom_sheet.dart; they should be removed once real values are computed.

# DEM Data
Allow the DEM datasource to be selected from one of the following, which for now is to be hardcoded in constants.dart:
- Copernicus GLO-30
- theList
- ELVIS (not currently available - future addition)

Two DEM data sources are available under the assets folder:
- cop30_hh.tif (Copernicus GLO-30 see below:)
- tasmania_dem_25m.tif & tasmania_dem_25m.vrt (theList see below:)

## Copernicus GLO-30
  - Grid spacing: ~30 m
  - Acquisition: mainly 2011-2015 TanDEM-X, with some infill sources
  - Absolute vertical accuracy: < 4 m at 90% linear error
  - Absolute horizontal accuracy: < 6 m at 90% circular error# Next Steps
## theList
- Refer to ~/Development/mapping/peak_bagger/tool/download_tasmania_thelist_dem.dart

1.  Provide or add a DEM/GeoTIFF source for the route area- see above.
2.  Add a GDAL-based elevation sampler service.
3.  Compute ascent/descent from routeDraftCommittedPoints / plotted polylines.
4.  Save Route.ascent and Route.descent in saveRouteDraft().
5.  Update the route sheet to show real values and remove placeholders.
6.  Add/adjust tests for computed ascent/descent.

# Critical Context
-  Current route save path: lib/providers/map_provider.dart → saveRouteDraft() creates Route with gpxRoute, displayRoutePointsByZoom, colour, distance2d only.
-  Route sheet distance/elevation group is in lib/widgets/map_route_bottom_sheet.dart.
-  Straight-line fallback currently lives in:
-  lib/providers/map_provider.dart
-  lib/screens/map_screen.dart
-  Route drafting tests currently cover:
-  test/providers/route_draft_state_test.dart
-  test/widget/map_screen_route_sheet_test.dart
-  test/robot/map/map_route_journey_test.dart
-  No elevation lookup service exists yet in lib/services/.
-  assets/mountain.png is not an elevation raster; it appears to be an icon asset.
-  flutter analyze has unrelated pre-existing warnings in test/robot/gpx_tracks/gpx_tracks_journey_test.dart and test/robot/gpx_tracks/gpx_tracks_robot.dart.

# Relevant Files
-  lib/widgets/map_route_bottom_sheet.dart: route UI currently showing placeholder ascent/descent.
-  lib/providers/map_provider.dart: route draft state machine and saveRouteDraft().
-  lib/screens/map_screen.dart: tap handling and snap/off-track routing behavior.
-  lib/models/route.dart: route model already includes ascent / descent.
-  lib/services/gpx_track_statistics_calculator.dart: existing elevation math pattern for tracks.
-  lib/services/geo.dart: calculateUphillDownhill(...).
-  test/providers/route_draft_state_test.dart: route draft behavior tests.
-  test/widget/map_screen_route_sheet_test.dart: route sheet widget tests.
-  test/robot/map/map_route_journey_test.dart: end-to-end route drafting tests.
-  test/robot/map/map_route_robot.dart: robot harness for route journeys.
