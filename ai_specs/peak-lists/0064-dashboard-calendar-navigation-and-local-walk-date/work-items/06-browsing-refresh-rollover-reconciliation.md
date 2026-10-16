---
type: Work Item
title: Unify horizontal browsing, refresh, and calendar-rollover reconciliation
parent: ../spec.md
---

## What to build

Complete the shared interaction flow across service/state/chart/header boundaries: snapped direct horizontal movement, mode/page preservation, data refresh/clamping, event-driven reference-date reconciliation, and cancellation of superseded work. Include deterministic interrupted-interaction widget tests and routed robot journeys in this slice rather than a separate harness Work Item.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS-only/maximised, Riverpod ownership, GoRouter boundaries, keyboard/pointer/focus and resource disposal).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 17 and 20–23 plus retained page/toolbar/state contracts; Technical Decisions 3–7; Testing Strategy 3–5 and 7–9. Read sibling `interview-ledger.md`, especially L6/L8/L10, and `GLOSSARY.md`.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/work-items/05-anchored-multi-month-yearly-pages.md` and the shared state/reference-clock infrastructure from item 4. Item 2's canonical/legacy decoder remains the Track-day authority.
- `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/screens/dashboard_screen.dart`, `lib/services/summary_card_service.dart`, `lib/router.dart`, `lib/providers/map_provider.dart`, and `lib/providers/dashboard_readiness_provider.dart` for scroll/animation/callback ownership, inspection, refresh, activation, and summaries.
- `test/widget/summary_chart_tooltip_test.dart`, the three card tests, `test/widget/dashboard_screen_test.dart`, `test/widget/dashboard_readiness_test.dart`, and item 4's `test/providers/summary_page_controller_test.dart` for controlled-frame regressions. Existing modified chart/tooltip files are user work to reconcile, not replace wholesale.
- `test/robot/dashboard/elevation_journey_test.dart`, `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`, `test/harness/test_map_notifier.dart`, `test/harness/test_tasmap_repository.dart`, and `test/harness/mapping_catalog_fixture.dart` for routed safe-data/provider conventions.
- `lib/widgets/dashboard/latest_walk_card.dart` exposes `latestWalkTileProviderFactoryProvider`; override it whenever journey rendering would otherwise access tiles.

## Acceptance criteria

- [x] Across Peaks Bagged, Elevation and Distance, both chart modes and every preset, horizontal scrolling/trackpad panning settles on the same complete pages and earliest/current bounds as buttons. No resting half-week/half-month viewport remains, and chart, date range, total and average agree after settling. Year to Date remains its fixed current-year page with all four controls disabled.
- [x] Preserve all established period contracts, first/last endpoints, consecutive empty pages, primary-metric eligibility, shared primary/secondary boundaries, exact tooltips, preset order/default, one-row toolbar, metric text/rounding/palettes, and loading/empty states from items 4–5. Do not introduce navigation persistence, summaries stored in the database, new routes/network requests/credentials, or new window/compact/full-screen policies.
- [x] Line/column switches preserve the selected page, subject only to the same calendar-rollover reconciliation as other interactions. Retain each card's independent browsing state and one authoritative selected-page identity rather than treating pixel offset or a sticky first/last flag as authoritative.
- [x] On Track refresh, keep the displayed calendar page when still permitted and recompute chart/range/total/average, earliest/latest destinations and button states. Removing history that places the selection before the new earliest permitted page clamps it to that earliest page; no qualifying records yields the existing empty-dataset state. Loading never briefly becomes no-data.
- [x] first/last are one-off jumps: adding earlier/later records updates destinations but never automatically moves a page selected by an earlier first/last action. Clear/reconcile inspection and cached bucket/header values so no old-data tooltip or superseded summary appears on the refreshed page. Preserve allowed legacy/skipped decoding and canonical corrected days during refreshed-data consumption.
- [x] Reconcile the Mac-local reference date on next Dashboard activation, data refresh, or timeline interaction; no background midnight timer is required. Wire activation through the actual routed Dashboard/GoRouter shell as well as focused `now` seams, including a Dashboard retained offstage and revisited.
- [x] If reference advancement changes the sequence, a card previously showing current follows the new current page. A historical card selects the newly aligned page containing its previous page's last included calendar day, then respects refreshed history bounds. In November, October's current August–October 2026 3-month page becomes September–November; historical May–July becomes June–August because it contains 31 July. Week/Month history remains its same period while permitted; All Time applies equivalent current-year anchoring at year rollover.
- [x] A different preset always opens its current-period page. Reference-day changes update future-date eligibility even when sequence alignment does not change, allowing previously excluded days once they arrive without changing stored Tracks. Reconcile selection, range, chart, summaries, endpoints, controls and inspection together.
- [x] Rapid successive requests settle at the final requested valid page. Newer navigation, preset changes, refreshes or calendar rollover invalidate incompatible movement, animation completions, post-frame summary callbacks, and stale inspection updates; superseded callbacks cannot restore an earlier page/header. Give controllers/listeners/animations/scheduled work explicit owners and clean disposal; removing the card during pending movement causes no post-disposal update or exception.
- [x] Add deterministic overlapping-action tests: issue repeated navigation before earlier animation completion, change preset mid-movement, refresh values/remove history mid-movement, and advance the clock across rollover mid-movement. Pump controlled intermediate frames and advance beyond obsolete completion callbacks; do not `pumpAndSettle` after each input and thereby serialize away races. Assert final chart/range/total/average, endpoint destinations/availability, hover/pinned state and stale-tooltip absence.
- [x] Expand the existing routed elevation robot journey for full-history first/prev/next/last, a snapped horizontal move, synchronized summaries, mode switch, and clock advancement through current/historical rollover. Replace `DateTime.now()`-dependent fixture/expected-page logic with fixed, advanceable overrides of the actual routed Dashboard reference clock.
- [x] Scope control finders/keys to their containing card. Preserve `summary-prev-window`, `summary-next-window`, `summary-period-dropdown`, and `summary-mode-fab`; use stable equivalent first/last selectors consistently (for example `summary-first-window` / `summary-last-window`). Preserve existing Dashboard/card/map selectors and navigation semantics.
- [x] Preserve existing Dashboard journeys and dependency/readiness failure reporting. Use mapping/catalog, repository, preference and Riverpod overrides, deterministic Track fixtures, fake tiles via `latestWalkTileProviderFactoryProvider`, and no external services, API keys, live tiles or user database. Dispose containers/controllers/subscriptions/gestures and temporary data.
- [x] Keep macOS pointer/keyboard activation, visible focus, accessible descriptions, disabled default cursor/feedback, semantic light/dark styling, text scaling and card reordering intact. Exercise the retained single-row toolbar under representative existing constraints and actual macOS wide-layout checks; report/gate only verification that depends on unresolved supported dimensions from item 4, without wrapping or reducing text scale.
- [x] Use behavior-first regressions and update superseded half-window/trailing-window/offset-preservation expectations. No additional strict one-test-at-a-time TDD mandate is added, and the existing research probe is not completion evidence for these app interactions.

### Verification

Add `test/widget/summary_card_navigation_test.dart` for shared-card race/refresh/disposal behavior and extend item 4's controller tests, existing Dashboard/widget tests, `test/robot/dashboard/elevation_journey_test.dart` and `dashboard_robot.dart`. Exercise all three adapters and both modes in focused tests, not only the elevation journey. Assert actual expected Hobart offsets and independently known reference/calendar outcomes.

Run the parent Spec's exact focused command, followed by the additional shared-state/widget/Dashboard regressions, analysis and full timezone-configured suite:

```sh
TZ=Australia/Hobart flutter test \
  test/services/latest_walk_summary_test.dart \
  test/services/summary_card_service_test.dart \
  test/services/elevation_summary_service_test.dart \
  test/widget/latest_walk_card_test.dart \
  test/widget/elevation_card_test.dart \
  test/widget/distance_card_test.dart \
  test/widget/peaks_bagged_card_test.dart \
  test/widget/summary_chart_tooltip_test.dart \
  test/robot/dashboard/elevation_journey_test.dart
TZ=Australia/Hobart flutter test \
  test/providers/summary_page_controller_test.dart \
  test/widget/summary_card_navigation_test.dart \
  test/widget/dashboard_screen_test.dart \
  test/widget/dashboard_readiness_test.dart \
  test/robot/dashboard/dashboard_journey_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

Complete the parent Spec's applicable date-derivation/import/migration regressions as well; their cross-host Hobart/UTC commands and same-database reopen tests remain in items 2–3 and are not replaced by the navigation journey. Record actual macOS wide-layout/trackpad/keyboard behavior as implementation verification and any conditional dimension-dependent gate explicitly.

### Completion evidence — 2026-10-17

- `SummaryPageController` owns selection, its previous reference day and the page's end-exclusive boundary. Pure projections render refreshed/reconciled pages immediately; guarded post-frame commits retain clamps in the authoritative state. Current-page following is derived from the previous calendar page, not a sticky first/last action. Historical remapping uses its last included day, including All Time at year rollover. Navigation resolves against current inputs at dispatch, including repeated requests before a rebuild.
- `SummaryPageBrowser` owns only transient horizontal input: pixel-scroll bursts settle after 100 ms and drag/trackpad pan completion commits whole bounded pages. It cancels accumulated input on page/preset/data/reference/activation changes and disposal. Selection is immediate; no page-selection animation completion can restore an earlier page. Existing chart-value animations remain presentation only. A synchronous revision guard also rejects timers that run after a toolbar action but before its queued rebuild; the overlapping preset regression exposed and verified this race.
- The shared chart clears obsolete inspection on refresh, page or reference changes. Summary callbacks carry invalidation revisions; null loading/empty summaries also clear obsolete header metrics. Opening a preset menu, changing mode, navigating and inspecting reconcile the live clock. The routed cards read the injectable clock themselves, rather than receiving a stale parent snapshot. Indexed-stack `TickerMode` activation and native app resume rebuild the Dashboard; the resume observer is removed on disposal.
- Added `test/widget/summary_card_navigation_test.dart`: **31 tests** covering all three actual adapters and both modes, every preset's direct-scroll/pan bounds, synchronized chart/range/total/average, rapid input, preset interruption, refresh/value changes, committed removal clamps, one-off jumps, loading/empty transitions, canonical/skipped decoding, future-day eligibility, current/historical rollover, hover/pinned invalidation and removal during both scroll timers and active drags. Inputs overlap using controlled frames, with time advanced beyond obsolete callbacks rather than settling between every request. Six additional controller tests cover current/historical remapping across every navigable preset and rejection of obsolete reconciliation commits.
- Parent Spec's exact nine-file focused block: **101 passed**. Work Item's additional five-file block plus retained `summary_calendar_navigation_test.dart`: **118 passed**, including existing Dashboard journeys, readiness/failure reporting, reordering, focus, semantic light/dark controls and 1.5× toolbar fixtures.
- Date derivation/codec/persistence/cross-host reopen/import/warning/migration/provider/status regression files from items 2–3 were run together: **40 passed under Hobart and 40 under UTC**. This includes the same-database opposite-timezone process/reopen test and independent host-offset assertions. Existing import/repository/provider/consumer regressions also passed in the full suite.
- Final `flutter analyze`: **no issues**. Final full suite: **2,454 passed, 5 pre-existing skips**, using `TZ=Australia/Hobart caffeinate -i flutter test --reporter expanded` (the same required timezone-configured suite, with idle-sleep prevention). A preceding run hit the shell's ten-minute timeout; it is not completion evidence. The successful rerun used a thirty-minute limit and completed in approximately twelve minutes. Final normal-entry `flutter build macos --debug`: **passed**, with the existing non-fatal ObjectBox Swift Package Manager warning.
- Actual macOS verification used a temporary fake-data entry point rendering the real Dashboard, mock preferences, in-memory repositories, fixed/advanceable dates and no user database/live tiles. At the observed maximised **1710 × 1073** window, inspected light/dark and 1×/1.5× text. Native horizontal pixel-scroll input changed Elevation from October to the complete zero-valued September page, with zero total/average; the other cards stayed in October. Tab visibly focused first; Enter opened February 1989 with `700 m` total and `140 m` weekly average. Advancing October to November retained that historical page while current Distance/Peaks Bagged followed November with matching zero summaries. All three toolbars retained one row. Trackpad pan/zoom event recognition is covered deterministically in widget tests; the native session used synthesized OS pointer/scroll and keyboard events rather than a physical trackpad operator.
- Native window-only screenshots in the session temporary directory: `spec0064-item06-light.png`, `spec0064-item06-dark-enlarged.png`, `spec0064-item06-scroll.png`, `spec0064-item06-focus.png`, `spec0064-item06-first.png`, and `spec0064-item06-rollover-light-enlarged.png`. The temporary preview was stopped/deleted and the normal entry point rebuilt.
- Authority review: the parent Spec's complete-page contract supersedes historical half-window/trailing-window behavior. No intentional shared-rule exception or foundation replacement is proposed. Existing enlarged Dashboard card-title ellipsis remains the item 4 alignment gap; the toolbar controls and period text remain accessible at the inspected constraints.

### Journey Verification

- Journey: Routed Dashboard elevation full-history browsing, direct horizontal snapping, inspection/mode changes, refresh and current/historical rollover after offstage reactivation.
- Verification command(s): `TZ=Australia/Hobart flutter test test/robot/dashboard/elevation_journey_test.dart`, also included in the exact parent focused block and successful full suite.
- Required seams/selectors: fixed advanceable `dashboardReferenceClockProvider`, `TestMapNotifier`, mapping/catalog/repository/preference overrides, `latestWalkTileProviderFactoryProvider` with `FixtureTileProvider`, card-scoped toolbar/browser/range/bucket selectors and existing header metric keys. `DashboardRobot` now exposes period, horizontal input, exact summary and Settings navigation actions.
- Result: `pass`.
- Remaining risk: the single established journey retains its inline fixture/container setup; robot actions and the tile fixture are separate. Physical trackpad hardware input was not manually exercised; pan/zoom recognition and native OS horizontal-scroll delivery were verified as described above. Supported minimum/resize-range verification remains conditionally gated below.

Summary: the expanded elevation journey and existing Dashboard journeys passed; no declared journey was skipped. Automated tests use controlled data/resources. The remaining layout gate and pre-existing title alignment gap are explicit.

## Covers

- User Stories: 2–5 (direct browsing, mode, refresh and rollover interaction).
- Requirements: 17; 20–23; preserve Requirements 3–16 and 18–19 while reconciling input/data/reference changes.
- Technical Decisions: 3–7; retain 1–2's profile and date-decoding boundaries.
- Testing Strategy: 3–5 (refresh/clock portions); 7–9.
- Interview Ledger: L6; L8; L10; preserve L1/L3–L5/L7/L9 contracts implemented by items 4–5.
- Approved refinement decisions: refresh preservation/clamping, one-off jumps, reference-date rollover and interrupted-navigation/inspection/disposal policies in Spec Notes; R4; consume R1/R5 dates consistently.

## Blocked by

- [05-anchored-multi-month-yearly-pages.md](05-anchored-multi-month-yearly-pages.md)

## Blocking decisions

- Retain item 4's conditional gate for **Pending — minimum usable macOS width**, **Pending — minimum usable macOS height**, **Pending — supported macOS resize range**, and **Pending — feature-specific wide-layout thresholds**. Independent interaction/state work, existing-card regression fixtures and observed native wide-window checks are complete. Verification across an approved minimum/resize range remains gated until the profile/Spec resolves those values; the observed native window is not a minimum contract.
