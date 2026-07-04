# Peak Bagger

Peak Bagger is a local-first hiking and peak bagging app for planning trips, importing walks, and tracking summit progress on an interactive map.

Built for serious walkers and peak-list chasers, it combines GPX import, route planning, summit tracking, offline map support, and personal progress management in one workflow. Instead of splitting your data across mapping apps, spreadsheets, and track viewers, Peak Bagger keeps peaks, tracks, routes, and list progress together on your device.

## Highlights

- Import GPX files and store walks locally
- Calculate distance, elevation, time, and speed statistics
- Match tracks against nearby peaks to detect likely ascents
- Browse, search, and inspect peaks on a live map
- Create and manage personal peak lists
- Draw and save custom routes for future trips
- Download map tiles for offline use
- Review activity and completion progress from a dashboard

## How It Works

Peak Bagger supports both retrospective logging and forward trip planning:

1. Import one or more GPX tracks from completed walks.
2. Store the track data locally and calculate summary stats.
3. Correlate track geometry with known peaks to identify climbed summits.
4. Review those ascents on the map, in summary cards, and in peak-list views.
5. Plan future outings by drawing and saving routes directly in the app.

## Main Areas

### Dashboard

The dashboard provides a quick view of recent activity and overall progress. It includes summaries for distance, elevation, latest walk, peaks bagged, ascents, year-to-date activity, and peak-list completion. Cards can be reordered to match the user's priorities.

### Map

The map is the center of the app. From here, users can import GPX files, search peaks, filter by peak list, switch basemaps, show or hide tracks and routes, inspect peak details, jump to grid or map-sheet references, center on current location, and move into route-planning workflows.

### My Peak Lists

Peak lists turn summit tracking into structured goals. Users can create named lists, import them from CSV, add or edit peaks, assign per-list point values, review ascent history, and track completion over time.

### Settings

Settings includes both normal preferences and maintenance tools. It covers theme selection, map labels and polygon toggles, OpenRouteService API key management, GPX filtering and peak-correlation tuning, offline tile downloads, CSV export, and rebuild or reset operations for map, route, peak, and track data.

### ObjectBox Admin

Peak Bagger also includes an in-app ObjectBox admin screen for power users. It supports inspecting stored entities, searching rows, viewing schema and data, editing peaks and routes, exporting GPX from stored tracks, deleting records, and sending selected data back to the main map.

## Route Planning

Route planning is a core workflow, not a secondary feature. The route builder supports:

- Straight-line routing
- Snap-to-trail routing
- Route-to-peak mode
- Out-and-back generation
- Close-loop generation
- Undo and redo
- Elevation sampling
- Ascent and descent feedback
- Saving finished routes for later display

## Peak Data And Progress Tracking

Peak Bagger stores rich summit metadata including names, alternate names, elevation, prominence, coordinates, region fields, grid references, verification fields, and optional Peakbagger identifiers. On the map, climbed and unclimbed peaks can be rendered differently, making progress easy to understand at a glance.

Named peak lists provide another layer of progress tracking, helping users manage challenge lists, regional collections, or personal goals.

## Offline And Regional Support

Offline support is a real part of the app experience. Users can initialize local tile caching, download basemap tiles by area and zoom range, skip tiles that already exist, and clear cached tiles later when needed.

Regional support is driven by bundled assets and manifests, so available basemaps and related map behavior can adapt by area. Tasmania currently has the richest support, with additional regional asset coverage including New South Wales, Slovenia, Croatia, and Italy.

The Mapy.cz tourist basemap uses Mapy's official tile API and is only enabled when the app is built with `--dart-define=MAPY_CZ_API_KEY=<your-key>`.

For local development in this repo, you can keep API keys out of git by using `dart_defines.local.json` and launching with `--dart-define-from-file=dart_defines.local.json`. The repo now expects both `TRACESTRACK_API_KEY` and `MAPY_CZ_API_KEY` there for the keyed basemaps. Tracestrack requests also send a `Referer` header; override it with `--dart-define=TRACESTRACK_REFERER=<your-origin>` if your Tracestrack app key is restricted to a specific origin.

For the combined local Mapy + Slovenia debug setup, run `./run_local_maps.sh`. It starts the local Slovenia proxy on `127.0.0.1:8080` if needed, then launches `flutter run --dart-define-from-file=dart_defines.local.json`. Extra `flutter run` args are forwarded, for example `./run_local_maps.sh --verbose` or `./run_local_maps.sh -d iphone`.

You can manage the local Slovenia proxy on its own with `./start_slovenia_proxy.sh`, `./stop_slovenia_proxy.sh`, and `./restart_slovenia_proxy.sh`. The helper-managed proxy PID is stored in `.dart_tool/slovenia_topo_proxy.pid`, and proxy output goes to `.dart_tool/slovenia_topo_proxy.log`.

## Local-First By Design

Peak Bagger stores its working data locally with ObjectBox. That local-first approach supports fast access to peaks, tracks, routes, ascents, and list data while enabling offline workflows and richer maintenance tools than a simple viewer app.

## PeakBagger Sync

Run the PeakBagger CSV sync from the repo root:

```bash
./sync_peakbagger_csv.sh
```

Optional unmatched-peak creation:

```bash
./sync_peakbagger_csv.sh --create-unmatched-peaks
```

You can also target a different CSV file by passing its path as the first argument.

It preserves `peak-bagger-peak-data.csv`, refreshes `peak-bagger-peak-data-lat-lon.csv`, and writes the review output to `peak-bagger-peak-data-processed.csv`.

The cached CSV is the reusable lookup file and only carries the coordinate fields needed for later runs. The processed CSV adds `note`, `osmId`, and `safeToCreate`. In the current review mode, the sync reads ObjectBox for matching but does not modify ObjectBox.

If the native ObjectBox library is missing, install it first with the ObjectBox `install.sh` helper so `lib/libobjectbox.dylib` exists.
