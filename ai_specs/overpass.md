
A future development will be for a local OSM Tile server so could that be used to generate the queries required for the requested route area?


Yes, but only if “local OSM tile server” means more than raster map tiles.
A normal tile server gives you rendered tiles or vector tiles for display. That is not enough for routing because you need the underlying OSM ways/nodes, not map tiles.
What can work
1. Run a local Overpass instance against your local OSM extract.
2. Or load OSM into osm2pgsql + PostGIS and query highways directly.
3. Or run a dedicated routing backend like OSRM/GraphHopper/Valhalla and call that instead of building graphs in-app.
Best fit for your current code
Your app already expects Overpass-shaped data:
- lib/services/route_graph_store.dart
- trip_routing.TripService.loadOverpassJson(...)
So the easiest future path is:
1. Keep the current query shape.
2. Point it at a local Overpass endpoint instead of the public API.
3. Request only the route corridor/bbox needed for the current route.
4. Cache the returned graph chunks locally.
That lets you reuse most of the existing parsing logic.
Important limitation
Do not query the local tile server itself for routing data unless it explicitly exposes source OSM features. Raster tiles are just images.
Recommended architecture
- Tile server: map display only
- Local Overpass or PostGIS: fetch OSM highways for route area
- App cache/store: keep recently used route-area graph chunks
- trip_routing: route over merged local chunks
Practical query strategy
For a route request:
1. Build a bbox or buffered corridor from start/end/waypoints.
2. Query way["highway"] plus referenced nodes in that area.
3. Load into TripService.
4. If no route is found, expand the area and retry.
A corridor is usually better than a huge statewide highway.json.
If you want, I can outline a concrete migration path from the current monolithic highway.json to a local Overpass-backed on-demand graph loader.

Yes. The useful part is not the tile server itself, but a local OSM data service beside it.
For this codebase, the best migration is:
1. Keep the app querying Overpass-style JSON.
2. Swap the source from bundled highway.json to a local Overpass endpoint.
3. Fetch only the route corridor needed for the current segment.
4. Cache those fetched areas locally.
Why this fits the current code
Right now the app is built around Overpass-shaped data:
- lib/services/route_graph_refresh_service.dart:30 uses a raw Overpass query
- lib/services/route_graph_store.dart:120 calls loadOverpassJson(...)
- trip_routing/lib/src/services/trip_service.dart:44 already accepts decoded Overpass JSON
So you do not need to invent a new route format first.
Target architecture
- Map tiles: served by your local tile server
- Routing data: served by local Overpass
- App cache: stores fetched route-area graph chunks
- trip_routing: routes over merged cached chunks
Phase 1
Replace the monolithic snapshot with a query source abstraction.
Add something like:
abstract class RouteGraphSource {
  Future<Map<String, dynamic>> fetchBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
  });
}
Implement:
- LocalOverpassRouteGraphSource
- later optionally RemoteOverpassRouteGraphSource
This should take over the query currently hardcoded in lib/services/route_graph_refresh_service.dart:30.
Phase 2
Replace snapshot preload with area cache.
Current issue:
- lib/services/route_graph_store.dart:109 loads one full file
- lib/providers/route_graph_readiness_provider.dart:75 eagerly preloads it
Change RouteGraphStore from “load one statewide graph” to “ensure graph available for bounds”.
Example shape:
abstract class RouteGraphStore {
  Future<void> warmIndex();
  Future<trip_routing.TripService> serviceForBounds(RouteBounds bounds);
  Future<void> invalidateBounds(RouteBounds bounds);
}
Phase 3
Cache by tile/region, not by one file.
Store fetched graph chunks under something like:
- route_graph_cache/z12_xyyy_zzzz.json
- or route_graph_cache/geohash_xxxxx.json
Each cache entry should track:
- bounds
- fetchedAt
- element count
- source version
Phase 4
Query a corridor, not a giant bbox.
For each route segment:
1. Build a bbox from start/end
2. Add a buffer
3. Query highways and referenced nodes
4. Attempt route
5. If no path, expand buffer and retry
Use the same Overpass pattern you already have:
[out:json];
(
  way["highway"]["area"!~"yes"]["place"!~"square"](minLat,minLon,maxLat,maxLon);
);
out body;
>;
out skel qt;
That is very close to lib/services/route_planner.dart:163.
Phase 5
Teach trip_routing to merge chunks.
This is the main code change.
Right now TripService assumes one complete graph in memory:
- trip_routing/lib/src/services/trip_service.dart:35
- trip_routing/lib/src/services/trip_service.dart:257
You want either:
1. appendOverpassElements(...) to merge newly fetched elements into an existing graph
2. or a GraphBuilder that deduplicates nodes/edges across multiple chunks
Without this, every request will rebuild from scratch and you lose most of the benefit.
Phase 6
Add a small spatial index.
Current closest-node lookup scans every node:
- trip_routing/lib/src/services/trip_service.dart:257
Once you stop using one full statewide graph, this becomes manageable, but a grid index or R-tree would still help a lot.
Good enough first step:
- bucket nodes into fixed lat/lon cells
- search nearby cells first
- fall back to wider search only if needed
Concrete file changes
- lib/services/route_graph_store.dart
  - replace single-file snapshot loading with bounds-based cache loading
- lib/services/route_graph_refresh_service.dart
  - repurpose or replace with on-demand fetch service
- lib/providers/route_graph_readiness_provider.dart
  - stop preloading the full graph; only warm config/index/cache
- lib/services/route_planner.dart
  - request route-area graph before planning
- trip_routing/lib/src/services/trip_service.dart
  - add incremental graph merge support
  - add better nearest-node lookup
Recommended rollout
1. Add LocalOverpassRouteGraphSource
2. Add bounds-based cache files
3. Route using fetched area for one segment
4. Add “expand search area and retry”
5. Add graph merging
6. Remove dependence on bundled assets/highway.json
What not to do
- Do not query raster tiles for routing
- Do not keep 223 MB highway.json and just move jsonDecode to later
- Do not fetch tiny bboxes without retry expansion, or routes will fail near graph edges
Best first implementation
If you want the smallest useful step:
1. Keep trip_routing as-is
2. Fetch only a corridor-sized Overpass response from local Overpass
3. Build one temporary in-memory graph per route request
4. Cache raw JSON by bounds on disk
That gets you off the monolithic asset quickly, before doing incremental graph merging.
If you want, I can turn this into a concrete implementation spec for this repo, including the exact new classes and method signatures.
