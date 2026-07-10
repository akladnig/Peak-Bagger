---
type: Spec
title: Track Speed Analysis
---

## Problem

Peak Bagger already stores imported Tasmanian `GpxTrack` walks, filtered-track data, rest-aware track statistics, and route-graph metadata with preserved OSM tags, but it does not yet expose a user-facing way to learn how walking speed varies by terrain, gradient, and track classification. That leaves the user without a local reporting tool for validating whether current track metadata and historical walks are strong enough to support later prediction work. [L1] [L2] [L3] [L9]

## Proposed Outcome

Add a read-only `Track Speed Analysis` screen under `Settings` that computes a local aggregate report from imported Tasmanian `GpxTrack` walks. The screen analyses moving GPX legs only, excludes rests using the current `GpxTrack` rest calculation, classifies each moving leg by matched route-graph metadata and preserved OSM difficulty tags, and presents aggregate summary tables for speed by `track type`, `hiking difficulty`, combined `track type + hiking difficulty`, and signed gradient bands. The report is computed on demand, refreshable in place, and scoped to reporting rather than route prediction. [L1] [L2] [L3] [L5] [L6] [L7] [L8] [L10] [L11]

## User Stories

1. As a user, I can open `Track Speed Analysis` from `Settings` and review a read-only report built from my imported Tasmanian walks. [L1] [L5]
2. As a user, I can compare observed walking speed across `track type`, `hiking difficulty`, and gradient buckets rather than relying on whole-track averages. [L2] [L3] [L7]
3. As a user, I can trust the report to follow the app's current track-statistics basis by excluding rests with the existing `GpxTrack` logic and using `filteredTrack` when available. [L2] [L9]
4. As a user, I can refresh the report locally and understand its loading, empty, and failure states without losing the last successful results during a rerun. [L8] [L11]

## Requirements

1. Add a dedicated read-only `Track Speed Analysis` screen that is entered from a new tile in `Settings`. The screen must use standard back navigation to return to `Settings` and must not become a new top-level shell destination. [L5]
2. The feature must remain a reporting-only slice over historical imported `GpxTrack` walks. Route planning, route ETA, route prediction, and route model changes are out of scope for this slice. [L1]
3. The screen must start analysis automatically on first open. It must also provide a visible `Refresh Analysis` action that reruns the analysis against current local data. [L8]
4. The analysis dataset must include imported `GpxTrack` walks that have usable timestamps and usable geometry, and must analyse only their in-Tasmania portions. Tracks or spans that do not have the minimum timestamp or geometry data needed for speed analysis must be excluded from computation rather than producing synthetic values. [L4]
5. The analysis must use each consecutive moving GPX leg between two non-rest track points as the raw observation unit. Rests must be excluded using the current `GpxTrack` rest calculation rather than a new or separate rest heuristic. [L2] [L6]
6. For each eligible track, analysis must follow the app's current processing basis in this order: use `filteredTrack` when it is present and usable; otherwise use repaired processing XML when `gpxFileRepaired` is already present or current processing rules generate repaired XML for that track; otherwise fall back to raw `gpxFile`. The report must therefore align with the app's current track-statistics and filtered-track behavior. [L9]
7. Each moving-leg observation must be classified by matching the leg midpoint to the nearest route-graph way within a fixed tolerance of `20 m`. If no eligible way is found within that tolerance, the leg must remain in the dataset and use the canonical unmatched term `off-track`. [L4] [L6]
8. `Track type` must be derived from matched route-graph metadata using these exact buckets:
   1. `path` when `highway=path`
   2. `footway` when `highway=footway`
   3. `steps` when `highway=steps`
   4. `road` when matched `highway` is one of `service`, `unclassified`, `residential`, `tertiary`, `secondary`, `primary`, or `living_street`
   5. `track` when `highway=track`
   6. `off-track` when no eligible way is found within `20 m`
   7. `other` for any other matched way
   `Hiking difficulty` must be treated as a separate dimension derived from preserved OSM tags in this exact priority order:
   1. `sac_scale`
   2. `trail_visibility`
   3. `tracktype`
   4. `surface`
   5. `off-track`
   6. `unknown`
   Missing or unclassified matched values must fall through this priority and land in `unknown`; unmatched moving legs must use `off-track` rather than pretending to have matched route-graph metadata. For matched values, the bucket label must use the preserved tag value after trimming and lowercasing, so aggregation does not split only by case differences. [L3] [L6]
9. The report must derive signed gradient from each moving leg's elevation change and horizontal distance, and bucket each leg into these exact percent-grade bands:
   1. `<= -20%`
   2. `-20% to -10%`
   3. `-10% to -5%`
   4. `-5% to +5%`
   5. `+5% to +10%`
   6. `+10% to +20%`
   7. `>= +20%`
   8. `gradient unknown`
   Downhill must remain negative and uphill positive; the screen must not collapse signed gradient into absolute steepness. [L7]
10. The first slice must show these aggregate report sections:
    1. speed by `track type`
    2. speed by `hiking difficulty`
    3. speed by `track type + hiking difficulty`
    4. speed by gradient band
    Each section must present bucket label, median speed, sample count, total moving distance, and total moving time. Low-sample buckets must still be shown rather than hidden. Section and row ordering must be deterministic:
    1. report sections use the order listed above
    2. `track type` rows use this exact order: `path`, `footway`, `steps`, `road`, `track`, `off-track`, `other`
    3. `hiking difficulty` rows group by source family in this exact order: `sac_scale`, `trail_visibility`, `tracktype`, `surface`, `off-track`, `unknown`; within each matched family, bucket labels sort alphabetically
    4. `track type + hiking difficulty` rows sort first by the `track type` order above, then by the `hiking difficulty` order above
    5. gradient rows use the exact band order in requirement 9 [L2] [L3] [L7] [L10]
11. The first slice must stay aggregate-only. Do not add drill-down into underlying tracks or legs, per-track detail lists, map highlighting, CSV export, raw matched-leg inspection, or an analyst-facing editing workflow. [L10]
12. The report must be computed on demand from current local track and route-graph data. This slice must not persist a separate analysis dataset, must not add scheduled recomputation, and must not add background analysis jobs. [L8]
13. During a manual refresh after at least one successful analysis run, the screen must keep the prior report visible while showing a lightweight in-progress indicator near `Refresh Analysis`. A refresh must not blank the screen first when prior results exist. [L8] [L11]
14. Only one analysis run may be active at a time. While analysis is running, `Refresh Analysis` and `Retry` must be disabled. A stale completion from an older or superseded run must not overwrite newer visible state, and a completed run must not update disposed screen state after the user leaves the screen. [L8] [L11]
15. The screen must provide explicit user-visible local states:
    1. Initial loading state with copy `Analysing tracks...`
    2. Empty state with title `No analysis data yet`
    3. Empty-state body copy `Import timestamped Tasmanian tracks and recalculate track statistics to build walking-speed analysis.`
    4. Empty-state action `Refresh Analysis`
    5. Failure state with title `Analysis failed`
    6. Failure-state body showing a concise error summary
    7. Failure-state action `Retry`
    No special offline or slow-network state is required because the workflow is local-only. [L11]
16. The screen should include a short note that analysis uses the same filtered-track basis as current track statistics when available, so the user understands why changing filter settings and running `Recalculate Track Statistics` can change report results. [L9]
17. The screen must remain usable on desktop and narrow/mobile layouts. If the summary tables do not fit horizontally, the UI must allow scrolling rather than clipping data, and large text settings must not hide the primary state copy or the refresh action.

## Technical Decisions

1. Implement the reporting logic behind a pure analysis service or equivalent deterministic seam rather than embedding the classification and aggregation rules directly in the widget tree. The UI should render results from that seam and own only screen state such as initial load, refresh progress, active-run disabling, and error presentation. [L2] [L8]
2. Reuse the existing `GpxTrack` processing contract for source selection and rest handling, including `filteredTrack`, repaired GPX processing XML, and raw `gpxFile` fallback order. The analysis must not introduce a second persisted rest model, a second filtered-track contract, or a competing source-of-truth for moving versus resting time. [L2] [L9]
3. This slice may refactor current moving-versus-rest classification logic out of `GpxTrackStatisticsCalculator` into a shared deterministic seam, but both track statistics and `Track Speed Analysis` must use that same seam rather than separate heuristics. [L2] [L9]
4. Reuse current route-graph storage, especially `RouteGraphWayIndex` plus preserved raw tags in `tagsJson`, as the metadata source for `track type` and `hiking difficulty` in this slice. Future schema expansion may be useful later, but this Spec does not require new ObjectBox fields. [L3]
5. Reuse existing route-graph query and geometry-decoding patterns where practical, but add or extract a deterministic geo-distance nearest-way matcher for midpoint classification. Do not reuse screen-space hit testing or zoom-gated drive ETA logic for this analysis flow. [L6]
6. Keep entry from `Settings` using current settings-navigation patterns rather than adding a new shell branch or coupling the feature to the map screen. [L5]

## Testing Strategy

1. Use behavior-first TDD for the analysis logic and screen states.
2. Add focused service or unit coverage for:
    1. eligible-track selection and in-Tasmania clipping
    2. `filteredTrack` versus repaired versus raw source selection
    3. moving-leg extraction using the current `GpxTrack` rest semantics through the shared seam
    4. midpoint matching to the nearest route-graph way within `20 m`
    5. `off-track` classification for unmatched legs
    6. `hiking difficulty` tag-priority resolution from preserved OSM tags
    7. signed gradient calculation and exact band assignment
    8. report ordering for sections and bucket rows
    9. median-speed and totals aggregation for each report section [L2] [L3] [L4] [L6] [L7] [L9] [L10]
3. Add widget coverage for the new settings entry tile, first-load state, empty state, failure state, successful aggregate tables, disabled refresh/retry during an active run, and refresh-in-place behavior that keeps prior results visible while loading. [L5] [L8] [L10] [L11]
4. Add at least one robot or journey test that opens `Settings`, enters `Track Speed Analysis`, waits through a deterministic successful load, and verifies that the report can be refreshed without losing the prior rendered results. Use stable app-owned selectors for the settings tile, screen root, refresh action, loading indicator, empty state, error state, disabled active-run actions, and key report sections. [L5] [L8] [L11]
5. Use deterministic fakes or repository-backed fixtures for `GpxTrack` data and route-graph metadata; automated tests must not depend on live network calls, live Overpass refreshes, or real API keys.

## Out of Scope

1. Route ETA or route-prediction changes.
2. Per-bucket or per-track drill-down, raw leg inspection, export, or map-highlighting workflows.
3. Persisted analysis datasets, background recomputation, or scheduled analysis jobs.
4. New ObjectBox schema fields solely for this slice.
5. Date-range filters, user-defined filters, or custom bucketing controls.

## Open Questions

1. Should a later slice add date-range filters, per-track drill-down, or export once the aggregate report proves useful?
2. Should a later prediction slice promote some currently derived OSM difficulty fields into first-class ObjectBox fields for faster analysis or richer querying?

## Notes

1. Relevant starting files and seams include `lib/screens/settings_screen.dart`, `lib/router.dart`, `lib/models/gpx_track.dart`, `lib/services/gpx_filter.dart`, `lib/services/gpx_track_statistics_calculator.dart`, `lib/services/gpx_track_geometry.dart`, `lib/services/route_graph_query_service.dart`, `lib/services/route_graph_import_service.dart`, and `lib/services/route_graph_drive_eta_hit_service.dart`. [L2] [L3] [L5] [L6] [L9]
2. Existing glossary updates in `GLOSSARY.md` now define `Track`, `Route`, `Track type`, `Hiking difficulty`, and `Off-track` for this feature's terminology. [L1] [L3] [L6]
