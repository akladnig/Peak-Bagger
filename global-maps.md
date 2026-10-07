# Global Maps
Update to only show the maps available for each region and get the baseUrls and map names from region_manifest.json instead of hardcoded values in map_screen_layers.dart

- update Select Basemaps to only show the basemaps available for the region in which the cursor currently sits when clicking the FAB.
- replace any hardcoded url with the url from the manifest
- update the Basemap enum to include all maps referenced in the manifest on application build

