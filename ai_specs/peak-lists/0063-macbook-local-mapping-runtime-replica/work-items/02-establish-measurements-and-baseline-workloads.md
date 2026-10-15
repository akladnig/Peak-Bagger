---
type: Work Item
title: Establish trustworthy startup/route measurements and fixed baseline workloads
parent: ../spec.md
---

## What to build

Instrument startup and accepted-click-to-visible-complete route updates, establish fixed real baseline workloads before optimization, and implement the named local-data-ready dashboard frame marker. Readiness must observe actual success/failure of all required local data/settings, including off-screen dependencies, while preserving existing UI fallback/error behavior and lazy widget construction.

This slice makes performance evidence trustworthy; startup and route optimizations follow in Items 09 and 10. Original reported 40+ second initialization and 20–30 second subsequent points are observations, not instrumented baseline measurements, and the original affected mode/coordinates remain unknown.

## Required context

- Read the parent Spec and ledger, especially Startup and recovery behavior 7–9, Route-point behavior and performance 6, and the performance execution gate.
- `lib/main.dart` already logs initialization phases, but startup-shell/ready-dependency completion is not the required dashboard endpoint. Inspect `macos/Runner/AppDelegate.swift` and the native runner when designing built-app monotonic launch timing and clock correlation.
- `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/providers/map_provider.dart`, dashboard card widgets, and their repositories/settings providers supply tracks, ascents, list/summary data, order, and settings. Audit every endpoint dependency rather than watching only visible cards. The current layout loader sets `_loaded` before its preferences read and catches failures; this cannot establish successful measurement readiness.
- `lib/services/route_elevation_sampler.dart`, `lib/services/route_planner.dart`, `lib/providers/route_planner_provider.dart`, `lib/providers/map_provider.dart`, and route/map widgets define accepted placement, lazy graph/DEM opening, sampling, commit, and visible statistics.
- Test anchors: `test/widget/dashboard_screen_test.dart`, `test/providers/dashboard_layout_provider_test.dart`, `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`, `test/providers/route_draft_state_test.dart`, `test/harness/route_elevation_fixture.dart`, and `test/robot/route_graph_mapping_journey_test.dart`. Reuse established dashboard selectors and injection; consult `pubspec.yaml` if dependencies change.

## Acceptance criteria

- [x] Measure manifest/path validation, polygon/catalog work, ObjectBox preparation/imports, route-graph loading/planning, DEM opening, geometry-point sampling, densified summary sampling, and final UI updates separately where applicable. Logs/evidence identify selected root, filesystem/transport, build mode, dataset identity, route coordinates, and cold/repeated conditions. Do not assert SMB is the proven cause before measurement.
- [x] Establish a named readiness marker at the first presented dashboard frame showing existing local tracks, ascents, list/summary content, and saved dashboard layout/settings loaded, with main navigation able to accept input. Ready-dependency completion, startup-shell handoff, first paint, or interactive navigation while existing local content loads cannot emit that marker.
- [x] Each required local-data/settings dependency exposes **pending**, **successfully loaded**, and **failed** measurement outcomes. Success includes legitimately empty data and absent saved settings only after a successful read. Empty values, fallback defaults, or flags set before a read completes are not success evidence. Failed required reads suppress the marker and produce a measurement diagnostic naming the dependency while preserving existing UI fallback/error behavior.
- [x] All required off-screen card data/settings must load successfully. Pending/failed off-screen dependencies suppress the marker; successfully loaded off-screen dependencies do not require widget construction or scrolling. Visible cards show current content at the qualifying frame.
- [x] Pending remote tiles or unrelated background work do not delay the marker unless they block the endpoint. Deterministic tests prove milestone semantics, not the real **≤5,000 ms** ceiling.
- [x] Record a monotonic process-launch timestamp for the already-built macOS app and the clock-correlation/measurement method linking it to the named qualifying frame. Include native and Flutter startup; exclude compilation, Flutter/Xcode tool startup, and debugger attachment. Keep startup checks, initialization/imports, and post-ready local-data loading separately observable.
- [x] Before optimization, fix the startup workload: relevant ObjectBox record counts, stored track-geometry vertex counts, migration/backfill status, saved dashboard order/relevant settings, window size, text scale, dataset identity, build mode, cold/repeated conditions, and launch repetition counts. Use non-sensitive read-only summaries; never copy personal databases, GPX content, or private configuration into workflow artifacts.
- [x] Before optimization, fix exact real Tasmania point sequences in primary **Snap-to-trail** mode for fresh and accumulated multi-point drafts, new-segment/cumulative draft lengths, geometry vertex counts, dataset identity, build mode, ObjectBox/graph state, and repetition counts. Include fresh launches with first lazy DEM/graph access and repeated-use cases. Record **Straight-line** and **Route-to-peak** correctness/responsiveness and timings separately.
- [x] Route timing runs from the accepted point-placement click through the frame showing the committed/snapped segment **and refreshed elevation, ascent, and descent**. Report individual placements and their maximum, with first subsequent and repeated cases separate; averages, marker appearance, and readiness for another click do not replace the **≤1,000 ms** ceiling (**500 ms** desired).
- [x] Observe ordinary start-point accepted-click-to-visible feedback against **≤100 ms** separately. Ordinary first-point placement performs no segment elevation sampling; distinguish Route-to-peak's immediate routing flow and investigate any separately reproduced start regression independently. Record event-loop/UI responsiveness and spinning-wheel observations.
- [x] Record actual before-cutover startup/route baseline evidence against the fixed workloads, preferring profile/release for acceptance and explicitly stating build mode. Initial synchronization and first-time imports have separate measurements. Hold workloads constant for comparable before/after runs; document deviations as different workloads, not interchangeable acceptance evidence or changes made to obtain a passing result.
- [x] Use behavior-first red/green/refactor for readiness/startup/async-result logic. Deterministic loader tests cover pending/success/failed data and settings, successful empty/absent settings, visible current content, off-screen pending/failure/success, and unrelated pending remote work. Reuse stable dashboard keys and controlled repository/preferences/basemap seams; automated tests require no personal datasets, SMB, SSH credentials, or API keys. Run focused provider/widget/robot checks and record results.

## Covers

- User Stories: 1, 2, 6.
- Requirements — Dependency inventory and diagnosis: 4–5.
- Requirements — Startup and recovery behavior: 7–9 (measurement semantics, baseline, and readiness observer; ceiling delivered in Item 09).
- Requirements — Route-point behavior and performance: 1–2, 6 (measurement protocol and baseline; performance delivered in Item 10).
- Technical Decisions: 1, 5–6.
- Blocking Decisions and Execution Gates: fixed route/startup workloads and named readiness milestone before optimization.
- Testing Strategy — Deterministic automated coverage: TDD default; startup readiness-marker coverage; relevant provider/widget/robot conventions.
- Testing Strategy — Live performance and operating evidence: initial diagnosis workloads; route individual/max timing protocol; fixed startup workload, process/frame correlation, and start-point timing protocol.
- Interview Ledger: L1, L2, L6, L7. Later refinement supplies the confirmed 5,000 ms/100 ms requirements; retain the ledger's historical provenance.

## Blocked by

None - ready to start

## Blocking decisions

- Establish and record the actual benchmark coordinates, fresh/accumulated draft workload, ObjectBox/graph conditions, build mode/repetitions, startup local-data/presentation workload, process-launch timing/clock correlation, and named readiness marker before optimization begins. These are diagnosis outputs, not values inferred from interview timings. Diagnosis and instrumentation can proceed before the gate is satisfied.

## Completion evidence — 2026-10-12

- Protocol and audited endpoint dependencies: [measurement guide](../../../../docs/mapping-performance-measurement.md).
- Executed, non-sensitive baseline: `docs/mapping-performance-baseline.md`. Exact Tasmania fresh/accumulated coordinates, lengths/vertices, source digests, graph generations, local record counts, migration flags, saved presentation settings, clock brackets, individual timings/maxima and repetition conditions are fixed there before optimization.
- Named endpoint: `dashboard.local_data_ready.frame`, with a correlated `.rasterized` engine-frame record. Read/application/render outcomes—not defaults or premature flags—govern emission. Native kernel process birth is correlated to the monotonic native/Flutter clocks. Raster finish is identified explicitly; no exact WindowServer/display scanout timestamp is claimed.
- The actual Route to Peak UI requires an existing start marker; preserve that behavior and measure its immediate button-triggered routing as `route.mode-action.accepted` → `route.mode-action.complete.frame.rasterized`, separately from ordinary first-point feedback and primary point-placement spans.
- Full final suite: **2,202 passed, five environment-dependent skips**. Focused provider/widget/robot checks and behavior-first failing/passing cases are recorded in the baseline. Analyzer: **no issues**. Instrumented macOS release builds and built-app launches succeeded.
- Full manifest-derived inventory re-audited: **25 files / 4,255,657,108 bytes**; per-file SHA-256 values match the previous dated audit, with no stale peak fingerprints. No personal database, GPX content or private configuration was copied into workflow artifacts.
- The operator's local Route count changed **77 → 79** during live work. Preserve those routes and treat the final records as a distinct workload B; do not interchange counts or historical timings to claim an improvement. A changed workload must be re-baselined for comparable optimization runs.
- Diagnosis is complete, **not performance recovery**: primary Snap-to-trail placements were **41.921 s / 33.765 s**; complete Route to Peak button action **34.775 s**. Provisioned-startup observations remain above 5 s, and ordinary start-point results vary by the recorded workload. UI-isolate stalls are recorded; spinning-wheel absence and SMB-only causality are not claimed. Items 09/10 retain ceiling delivery.
