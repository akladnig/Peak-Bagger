# Peak Bagger

Peak Bagger is a macOS-only, local-first hiking and peak bagging app for planning trips, importing walks, and tracking summit progress on an interactive map.

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

Settings includes theme selection, map labels and polygon toggles, OpenRouteService API key management, GPX filtering and peak-correlation tuning, offline tile downloads, CSV export, and updates for map, route, peak, Natural Features, and track data. `Update Peak Data` and `Update Map Data` reconcile the manifest-declared Mapping sources into local ObjectBox data.

### ObjectBox Admin

Peak Bagger also includes an in-app ObjectBox admin screen for power users. It supports inspecting stored entities, searching rows, viewing schema and data, editing peaks and routes, exporting GPX from stored tracks, deleting records, and sending selected data back to the main map.

## Tasmania Maintainer Workflow

For Mapping data store tool permissions, no-overwrite tool-manifest bootstrap,
and v1 retained-contract verification, see
[`docs/mapping-data-store.md`](docs/mapping-data-store.md).

For the consolidated ELVIS DEM, Tasmania Local Topo rebuild, and local stack commands, see:

- `README.tasmania-elvis-local-topo.md`

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

Offline support is a real part of the app experience. Users can initialize local tile caching, download basemap tiles by area and zoom range, skip tiles that already exist, and clear cached tiles later when needed. These user-managed tiles live in the macOS application-support cache, outside the Mapping data store.

Regional support is driven by `region_manifest.json` and `Polygons/manifest.json` from the selected Mapping runtime. The macOS app reads [machine-local Application Support configuration](docs/mapping-runtime-startup.md): by default an immutable local runtime replica, or explicitly the mini's attached `/Volumes/Services/Mapping` canonical store. SMB app-runtime access is rejected. Only called UI icons are bundled. The app validates eligibility and the complete manifest-derived dataset before opening ObjectBox or the main UI; an unavailable replica shows its local paths with `Retry` and `Quit`. The app does not download, repair, or write Mapping source files and never queries Overpass. GDAL/PROJ remain host dependencies, opened lazily for route elevation and not bundled. Tasmania currently has the richest support, with additional regional coverage including New South Wales, Slovenia, Croatia, and Italy.

The Mapy.cz tourist basemap uses Mapy's official tile API and is only enabled when the app is built with `--dart-define=MAPY_CZ_API_KEY=<your-key>`.

For local development in this repo, you can keep API keys out of git by using `dart_defines.local.json` and launching with `--dart-define-from-file=dart_defines.local.json`. The repo now expects both `TRACESTRACK_API_KEY` and `MAPY_CZ_API_KEY` there for the keyed basemaps. Tracestrack requests also send a `Referer` header; override it with `--dart-define=TRACESTRACK_REFERER=<your-origin>` if your Tracestrack app key is restricted to a specific origin.

For the combined local Mapy + Slovenia debug setup, run `./run_local_maps.sh`. It starts the local Slovenia proxy on `127.0.0.1:8080` if needed, then launches `flutter run --dart-define-from-file=dart_defines.local.json`. Extra `flutter run` args are forwarded, for example `./run_local_maps.sh --verbose`.

The launcher reuses a healthy Tasmania tile server on localhost, or starts the
local stack when Docker is available. When local Docker is unavailable, it checks
the migrated server at `http://mac-mini.local:8090` and uses it if healthy.
Set `LOCAL_TOPO_BASE_URL` to select an externally managed server explicitly;
the launcher checks that URL and reports a failure if it is unavailable.
Save the URL printed by the launcher in **Settings → Local tile server base URL**.

If the selected Local Topo server times out, disconnects, or returns a server
error, the map switches to the fallback basemap and offers **Retry**. The saved
server URL and capability snapshot remain available for that retry; an ordinary
missing tile does not trigger a server-outage fallback.

You can manage the local Slovenia proxy on its own with `./start_slovenia_proxy.sh`, `./stop_slovenia_proxy.sh`, and `./restart_slovenia_proxy.sh`. The helper-managed proxy PID is stored in `.dart_tool/slovenia_topo_proxy.pid`, and proxy output goes to `.dart_tool/slovenia_topo_proxy.log`.

### macOS builds after moving or copying the project

Stop any existing `flutter run` session, then open a terminal in the intended
checkout and regenerate the local build files:

```bash
flutter clean
flutter pub get
flutter run -d macos --dart-define-from-file=dart_defines.local.json
```

Xcode and Flutter caches contain absolute paths. Copying `build`, `.dart_tool`,
`macos/Pods`, or `macos/Flutter/ephemeral` between project locations or machines
can produce stale-file warnings. Exclude these generated directories from sync
and recreate them locally. A terminal already running in a renamed directory
continues using that directory, so check `pwd -P` before launching.

`objectbox_flutter_libs` 5.3.2 requires Flutter's CocoaPods fallback and emits a
Swift Package Manager compatibility warning until ObjectBox adds support.
Disabling SwiftPM does not remove that warning in Flutter 3.47.
`geolocator_apple` 2.3.14 also emits upstream CoreLocation deprecation warnings;
these do not prevent a macOS build.
The `pub get` notice about newer versions is informational; use
`flutter pub outdated` to review upgrades separately.

## Theme Verification

Theme-related tests and native/manual visual checks use **My Seed Colour
(`#7E47EB`) in dark mode only** (`MyTheme.dark`). Do not add light-mode or other
seed-colour matrices. Keep distinct behaviour, failure, text-scale and resize
checks. Runtime theme options are unchanged. See the
[approved testing scope](ai_specs/app-profile.md#theme-testing-scope--approved-2026-10-21),
which supersedes older Spec/Work Item theme-testing requirements; dated evidence
retains its original scope and counts.

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
