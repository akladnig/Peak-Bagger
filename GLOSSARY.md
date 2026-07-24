# Peak Bagger Glossary

This glossary captures stable project-specific terms used across planning and implementation work in this repository.

## Terminology

**Starter app**:
A project-owned reusable Flutter app foundation extracted from this repository for generating new apps with shared UI and infrastructure.
_Avoid_: Flutter template, SDK template

**Track**:
An imported `GpxTrack` that represents a completed recorded walk.
_Avoid_: route when referring to historical walk data

**Route**:
A planned path saved in the app for future use, separate from a completed imported walk.
_Avoid_: track when referring to planned geometry

**Track type**:
The classification of a walked segment derived from app-owned map or trail metadata, rather than a free-text user label.
_Avoid_: user-entered category, manual label

**Hiking difficulty**:
The difficulty classification of a walked segment derived from preserved OSM tags, prioritizing tags such as `sac_scale`, `trail_visibility`, `tracktype`, and `surface`.
_Avoid_: track type when referring to difficulty-specific tagging

**Peak difficulty**:
The region-specific difficulty grade stored on a `Peak` record and used for peak browsing, sorting, and filtering.
_Avoid_: hiking difficulty when referring to peak metadata

**Peak duration**:
The estimated standard out-and-back walking duration stored on a `Peak` for peak browsing, sorting, and filtering.
_Avoid_: live ETA, ascent-history duration

**Off-track**:
A moving track segment that does not match any route-graph way closely enough to inherit route-graph metadata.
_Avoid_: unknown/off-network

**Ranked peak list CSV**:
A header-detected peak-list import format produced by region ranking tools such as `tool/rank_fvg_peaks.dart`, where each row identifies an existing peak by `osmId` and can carry shared peak metadata updates plus list membership.
_Avoid_: FVG format

**App-owned export CSV**:
A project-generated peak-list CSV produced by the app's export flow and accepted again by the corresponding app-owned import flow for round-trip maintenance.
_Avoid_: ranked peak list CSV, legacy export format

**Hribi source peak list**:
A CSV-only raw peak extract built from `hribi.net` range and detail pages, optionally enriched from sibling translated domains such as `monti.uno`, without matching rows to existing app peaks.
_Avoid_: ranked peak list CSV, import-ready peak list

**Slovenia ranked peak list**:
A Slovenia peak CSV produced by correlating Hribi-sourced rows to existing ObjectBox `Peak` records so the result is import-ready rather than a raw source extract.
_Avoid_: Hribi source peak list, raw Slovenia export

**Correlation review CSV**:
A read-only CSV review artifact for Slovenia rows that could not be confidently correlated to exactly one existing ObjectBox `Peak` record.
_Avoid_: repair list, canonical ranked CSV

**Repair list**:
A sidecar CSV of unresolved range or peak source pages that a later repair-only run retries instead of crawling the full upstream set again.
_Avoid_: retry cache, hidden state file

**Tassy Full**:
A Tasmania-only project-managed peak list intended to represent the full Tasmanian set rather than a cross-region super-set.
_Avoid_: all-lists super-set, non-Tasmanian aggregate

**Mixed-region peak list**:
A `PeakList` whose member peaks span more than one canonical region. Persist `PeakList.region` as `mixed` when referring to this classification.
_Avoid_: treating `PeakList.region` as the list's geometric coverage

**Italy administrative region**:
A stored/search region key for an ISO 3166-2:IT first-level Italian subdivision, such as `fvg`, `veneto`, `trentino-alto-adige`, or `emilia-romagna`.
_Avoid_: Italy North East subregion, treating `italy-nord-est` or `italy-nord-ovest` as the stored peak region

**Manifest priority**:
A manifest-defined segmented numeric canonicalization path such as `2`, `2.1`, or `2.1.3` that orders overlapping region matches without relying on manifest file order.
_Avoid_: lexical string sorting, treating missing segments as implicit zeroes, or using JSON entry order as precedence

**Italy aggregate region**:
An app-owned union region such as `italy-nord-est` or `italy-nord-ovest` that groups multiple Italy administrative regions.
_Avoid_: Italian administrative region, source-of-truth region

**Search popup**:
The map screen's `MapSearchPopup` multi-entity search surface, which replaces the older peak-only search experience.
_Avoid_: peak search when referring to the popup flow

**Map metadata filter**:
The `MapScreen` filter control for peak metadata such as rating, difficulty, and duration.
_Avoid_: peak list filter when referring to metadata dropdowns

**Local Topo tile source**:
A project-managed source for app-consumable `Local Topo` raster `XYZ` tiles, whether backed by on-demand rendering or pre-rendered static tile output.
_Avoid_: treating the broader delivery concept as server-only, Flutter-embedded renderer

**Local tile server**:
A project-managed HTTP service that serves app-consumable `XYZ` map tiles for one or more managed regions as one possible `Local Topo tile source` implementation, and may run on a laptop, mini PC, NAS, or localhost during development.
_Avoid_: using this term for static pre-rendered tile delivery in general, localhost-only basemap

**Local Topo**:
The app-owned basemap label for the project-managed locally hosted topographic `XYZ` source rendered from the canonical style and region-scoped source data.
_Avoid_: style editor, vector basemap, user-custom basemap

**MapTiler Topo**:
A planned future app-facing basemap label for the Tasmania-local visual port of the downloaded MapTiler `Topo` style, kept distinct from `Local Topo`.
_Avoid_: calling this `Local Topo` or using `Topo` alone when the future picker label matters

**MapTiler Outdoor**:
A planned future app-facing basemap label for the Tasmania-local visual port of the downloaded MapTiler `Outdoor` style, kept distinct from `Local Topo`.
_Avoid_: calling this `Local Topo` or using `Outdoor` alone when the future picker label matters

**Terrain relief shading**:
A raster shaded-relief treatment derived from DEM elevation and blended into `Local Topo` to create terrain depth in a north-up 2D basemap.
_Avoid_: true 3D terrain, pitched map camera, extruded terrain

**Local tile server base URL**:
The user-configured Settings value that points `Peak Bagger` at the root HTTP host for project-managed local topo basemap routes.
_Avoid_: hard-coded localhost, embedded server address

**theLIST 25m DEM**:
The Tasmania-specific elevation raster source used by this project for DEM-backed workflows when a Tasmania-local source of truth is required.
_Avoid_: generic Tasmania DEM, OSM elevation data

**ELVIS DEM**:
The project's canonical higher-detail Tasmania DEM input stored outside git, preferred for `Local Topo` rebuild inputs and as the source for repo-managed runtime elevation derivatives.
_Avoid_: treating the Flutter app as reading `/Volumes/Media/Elvis` directly at runtime, using `ELVIS` alone when the source-versus-derived distinction matters

**ELVIS runtime DEM**:
The repo-managed external Tasmania `10m` DEM derived from the full `ELVIS DEM` dataset for Flutter elevation sampling workflows.
_Avoid_: raw ELVIS tile tree, bundled app asset when the external generated file contract matters

**ELVIS topo DEM**:
The repo-managed external DEM derivative under `elvis_topo` used by Tasmania `Local Topo` contour and terrain-relief build workflows.
_Avoid_: assuming the Flutter app runtime DEM and topo-build DEM are the same artifact

**Peak list mini-map**:
The embedded map on `PeakListsScreen` that previews the selected peak list's geography.
_Avoid_: mini-map when the dashboard latest-walk preview is also in scope

**Background job**:
App-managed long-running import or export work with shared status that is not tied to the initiating screen.
_Avoid_: screen-local task, blocking import/export

**Peak ownership ring**:
The segmented ring drawn around a peak marker or peak cluster to show visible peak-list ownership in map rendering.
_Avoid_: list ring, ownership halo

**Peak visibility mode**:
The main-map three-state peak display control that chooses between hidden peaks, individual peak markers, and peak clusters.
_Avoid_: peak cluster setting, show peaks FAB when referring to the full three-state behavior

**Peak duplicate resolution**:
An ObjectBox Admin peak-maintenance workflow that reassigns app-owned references from a duplicate `Peak` to one surviving canonical `Peak` before deleting the duplicate row.
_Avoid_: plain delete when the peak is being replaced

**Surviving peak**:
The canonical `Peak` record kept after peak duplicate resolution, after app-owned references are moved off the duplicate record.
_Avoid_: target row, kept duplicate

**Region FAB**:
A permanent peak-list control shown for one manifest region, such as `Tasmania` or `Slovenia`, rather than for an individual peak list.
_Avoid_: country FAB when the source of truth is a manifest region

**My Ascents**:
The peak info popup term for the user's recorded climbed tracks associated with a peak.
_Avoid_: Available Tracks
