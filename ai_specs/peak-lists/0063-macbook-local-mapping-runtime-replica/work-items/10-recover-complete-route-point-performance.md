---
type: Work Item
title: Recover responsive complete route-point updates
parent: ../spec.md
---

## What to build

Profile the concrete local-generation route path and resolve remaining raster, route-graph, CPU, I/O, or rendering bottlenecks. Deliver visible committed/snapped route segments and current elevation/ascent/descent within **1,000 ms**, aiming for **500 ms**, on the fixed representative short Tasmania cases, including first lazy opens and repeated use.

Preserve ordinary start-point visible feedback within **100 ms**, route accuracy/state/error contracts, and interactive/renderable UI during longer calculations. Worker/sample-reuse changes are profiling-dependent; implement them only when justified, with explicit native ownership and invalidation.

## Required context

- Project-root-relative `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md`: Desktop wide / macOS-only foundations apply. This computation/ownership slice introduces no dimension-dependent layout or pending-value resolution.
- Read the parent Spec/ledger, Item 02's exact fixed route benchmark and accepted-click-to-presented-complete-frame timing, and Item 05's pinned local generation/readiness/late-import contracts. The original affected mode/coordinates remain unknown; the approved primary benchmark is **Snap-to-trail**.
- `lib/services/route_elevation_sampler.dart` contains GDAL opening, synchronous native sampling, densified summaries, and sampling/error contracts. `lib/services/route_planner.dart`, `lib/services/route_graph_store.dart`, `lib/services/route_graph_query_service.dart`, and `lib/providers/route_planner_provider.dart` define graph/planning seams.
- `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, route draft state and route/map widgets, especially `lib/widgets/map_route_bottom_sheet.dart`, govern point acceptance, geometry/statistics commit, visible errors/retry, cancel, undo/redo, and saving.
- Reuse `FakeDemFileSystem`, `FakeDemDatasetOpener`, `LookupDemDataset`, and existing planner/sampler injection in `test/harness/route_elevation_fixture.dart`, `test/services/route_elevation_sampler_test.dart`, `test/providers/route_draft_state_test.dart`, and `test/providers/route_elevation_mapping_test.dart`.
- Widget/robot anchors: `test/widget/map_screen_route_sheet_test.dart`, `test/robot/route_graph_mapping_journey_test.dart`, `test/robot/map/map_route_journey_test.dart`, and `test/robot/map/map_route_robot.dart`. Use stable keys, deterministic geometry/data fixtures, controlled pending futures, and fake basemap/external services. Read `pubspec.yaml` before dependency changes.
- Retention from Item 06 consumes Item 05's session/native ownership; any new worker/cache must honor that contract, even if scheduled refresh is not yet installed.

## Acceptance criteria

- [x] Confirm the pre-optimization benchmark record fixes exact real Tasmania sequences in **Snap-to-trail**, fresh and accumulated multi-point drafts, new-segment/cumulative lengths, geometry vertex counts, dataset identity, build mode, ObjectBox/graph state, fresh/repeated conditions, and repetitions. Do not substitute different workloads to obtain passing timings.
- [x] Profile route-graph load/planning, first lazy DEM open, geometry-point sampling, densified summary sampling, commit/state propagation, and final frame separately. Record the concrete local root, filesystem, dataset identity, coordinates, build mode, and cold/repeated conditions; quantify residual causes instead of asserting SMB or caching alone explains performance.
- [x] Every recorded representative short Tasmania placement is **≤1,000 ms** from accepted click to the frame showing committed/snapped segment **and refreshed elevation, ascent, and descent**. Aim for **500 ms**. Measure first subsequent placement after launch, including lazy DEM/graph access, and repeated subsequent placements separately; marker appearance/readiness for another click is insufficient.
- [x] Ordinary start-point feedback is visible within **≤100 ms** of accepted click. Ordinary first-point placement performs no segment elevation sampling; preserve immediate feedback and distinguish **Route-to-peak** immediate routing. Investigate separately reproduced ordinary first-point regressions independently of subsequent-point work.
- [x] Route/elevation calculations cause no macOS spinning wheel or blocked map interaction, including longer calculations outside the short benchmark. Pending/loading state stays renderable while supported controls can interact; do not weaken existing routing-in-progress guards on accepting additional point-placement actions.
- [x] Preserve geometry, endpoint snapping, elevation accuracy, summary semantics, point ordering, undo/redo, saving, and mode-specific behavior. Cancellation/request/geometry-version checks prevent obsolete routing/elevation results from updating canceled or newer drafts.
- [x] Keep the session's concrete local generation for all lazy DEM opens, late imports, workers, and samples even if another generation becomes pending/selected for a later session. Preserve host GDAL/PROJ dependencies and existing DEM selection at `DEM/Elvis/elvis_runtime_10m.tif`; no new elevation source or reduced accuracy/coverage is introduced.
- [x] Preserve visible route/elevation failure and retry behavior for local-source errors. Logs identify operation and local dataset context; failures trigger neither hidden SMB access nor silent replacement of failed elevation work with successful/zero results.
- [x] Expensive native raster/CPU work must not monopolize Flutter's UI isolate. If changing workers/native dataset caches, define creation, ownership, request dispatch, cancellation/stale-result handling, and deterministic disposal/release; retain generation protection while any handle/worker uses it.
- [x] If profiling justifies sample reuse, combine unchanged/new samples before recomputing summaries and compare to the existing full-recomputation baseline. Three-point ascent/descent smoothing changes values around appended boundaries; independently summing segment totals is not equivalent. Invalidate/account for snapping, edits, undo/redo, dataset-generation changes, and request/geometry versions.
- [x] Use behavior-first red/green/refactor for new async-result logic. Unit/service/provider tests cover selected-local opener paths, exact geometry/summary semantics, pending work permitting frame pumping, source errors/retry, canceled/newer geometry rejecting stale results, and explicit worker/native ownership when changed. Automated tests require no real Mapping files, SMB, credentials, or API keys.
- [x] Conditional sample-reuse regressions compare cached/new results with full recomputation for append-boundary smoothing, snapping, edits, undo/redo, generation changes, and invalidated requests. A later selection never redirects an existing session's imports/lazy opens.
- [x] Extend stable-key deterministic robot/widget journey coverage for route draft → point → completed geometry/statistics, faking basemap/external services. Recheck cancel/undo/redo when touched by state/worker changes and verify pending frames, supported interaction, visible errors/retry, and mode-specific behavior.
- [x] Live evidence uses the fixed sequences on the MacBook with real local GDAL and replicated ELVIS runtime DEM, preferring profile/release and explicitly recording build mode. Report every placement and maximum, first lazy versus repeated cases, UI/event-loop responsiveness, and spinning-wheel observations; no averages replace the ceiling. Exercise **Straight-line** and **Route-to-peak** correctness/responsiveness and report their timings separately.
- [x] Run focused changed-area tests, Flutter analyzer, and relevant broader route regressions before release. Record actual measurements, skips/environmental blockers, unmet ceilings, and stretch-target status. Automated fakes alone cannot prove native raster performance; incomplete live acceptance remains explicitly incomplete.

## Covers

- User Stories: 2.
- Requirements — Dependency inventory and diagnosis: 4–5.
- Requirements — Canonical ownership and local runtime access: 3, 6 (session-local path preservation).
- Requirements — Automatic synchronization and activation: 6 (native/session generation lifetime).
- Requirements — Generation retention and cleanup: 2 (changed native cache/worker ownership).
- Requirements — Route-point behavior and performance: 1–7.
- Technical Decisions: 1, 4–6; background-only replication and host GDAL/PROJ preservation.
- Blocking Decisions and Execution Gates: fixed route workload before optimization.
- Testing Strategy — Deterministic automated coverage: TDD default for async-result logic; provider/elevation coverage; conditional sample-reuse regressions; route widget/robot journeys.
- Testing Strategy — Live performance and operating evidence: fixed fresh/accumulated workloads, complete-frame individual/max timing, 1,000 ms ceiling/500 ms desired target, 100 ms ordinary start-point feedback, responsiveness, separate modes, analyzer/regressions.
- Interview Ledger: L1, L2, L6, L7; refinement confirms 100 ms ordinary start-point ceiling and benchmark protocol.

## Blocked by

- [02-establish-measurements-and-baseline-workloads.md](02-establish-measurements-and-baseline-workloads.md)
- [05-select-runtime-and-recover-startup.md](05-select-runtime-and-recover-startup.md)

## Implementation and verification — completed 2026-10-14

- [Fixed workloads, profiling, ownership and live evidence](../../../../docs/mapping-route-performance.md)
  retain the exact Item 02 Tasmania sequence and local workload C. Before: P2
  **9,121.479 ms**, P3 **10,169.320 ms**, ordinary start **180.529 ms**.
- Final ARM64 macOS release, real pinned local ELVIS/GDAL: P2 first lazy
  **432.103 ms**, accumulated P3 **229.414 ms**, maximum **432.103 ms**.
  Both required **1,000 ms** and desired **500 ms** targets are met for these
  fixed recorded cases. Ordinary Snap start **50.343 ms**, Straight-line start
  **46.839 ms**; neither opens/samples a segment DEM.
- Straight-line P2/P3 **89.654 / 119.246 ms** and Route-to-peak button
  **339.345 ms** are separate mode checks with matching expected statistics.
  Supplemental exact-coordinate warm-use P2/P3 **196.244 / 223.997 ms**;
  different zoom-13 exploratory inputs are excluded, not substituted.
- Generation-bound graph validation receipts, inclusive bounded ObjectBox
  snapshot queries, graph construction/search/probe isolates and a serial lazy
  DEM worker remove repeated full-table validation and UI native sampling.
  Prepared immutable polygon containment removes repeated normalization.
  Ordinary start state is published coherently once. Lazy source preparation
  overlaps planning only after an accepted subsequent click, inside its span.
- The Riverpod-owned DEM worker retains native generation protection through
  confirmed exit, drains pending work, closes datasets/transforms, rejects new
  requests during disposal and fails pending work on unexpected exit. Geometry
  is frozen before awaits. Full manifest/request/geometry-version checks reject
  superseded work; late selection never redirects workers or imports.
- No sample reuse was justified/introduced: conditional sample-cache criteria
  are **not applicable**. Full densification/smoothing/summary semantics remain;
  native synthetic-raster tests compare every summary field across append,
  reversal, shortening and restoration. Host GDAL/PROJ and selected DEM remain.
- The longer **15,644 m** case completed in **1,020.338 ms** outside the short
  ceiling, with pending UI/name interaction and no >100 ms heartbeat gap during
  that placement. No spinning wheel/non-responsive-app warning was observed in
  final checks. A **278.283 ms** first-use library/worker heartbeat gap is retained
  explicitly; no universal zero-jank/cursor-absence claim is made.
- Earlier unmet ceilings and ordinary-start regression, desktop interruptions,
  lock-screen exclusions and input-precision deviations remain in the evidence.
  Final read-only summary matches workload C exactly; Route count stays **80**,
  and no test draft was saved or personal data copied/deleted.
- Focused 13-file run **223 passed**; later preparation cycles passed and the
  ordinary-start refactor passed a **100-test** provider/widget/robot run.
  Full `caffeinate -i flutter test --no-pub --reporter expanded`: **2,282 passed,
  5 existing skips**, **4m52s**. Analyzer **no issues**, diff checks passed,
  instrumented and final normal macOS release builds succeeded.

### Journey Verification
- Journey: Draft → point → pending interaction → completed geometry/statistics → undo/redo → Cancel
- Verification command(s): `flutter test --no-pub test/robot/map/map_route_journey_test.dart`
- Required seams/selectors: controlled planner/elevation futures, fake external basemap/in-memory records, existing route name/loading/marker/ascent/descent/undo/redo/Cancel keys
- Result: `pass`
- Remaining risk: Fake journey timing does not establish hardware ceilings; fixed real native measurements are recorded separately above.

### Journey Verification
- Journey: Route-source failure → Dismiss → Retry → completed segment
- Verification command(s): `flutter test --no-pub test/robot/route_graph_mapping_journey_test.dart test/providers/route_elevation_mapping_test.dart`
- Required seams/selectors: selected-local source failures/planner injection, Mapping operation coordinator and existing Retry/Dismiss/route-planning keys
- Result: `pass`
- Remaining risk: Immutable live datasets were not corrupted to manufacture failures; disposable fixtures and controlled seams verify error/retry behavior.
