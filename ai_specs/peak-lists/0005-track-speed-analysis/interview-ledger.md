---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What is the canonical scope and terminology for this work?

Recommended Answer:
- Canonical input is imported `GpxTrack` walks recorded in Tasmania.
- The goal is to learn from historical walks in a reporting-first workflow; route prediction stays out of scope for this slice.
- Use `track` for a completed imported walk and `route` for a planned path.

Answer: As per recommended answer. To clarify route is out of scope.

Decision: This feature analyses historical imported Tasmanian `GpxTrack` walks in a reporting-only slice and preserves the existing `track` versus `route` distinction.

Negative Requirements:
- Do not change planned-route behavior in this slice.
- Do not turn this slice into route ETA or prediction UI.

### L2

Status: current

Question: What should the report analyse, and how should rests be handled?

Recommended Answer:
- Analyse observed walking speed at the segment level, then aggregate it into readable summary tables.
- Use short contiguous track segments as the measurement unit rather than whole-track averages.

Answer: That is good except rests need to be excluded. use the current rest calculations for GpxTrack

Decision: The report analyses segment-level walking speed observations and must exclude rests using the existing `GpxTrack` rest calculation.

Answer History:
- Initial answer accepted segment-level reporting but clarified that rests must be excluded.
- Final answer required the existing `GpxTrack` rest calculation rather than a new rest heuristic.

Reason: The existing rest semantics are already part of track statistics and should remain the source of truth for this report.

### L3

Status: current

Question: How should `track type` and richer difficulty metadata be derived?

Answer: Track type is the type of track identified by RouteGraphWayIndex. Also include the richer hiking-difficulty tags - these are essential. Agreed. A future requirement may need to include additional fields in ObjectBox.

Decision: `track type` comes from matched route-graph metadata, while `hiking difficulty` is a separate dimension derived from preserved OSM tags, with future ObjectBox expansion deferred.

Constraints:
- Keep `track type` and `hiking difficulty` separate.
- Preserve the ability to use richer OSM tags now through current preserved data.

### L4

Status: current

Question: Which tracks and segments belong in the analysis dataset?

Recommended Answer:
- Include all imported `GpxTrack` walks that have usable timestamps and at least one segment inside Tasmania.
- Analyse only the in-Tasmania portions of those tracks.
- Keep unmatched in-Tasmania moving segments in the dataset.
- Exclude tracks or spans that lack the minimum data needed for segment speed analysis.

Answer: agreed

Decision: The analysis dataset includes in-Tasmania portions of imported tracks with usable timestamps and geometry, and keeps unmatched moving segments rather than dropping them.

### L5

Status: current

Question: Where should this reporting workflow live in the app?

Recommended Answer:
- Add a dedicated `Track Speed Analysis` screen.
- Entry point: a new item under `Settings`.
- Exit behavior: standard back navigation returns to `Settings`.
- The screen is read-only in this slice.

Answer: agreed

Decision: The feature is a dedicated read-only `Track Speed Analysis` screen entered from `Settings` with normal back navigation.

### L6

Status: current

Question: How should moving track spans be matched to route-graph metadata?

Recommended Answer:
- Use each consecutive moving GPX leg between two non-rest track points as the raw observation unit.
- Classify each leg by matching its midpoint to the nearest route-graph way within a fixed tolerance of `20 m`.
- If no way falls within the tolerance, classify the leg as `unknown/off-network`.

Answer: agreed. Also change terminology from unknown/off-network to off-track

Decision: Each consecutive moving GPX leg is matched by midpoint to the nearest route-graph way within `20 m`; unmatched legs are classified as `off-track`.

Negative Requirements:
- Do not use `unknown/off-network` as the user-facing term.

### L7

Status: current

Question: What gradient bands should the report use?

Recommended Answer:
- Use signed gradient bands based on percent grade for each moving leg:
  - `<= -20%`
  - `-20% to -10%`
  - `-10% to -5%`
  - `-5% to +5%`
  - `+5% to +10%`
  - `+10% to +20%`
  - `>= +20%`
- Keep downhill negative and uphill positive.
- If a moving leg lacks usable elevation data, keep it under `gradient unknown`.

Answer: agreed

Decision: The report uses the exact signed gradient bands above plus `gradient unknown` when gradient cannot be derived.

### L8

Status: current

Question: Should the analysis be persisted or computed on demand?

Recommended Answer:
- Do not persist a separate analysis dataset in this slice.
- Compute the report on demand from the current local `GpxTrack` data plus the current route graph.
- Run the analysis automatically when the screen opens.
- Keep a visible `Refresh Analysis` action.
- While a refresh is running, keep showing the last completed report if one exists.

Answer: agreed

Decision: The report is computed on demand from current local track and route-graph data, runs on screen open, and refreshes in place without clearing the last successful report.

Negative Requirements:
- Do not add a persisted analysis table in this slice.
- Do not add background or scheduled recomputation in this slice.

### L9

Status: current

Question: Should the analysis use raw imported GPX or the app's filtered track data?

Recommended Answer:
- Use the current filtered track data when `filteredTrack` is present.
- Otherwise use repaired GPX processing XML when `gpxFileRepaired` is present or current processing rules generate repaired XML for the track.
- Fall back to raw `gpxFile` only when filtered and repaired processing data are unavailable or unusable.
- The report should reflect the app's current GPX filter settings and any later `Recalculate Track Statistics` run.

Answer: agreed

Decision: `Track Speed Analysis` uses `filteredTrack` when available, otherwise uses repaired GPX processing XML when present or generated by current processing rules, and falls back to raw `gpxFile`, staying aligned with current track-statistics behavior.

### L10

Status: current

Question: Should the first screen support drill-down or remain aggregate-only?

Recommended Answer:
- Keep the first slice aggregate-only.
- Show summary tables with bucket label, median speed, sample count, total moving distance, and total moving time.
- Do not add per-bucket drill-down, per-track lists, map highlighting, CSV export, or raw matched-leg inspection yet.
- If a bucket has too few samples to be reliable, still show it rather than hiding it.

Answer: agreed

Decision: The first slice is aggregate-only and must show low-sample buckets rather than suppressing them.

### L11

Status: current

Question: What loading, empty, and failure states should the screen show?

Recommended Answer:
- On first open, show a loading state with copy `Analysing tracks...`.
- Empty state:
  - title: `No analysis data yet`
  - body: `Import timestamped Tasmanian tracks and recalculate track statistics to build walking-speed analysis.`
  - action: `Refresh Analysis`
- Error state:
  - title: `Analysis failed`
  - body: a concise error summary
  - action: `Retry`
- During manual refresh after a successful run, keep the previous report visible and show a lightweight in-progress indicator near `Refresh Analysis`.

Answer: agreed

Decision: The screen has explicit local loading, empty, and failure states with the exact loading and empty copy above, plus in-place refresh behavior.
