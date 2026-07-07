---
type: Work Item
title: Shared Track Speed Analysis Seam And Aggregate Service
parent: ../spec.md
---

## What to build
Implement the deterministic reporting seam for `Track Speed Analysis` outside the widget tree. The seam must compute the aggregate report on demand from current local data, selecting each eligible `GpxTrack` source in the required order, clipping analysis to Tasmania, extracting moving GPX legs with the existing `GpxTrack` rest semantics, classifying each moving leg by nearest route-graph metadata within `20 m`, deriving exact `track type`, `hiking difficulty`, and signed gradient buckets, and aggregating the four required report sections with deterministic ordering.

## Required context
- `lib/services/gpx_track_statistics_calculator.dart` contains the current moving-versus-rest semantics that this item must reuse or extract into a shared deterministic seam instead of duplicating with a new heuristic.
- `lib/models/gpx_track.dart` contains the stored `filteredTrack`, `gpxFileRepaired`, and `gpxFile` fields that must be used in the exact fallback order from the Spec.
- `lib/services/route_graph_query_service.dart` and route-graph storage models are the existing route-graph query path. Reuse repository/query patterns where practical, but do not reuse screen-space hit testing or drive ETA matching logic for this analysis flow.
- `GLOSSARY.md` defines the canonical `Track`, `Route`, `Track type`, `Hiking difficulty`, and `Off-track` terms that this item must preserve in code, tests, and docs.
- Keep this as a pure service or equivalent deterministic seam consumed by later UI state. Do not add persistence for a derived analysis dataset, scheduled recomputation, background jobs, or new ObjectBox schema fields solely for this slice.
- `pubspec.yaml` shows no new dependency is required for this item; prefer existing repo libraries and test utilities.

## Acceptance criteria
- [ ] The analysis seam includes only imported `GpxTrack` walks with usable timestamps and usable geometry, analyses only their in-Tasmania portions, and excludes tracks or spans that lack the minimum timestamp or geometry data needed for speed analysis instead of producing synthetic values.
- [ ] For each eligible track, source selection follows this exact order: use `filteredTrack` when it is present and usable; otherwise use repaired processing XML when `gpxFileRepaired` is already present or current processing rules generate repaired XML for that track; otherwise fall back to raw `gpxFile`.
- [ ] The raw observation unit is each consecutive moving GPX leg between two non-rest track points, and rests are excluded using the existing `GpxTrack` rest calculation through the shared seam rather than a new or separate rest heuristic.
- [ ] Each moving-leg observation is classified by matching the leg midpoint to the nearest route-graph way within a fixed tolerance of `20 m`; if no eligible way is found within that tolerance, the leg remains in the dataset and uses the canonical unmatched term `off-track`.
- [ ] `Track type` uses the exact buckets and mapping from Requirement 8: `path`, `footway`, `steps`, `road`, `track`, `off-track`, and `other`, with `road` limited to matched `highway` values `service`, `unclassified`, `residential`, `tertiary`, `secondary`, `primary`, and `living_street`.
- [ ] `Hiking difficulty` is derived as a separate dimension from preserved OSM tags in this exact priority order: `sac_scale`, `trail_visibility`, `tracktype`, `surface`, `off-track`, `unknown`; matched values use the preserved tag value after trimming and lowercasing, unmatched moving legs use `off-track`, and missing or unclassified matched values land in `unknown`.
- [ ] Signed gradient is derived from each moving leg's elevation change and horizontal distance and bucketed into these exact bands: `<= -20%`, `-20% to -10%`, `-10% to -5%`, `-5% to +5%`, `+5% to +10%`, `+10% to +20%`, `>= +20%`, and `gradient unknown`, keeping downhill negative and uphill positive.
- [ ] The aggregate report exposes exactly these sections in this order: speed by `track type`, speed by `hiking difficulty`, speed by `track type + hiking difficulty`, and speed by gradient band; each row includes bucket label, median speed, sample count, total moving distance, and total moving time, and low-sample buckets are still returned rather than hidden.
- [ ] Section and row ordering are deterministic exactly as specified: `track type` rows use `path`, `footway`, `steps`, `road`, `track`, `off-track`, `other`; `hiking difficulty` rows group by source family `sac_scale`, `trail_visibility`, `tracktype`, `surface`, `off-track`, `unknown` with alphabetical bucket labels within matched families; combined rows sort first by `track type` order then by `hiking difficulty` order; gradient rows use the exact band order above.
- [ ] The seam remains reporting-only and does not add route planning, route ETA, route prediction, route model changes, drill-down into underlying tracks or legs, per-track detail lists, CSV export, raw matched-leg inspection, map highlighting, or analyst-facing editing workflow.
- [ ] Behavior-first TDD drives this item, with focused deterministic service or unit coverage for eligible-track selection and Tasmania clipping, source selection order, moving-leg extraction using the shared rest seam, midpoint nearest-way matching within `20 m`, `off-track` classification, `hiking difficulty` priority resolution, signed gradient band assignment, report ordering, and median/totals aggregation without live network calls, live Overpass refreshes, or real API keys.

## Covers
- User Stories: 2-3
- Requirements: 2, 4-12
- Technical Decisions: 1-5
- Testing Strategy: 1-2, 5
- Interview Ledger: L1-L4, L6-L10

## Blocked by
None - ready to start
