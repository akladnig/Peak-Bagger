# Route Planning
Since you need route planning only (no live tracking) and GPX export for external apps, here are the tailored recommendations:
Core Requirements
- Plan walking routes (manual or automated)
- Export as standard GPX files
- Leverage your existing stack: flutter_map, latlong2, path_provider
---
Recommended Packages
1. Automated Route Calculation (between waypoints)
trip_routing (pub.dev/packages/trip_routing)
- Client-side pedestrian routing using OpenStreetMap data via Overpass API
- Optimized for walking paths (prefers trails/footpaths)
- Accepts List<LatLng> waypoints, returns optimized route points
- No live tracking dependency
dependencies:
  trip_routing: ^latest
2. GPX File Generation
gpx (pub.dev/packages/gpx)
- Dart library for GPX 1.1 standard (compatible with Garmin, AllTrails, etc.)
- Create tracks with your route's coordinate points
- Export to .gpx file using your existing path_provider
dependencies:
  gpx: ^latest
---
## Optional: Manual Route Drawing
If you want users to plot routes by tapping the map (no internet needed for this part):
- Use `flutter_map`'s `onTap` callback to collect `LatLng` points
- Display the route via `PolylineLayer`
- Process the points with `trip_routing` (to optimize) or directly export via `gpx`
---
Example Workflow
1. User selects waypoints (tap map or enter peak coordinates)
2. Calculate route: trip_routing returns List<LatLng> optimized for walking
3. Generate GPX:
      import 'package:gpx/gpx.dart';
   final gpx = Gpx();
   final track = Trk(name: 'Peak Route');
   final segment = Trkseg();
   segment.trkpts = routePoints.map((p) => Trkpt(lat: p.latitude, lon: p.longitude)).toList();
   track.trksegs.add(segment);
   gpx.trks.add(track);
   final gpxString = GpxWriter().asString(gpx, pretty: true);
   4. Save using path_provider to export/share the .gpx file

# Local osm database
To recreate Overpass API functionality locally, you need to handle OSM data storage and querying yourself. Here are the approaches:
Understanding What Overpass Does
Overpass API:
1. Queries OSM data (nodes, ways, relations) using Overpass QL
2. Returns XML/JSON with matching elements
3. trip_routing uses it to fetch walking paths within a bounding box
---
Approach 1: Bundle Pre-Processed OSM Data (Recommended for Peak Bagging)
Step 1: Download OSM Data
Download PBF file for your region:
- Geofabrik downloads (e.g., australia-oceania-latest.osm.pbf)
- Or extract specific regions using Osmium tool
Step 2: Extract Walking Paths
Use Osmium or osmfilter to extract only pedestrian paths:
osmfilter input.osm.pbf --keep="highway=path =footway =cycleway =steps" --output=paths.osm.pbf
Step 3: Convert to Queryable Format
Option A: SQLite with Spatialite
# Convert PBF to SQLite with spatial indexing
ogr2ogr -f SQLite -dsco SPATIALITE=YES paths.db paths.osm.pbf
Option B: Use a Dart package to parse PBF
Search for Dart OSM readers (limited options, may need to write custom parser)
---
Approach 2: Use Existing Offline Routing Engine
GraphHopper (Java - runs separate server)
- Download GraphHopper and prepare OSM data
- Run locally as a separate process
- Use HTTP client in Flutter to query it
Embedded routing with FFI
If you want everything in Dart/Flutter:
- Write a C/C++ routing module (using something like OSRM)
- Use Dart FFI to call it
- Complex but fully embedded
---
Approach 3: Simplified Local Solution (Most Practical)
Since you're doing peak bagging (specific trails/paths), consider:
Custom Trail Database
1. Pre-identify hiking trails/paths for your peaks
2. Store as List<LatLng> in ObjectBox or SQLite
3. No real-time querying needed - just load known paths
// Example ObjectBox entity
@Entity()
class TrailPath {
  @Id()
  int id = 0;
  
  String trailName;
  String peakId; // Link to peak
  List<double> latLngPairs; // Flattened [lat, lng, lat, lng, ...]
}
---
Recommended: Hybrid Approach
1. For initial route planning: Use trip_routing with internet (it caches with useCity())
2. For offline: Bundle a SQLite database of known hiking trails for your peaks
3. For GPX export: Use the gpx package as discussed
This avoids rebuilding a complex OSM query engine while still providing offline capability for your specific use case (peak bagging trails).

Option 1 is ideal for extensible OSM tag queries. Here's the concrete implementation split:
Preprocessing (Desktop, One-Time Per Region)
1. Download regional OSM PBF from Geofabrik (https://download.geofabrik.de/)
2. Filter all relevant tags (pedestrian paths, natural features, waterways) with osmfilter:
      osmfilter input.osm.pbf --keep="highway=* natural=* waterway=*" --output=filtered.osm.pbf
   3. Convert to Spatialite SQLite (with spatial indexes) via ogr2ogr:
      ogr2ogr -f SQLite -dsco SPATIALITE=YES osm_data.db filtered.osm.pbf
   4. Bundle osm_data.db with your app (assets or on-demand region download)
In-App Implementation
1. Use spatialite_flutter to query the local db:
      // Query walking paths in a bounding box
   final result = await db.query(
     "SELECT geom FROM lines WHERE highway IN ('path','footway') AND bbox_test(geom, ?,?,?,?)",
     [minLng, minLat, maxLng, maxLat]
   );
   2. Replace trip_routing's Overpass call with your local query, reuse its graph-building/routing logic for path calculation
3. Export GPX with gpx package as before
Extend for Other Tags
Query the same db for natural=water (lakes) or waterway=river using the same bounding box pattern.


Based on the search results, there isn't a single pub.dev package that bundles SpatiaLite ready-to-use. Here are your options:
Option 1: Use sqlite3 Package (pub.dev/packages/sqlite3)
dependencies:
  sqlite3: ^latest
But you need custom SpatiaLite binaries for iOS/Android. The sqlite3 package maintainer explains:
> "To use SpatiaLite, you need custom build scripts to compile and include SpatiaLite in your project. You shouldn't use sqlite3_flutter_libs - you need something custom."
This requires building libspatialite for each platform (iOS/Android) and loading it with FFI.
---
Option 2: Use iulian0512's Forked sqflite (GitHub, Not pub.dev)
This fork has SpatiaLite pre-built:
dependencies:
  sqflite:
    git:
      url: https://github.com/iulian0512/sqflite
      path: sqflite
  sqflite_darwin:
    git:
      url: https://github.com/iulian0512/sqflite
      path: sqflite_darwin
They've also built:
- android_spatialite - Android arm64/arm32/x86_64 builds
- libspatialite-ios - iOS builds
---
Recommendation
For pub.dev only: Use sqlite3 package, but you'll need to handle SpatiaLite binary compilation separately (complex).
For working solution: Use iulian0512's GitHub fork with pre-built SpatiaLite - it's the only ready-to-use Flutter SpatiaLite plugin currently available, though not on pub.dev main repository.

# Tile and Query Server

To set up a local server that serves map tiles AND allows spatial queries, here's the recommended architecture:
Recommended: PostGIS + Martin Tile Server
This gives you both raster/vector tiles and full SQL querying capability.

## Step 1: Download OSM Data
### Download PBF for your region (e.g., Tasmania)
wget https://download.geofabrik.de/australia-oceania/tasmania-latest.osm.pbf

## Step 2: Set Up PostGIS Database
### Using Docker (easiest)
docker run -d \
  --name osm-postgis \
  -e POSTGRES_PASSWORD=password \
  -e POSTGRES_USER=osm \
  -e POSTGRES_DB=osm \
  -v $(pwd)/tasmania-latest.osm.pbf:/data.osm.pbf \
  -p 5432:5432 \
  -p 7800:7800 \
  kartoza/postgis:latest

## Step 3: Load OSM Data into PostGIS
### Inside the container or with proper connection
docker exec -it osm-postgis bash

### Load PBF into PostGIS (creates planet_osm_line, planet_osm_point, etc.)
osm2pgsql \
  --create \
  --slim \
  -d osm \
  -U osm \
  -H localhost \
  -P 5432 \
  /data.osm.pbf

## Step 4: Add PostGIS Extensions for Spatial Queries
docker exec -it osm-postgis psql -U osm -d osm -c "
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS hstore;
"

## Step 5: Run Martin Tile Server (serves both tiles + queries)
### Martin serves vector tiles AND allows raw SQL queries
docker run -d \
  --name martin \
  --link osm-postgis:db \
  -p 3000:3000 \
  -e DATABASE_URL="postgres://osm:password@db:5432/osm" \
  maplibre/martin

Now you have:
- Map tiles: http://localhost:3000/tiles/{z}/{x}/{y}.pbf
- Spatial queries: http://localhost:3000/sql?q=SELECT * FROM planet_osm_line WHERE highway='path'
## Step 6: Query from Flutter
// Use http package to query PostGIS via Martin
final response = await http.get(
  Uri.parse('http://localhost:3000/sql?q=' + 
    Uri.encodeComponent('SELECT osm_id, name, ST_AsGeoJSON(way) as geom FROM planet_osm_line WHERE highway IN (\'path\',\'footway\') LIMIT 10'))
);

# Simpler Alternative: SpatiaLite Server
If you want a lighter setup without PostGIS, use the Spatialite DB we discussed earlier with a tiny Dart/Python server:
## Start simple HTTP server for Spatialite queries
python3 -m http.server 8080  # Then add custom endpoints
Martin + PostGIS is the production-grade solution. SpatiaLite + custom server is lighter for mobile/local use.
