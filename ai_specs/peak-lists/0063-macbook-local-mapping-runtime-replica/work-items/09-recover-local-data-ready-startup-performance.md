---
type: Work Item
title: Recover provisioned local-data-ready startup performance
parent: ../spec.md
---

## What to build

Profile and optimize the provisioned MacBook local-generation startup path against Item 02's fixed workload and trustworthy local-data-ready frame marker. Meet the confirmed **≤5,000 ms** built-app process-launch-to-usable-dashboard ceiling while retaining all readiness, import correctness, settings, data-loading, and UI behavior contracts.

Address measured residual startup/native/ObjectBox/provider/rendering work rather than assuming local storage alone is sufficient. Preserve the Flutter/Riverpod/ObjectBox architecture and keep bulk replication/hashing out of startup.

## Required context

- Project-root-relative `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS); this startup/data-access slice does not depend on pending window/layout dimensions.
- Read the parent Spec/ledger, Item 02's saved baseline workload, process-launch timing/clock correlation and marker semantics, and Item 05's local configuration/transactional activation/readiness flow. Optimization cannot start until the recorded measurement gate is satisfied.
- `lib/main.dart`, `lib/startup_shell.dart`, `lib/services/mapping_store_core.dart`, `lib/services/mapping_data_store.dart`, `lib/services/objectbox_store_directory.dart`, `lib/services/objectbox_schema_guard.dart`, and current bootstrap/import paths define startup ordering.
- `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/providers/map_provider.dart`, dashboard cards/settings/repositories, and Item 02's observer define all endpoint dependencies, including off-screen data.
- Test conventions: `test/widget/startup_shell_test.dart`, `test/widget/dashboard_screen_test.dart`, `test/providers/dashboard_layout_provider_test.dart`, `test/services/mapping_data_store_test.dart`, `test/robot/dashboard/dashboard_journey_test.dart`, and `test/robot/dashboard/dashboard_robot.dart`. Reuse deterministic successful/pending/failed loaders, existing selectors, and fake remote services. Read `pubspec.yaml` before dependency changes.
- Existing source/network startup timings are comparison evidence only; the accepted runtime is Item 05's concrete local generation. Retained active/recovery/session protection and existing personal-data locality remain in force.

## Acceptance criteria

- [x] Confirm Item 02 has fixed the exact startup local-data/presentation workload and repetitions, process-launch timing method/clock correlation, and named local-data-ready marker. Its required dependencies expose pending/successfully loaded/failed outcomes, including off-screen dependencies. Do not optimize against shell/first-paint timing or an unrecorded workload.
- [x] Profile selected-local-generation manifest/path checks, polygon/catalog work, ObjectBox preparation/open/schema/import work, initialization, post-ready local-data/settings loading, and UI/frame presentation separately. Record selected root, local filesystem, dataset identity, ObjectBox state, build mode, and cold/repeated conditions.
- [x] For an already-provisioned app with existing ObjectBox data, achieve **≤5,000 ms** from monotonic process launch of the already-built macOS app to the first presented qualifying dashboard frame. Include native/Flutter startup and exclude compilation, Flutter/Xcode tool startup, and debugger attachment. Record timestamp, marker, clock correlation/measurement method, phase timings, and total for cold/repeated launches.
- [x] At the endpoint, existing local tracks, ascents, list/summary content, and saved dashboard layout/settings are successfully loaded, visible cards present current content, and main navigation accepts input. Ready-shell handoff, ready-dependency completion, provisional empty/loading values, or interactive navigation while existing local content loads do not qualify.
- [x] Legitimately empty data or absent saved settings qualifies only after a successful read. Failed reads represented by empty/default fallback values never qualify; preserve existing UI fallback/error behavior and record a measurement diagnostic naming each failed required dependency.
- [x] All required off-screen data/settings load successfully; their widgets remain permitted to be lazy and need not be constructed/scrolled into view. Pending remote tiles or unrelated background work may continue unless they block the endpoint.
- [x] Recheck relevant ObjectBox record counts, stored track-geometry vertices, migration/backfill status, saved dashboard order/settings, window size, text scale, dataset identity, build mode, cold/repeated conditions, and repetition counts against the baseline. Hold comparable workloads constant; record deviations as different workloads, never as interchangeable before/after evidence or easier replacement benchmarks.
- [x] Preserve manifest/source schemas, region/coverage resolution, fingerprints, path containment, required polygon/source validation, all declared DEMs, and preflight-before-ObjectBox ordering. Existing data/caches cannot bypass checks, and eligibility does not entail launch-time multi-gigabyte rehashing. No canonical SMB readiness/freshness probe or runner wait is introduced.
- [x] Separate initial synchronization and first-time dataset imports from steady-state launch evidence; report dataset/ObjectBox/import state so exclusions cannot hide a regression. Native/CPU/I/O work must not monopolize Flutter's UI isolate; use profiling to justify narrowly scoped optimizations and ownership/release for any changed caches/workers.
- [x] Use behavior-first red/green/refactor for new startup-state/publication/async-result logic. Focused provider/widget/robot regressions preserve success/failure readiness semantics, settings/order/content, off-screen pending/failed checks, platform/error behavior, retry/quit, navigation input, and responsive frames under pending fake work. Stable keys/deterministic loaders and fake basemap/external services avoid live user data/credentials.
- [x] Run focused changed-area tests and Flutter analyzer, then relevant broader regressions before release. Record actual live profile/release evidence (or explicit build mode), environmental blockers/skips, failed-dependency diagnostics, and remaining unmet targets. Fake tests prove semantics, not the real 5-second ceiling; do not mark performance complete without qualifying measured evidence.

## Covers

- User Stories: 1, 6.
- Requirements — Dependency inventory and diagnosis: 4.
- Requirements — Canonical ownership and local runtime access: 3–4, 6 (preserved local readiness and reads).
- Requirements — Startup and recovery behavior: 7–9.
- Technical Decisions: 1, 5–6; background-only bulk copy/integrity work.
- Blocking Decisions and Execution Gates: fixed startup workload and successful-data-ready milestone before optimization.
- Testing Strategy — Deterministic automated coverage: TDD default where applicable; startup readiness-marker regressions; relevant startup/dashboard/provider/widget/robot coverage.
- Testing Strategy — Live performance and operating evidence: fixed startup workload, process/frame correlation, local-data-ready endpoint, phase/import separation, analyzer and regressions.
- Interview Ledger: L1, L2. The 5,000 ms requirement is confirmed in refinement, preserving original ledger provenance.

## Blocked by

- [02-establish-measurements-and-baseline-workloads.md](02-establish-measurements-and-baseline-workloads.md)
- [05-select-runtime-and-recover-startup.md](05-select-runtime-and-recover-startup.md)

## Implementation and verification — completed 2026-10-14

- [Fixed workload C and full operating evidence](../../../../docs/mapping-startup-performance.md)
  records the local generation, initial/final read-only workload summaries,
  process/frame clocks, individual phases/totals, native sample, and remaining
  boundaries. Item 02/05 gates were checked before optimization.
- Local baseline **102,705.318 / 108,727.420 ms**; final built-app ARM64 macOS
  release **3,985.827 / 3,690.190 ms**, process-cold/repeated respectively.
  Maximum **3,985.827 ms** meets **5,000 ms**, including clock uncertainty,
  existing successfully loaded local data/settings and qualifying raster frame.
  No failed required dependency was reported. Settings navigation and Dashboard
  return were visually verified while unrelated graph validation remained pending.
- The operator's data changed since Item 02: **198 tracks / 132 bagged
  associations / 80 routes**. Workload C was fixed before optimization, then
  compared equal after verification for all counts/geometry/migration/settings/
  graph/dataset fields. Historical A/B measurements are not used as equivalent
  optimization comparisons; no personal records were removed or exported.
- ObjectBox native coverage/generation filtering avoids whole-table Dart
  materialization. Legacy-row removal and complete stored-graph validation run in
  attached-store worker transactions; queries/stores close on completion/error.
  Manifest identity recheck rejects superseded results. Failed async reads publish
  failed readiness; disposed coordinators ignore late publication. No Mapping
  payload/cache integrity check, declared DEM or source schema was bypassed.
- Five behavior-first red/green tests observed missing API, synchronous/premature
  bootstrap completion, missing failure publication, disposed notifier access,
  and stale generation acceptance before their passing fixes. Existing deterministic
  provider/widget/robot readiness, content/settings, off-screen, failure, platform,
  retry/quit, navigation and native retention/I/O regressions remain green.
- Focused 13-file run **120 passed**; final repository/coordinator run **16 passed**.
  `flutter analyze --no-pub`: **no issues**. Full
  `caffeinate -i flutter test --no-pub --reporter expanded`: **2,264 passed,
  5 existing skips, 11m55s**. Release builds succeeded; final build has workload
  summary disabled. Raw logs/screenshots/private configuration remain local.
- ADS-1.0/Desktop wide apply. No layout dimension decision, foundation replacement
  or shared-rule exception is introduced. Existing user theme/order/presentation
  remain the frozen benchmark rather than being altered to simplify it.
- The startup ceiling is delivered for the recorded workload; this does not claim
  zero startup jank (unchanged local loading has sub-2-second heartbeat gaps), fast
  completion of large background graph validation, route-point ceilings, or
  commissioning faults. Item 10 owns route recovery; Item 11 owns remaining live
  offline/disconnect/login/handover operating evidence.

### Journey Verification
- Journey: Dashboard loads current content and saved order; Settings navigation accepts input during background graph validation
- Verification command(s): `flutter test --no-pub test/robot/dashboard/dashboard_journey_test.dart test/widget/dashboard_readiness_test.dart`; live built-app LaunchServices runs under Item 02's protocol
- Required seams/selectors: deterministic repository/preferences/basemap loaders and existing dashboard keys; native window-specific live capture retained locally
- Result: `pass`
- Remaining risk: Engine raster finish is not an exact WindowServer scanout timestamp. Two fixed launches meet the startup ceiling; OS/thermal conditions are not universally controlled, and background graph/route performance is not covered by this ceiling.
