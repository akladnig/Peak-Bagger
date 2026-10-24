---
type: Work Item
title: Add Time's three chart views and chart-type menu
parent: ../spec.md
---

## What to build

Extend the integrated Time card with its three chart presentations and exact chart-type menu, from selected-type state through opt-in shared rendering and pointer/widget verification. Retain the selected calendar preset/page and Time-only scope. Work Item 03 adds persistence; Work Items 04–05 complete card-scoped keyboard/menu/inspection behavior. Expose coherent interfaces for those slices rather than adding a competing state owner.

Apply ADS-1.0 and Desktop wide/macOS-only obligations, semantic light/dark colours, compact pointer/keyboard controls, accessible labels/selected states, respected text scale, and mandatory ObjectBox/Riverpod/GoRouter boundaries. Keep the existing grid/card geometry, one-row toolbar, and global window policy.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/01-time-card-calendar-and-summaries.md` and its implementation.
- `ai_specs/peak-lists/0003-dashboard-chart-series-theme/spec.md`, `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`, `ai_specs/peak-lists/0065-dashboard-weekly-tooltip-and-year-navigation/spec.md`; 0065 has precedence for Year to Date/tooltip changes.
- `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_page_browser.dart`, `lib/providers/summary_page_controller.dart`, and the Time adapter/formatter introduced by Work Item 01.
- `lib/widgets/dashboard/distance_card.dart`, `lib/widgets/dashboard/elevation_card.dart`, `lib/widgets/dashboard/peaks_bagged_card.dart`, `lib/theme.dart`, `lib/screens/dashboard_screen.dart`: preserve non-opted-in adapter and header behavior.
- `test/widget/summary_chart_tooltip_test.dart`, `test/widget/summary_calendar_navigation_test.dart`, `test/widget/summary_card_navigation_test.dart`, existing card tests, and Time tests introduced by Work Item 01.
- `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`: selectors and deterministic routed harness conventions.

## Acceptance criteria

- [x] Time's chart-type menu has exactly this order, labels, and icons, with a visible and accessible current-choice indication:

  | Label | Icon |
  | --- | --- |
  | `Stacked column view` | `Icons.stacked_bar_chart` |
  | `Line view` | `Icons.show_chart` |
  | `Clustered column view` | `Icons.bar_chart` |

- [x] The button shows the current type's icon and exact tooltip/accessibility label `Chart type`. Activating it opens a menu rather than cycling; selection closes the menu and preserves preset/page, current-choice selection is a no-op, and Escape/outside click dismiss without changing type. Do not label the stacked choice `Switch to column view`. Preserve pointer operation and keep the toolbar on one row. Keyboard-opened menu closure returns to the owning card under Work Item 04, with inspection preservation/clearing under 05 rather than unconditional reinitialization.
- [x] Use an explicit Time opt-in for subset stacking and menu/type capabilities. Retain Work Item 01's stacked geometry: green zero-to-moving, primary moving-to-total, five total/four moving reaches five not nine, equal totals omit primary remainder, and zero portions vanish naturally. Do not globally reverse the legacy renderer or rename the remainder as a tooltip series.
- [x] Line view shows full Total Time and Moving Time values on one duration axis with green visible when lines coincide. Clustered view shows Total Time first/left and Moving Time second/right on a common zero-based axis; five/four hours produces separate full-height five/four columns. Scaling uses both series and the true subset-stacked height; all-zero data remains renderable.
- [x] Every view uses `ChartSeriesTheme.primarySeriesColor`, currently derived from `colorScheme.primaryContainer`, for Total Time and `secondarySeriesColor`, currently `#2E7D32`, for Moving Time; never substitute raw seed/`colorScheme.primary`. Reuse shared selected and lightened-tooltip colour derivations across light/dark and changed-seed themes.
- [x] Every inspected bucket uses the reference date title and exactly two rows in order `Total Time: <duration>` and `Moving Time: <duration>`, preserving `xd yh zm` all-three-component formatting and decimal-day axes from Work Item 01. Preserve hover/pinned behavior for both series, including coincident and zero values. Clear incompatible inspection on type changes without changing the calendar page; Work Item 05 supplies keyboard equivalents/accessible inspected values.
- [x] All three types share the same eligible Track set, calendar boundaries, initial `Last 12 Months` current page, exact preset order, Total Time-only header/averages, horizontal browsing, First/Previous/Next/Last destinations, refresh clamping, current-page following and historical remapping, and activation/interaction clock reconciliation without a midnight timer. Superseded type/page/data callbacks cannot restore stale tooltips or selected pages.
- [x] Time's wrapping summary header and full labels/values remain intact at enlarged text; the toolbar stays one row. L23 resolves the inherited height policy with fixed card/grid geometry, a usable reserved plot and vertically scrollable Time content; no new window dimensions, compact breakpoints, routes or native-window policy are selected.
- [x] Distance/Elevation/Peaks Bagged retain their existing binary controls, exact labels, initial mode defaults, eligibility, chart/header presentation, palettes, and chart preferences. No new chart-type menu, subset stacking, clustered choice, wrapping header, or chart-preference migration appears on those cards. No combined card-actions menu is introduced.
- [x] Add behavior-focused widget/rendering coverage for exact menu order/icons/labels/current marker, `Chart type`, pointer/Escape/outside dismissal, same-choice no-op, page preservation, subset/equal/zero geometry, coincident lines, independent clustered values, colours in light/dark and changed-seed themes, exact tooltip rows, loading/empty states, and stale-inspection clearing. Reuse deterministic Tracks/clocks/provider overrides and stable menu/item selectors; scope duplicated control keys to the card, retain `time-...` selectors and existing robot selectors/journeys, fake tiles when needed, and dispose resources. No strict TDD or new robot journey is mandated.
- [x] Run `flutter analyze`, affected Time/summary/Dashboard widget tests under `TZ=Australia/Hobart`, and the complete `TZ=Australia/Hobart flutter test` suite; check affected macOS-wide light/dark pointer/available keyboard behavior, focus and enlarged text without downscaling. Report actual results and any dependent dimension gate. Later 04–05 keyboard criteria remain required for feature completion.

## Covers

- User Stories: 2.
- Requirements: 11, 14–22 (menu pointer/rendering portion; keyboard completion in 04–05).
- Technical Decisions: 1–3, 5–6, 8–10, 13 (scope boundaries).
- Testing Strategy: 1, 3–4 (chart/menu portion), 7–9.
- Interview Ledger: L1, L3–L7. L18 remains deferred; no discovery footer, accessible-only shortcut explanations, shortcut editor, or Help screen is added.

## Blocked by

- Uses the implemented independent data/calendar/formatter/chart foundation from [01 — Add Time's eligible-duration chart and calendar summaries](01-time-card-calendar-and-summaries.md). On 2026-10-18 the user explicitly authorised independent Work Item 02 work while carrying forward Work Item 01's unresolved layout gate (Interview Ledger L20).
- L19's product decision was resolved by L23 on 2026-10-24: retain card/grid
  geometry, reserve usable chart space and scroll overflowing Time content. The
  remaining layout criterion requires executed verification, not another window
  decision. Earlier progress entries below retain their historical scope.

## Implementation progress — 2026-10-18

**Current status — completed 2026-10-24 under L23.** The inherited wrapping-header
criterion now passes for all three chart types with retained geometry and scrollable
overflow. Full suite: **2,887 passed, five existing skips**; native/input/analysis
evidence is in [the layout delivery record](../implementation-layout-verification.md).
The following partial-delivery entry remains dated history.

**Independent chart/menu scope implemented and verified under L20. Full Work Item completion remains conditional on the unchecked inherited wrapping-header layout criterion.** Work Item 01 remains incomplete under L19; no dimensions or layout policy were selected here.

### Implemented

- Added app-owned `timeChartTypeProvider` as the single selected-type owner. `TimeCard` projects it to explicitly opted-in shared display-mode, bar-style and menu-control inputs. Work Item 03 can extend this owner with preference state instead of introducing another mutable selection.
- Added the exact three-choice `TimeChartTypeMenu`, current icon, `Chart type` tooltip/accessible label, check marker and selected semantics. Selection closes the menu; unchanged selection and dismissal preserve inspection/page state. Selected-item autofocus enables Escape after pointer opening and native arrow/Enter operation. The invoking control's focus node is disposed by the menu; owning-card focus/dropdown shortcuts remain Work Item 04 work.
- Reused existing subset, line and grouped renderers with unchanged theme-derived colours and full-duration tooltip meanings. The secondary line paints last at coincident values; clustered rods retain primary-left/secondary-right order and independent heights.
- Type changes synchronously invalidate pending browsing/inspection before the provider-driven frame. Captured pointer callbacks reject superseded inspection identities, and deferred Material menu callbacks check mounting before accessing widget/provider state.
- Extended the existing calendar/navigation fixture loops to all three Time views using `test/harness/summary_chart_controls.dart`. Existing binary controls and robot selectors are retained. Focused tests cover exact menu semantics/dismissal/no-op, theme palettes, equal/zero/subset/clustered geometry, coincident lines, hover/pin rows, stale callbacks, loading/empty transitions, and disposal.

### Executed verification

- `flutter analyze` — **passed, no issues**.
- `env TZ=Australia/Hobart flutter test test/services/time_summary_metrics_test.dart test/providers/summary_page_controller_test.dart test/widget/time_card_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_card_navigation_test.dart test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart test/widget/dashboard_screen_test.dart test/widget/dashboard_readiness_test.dart test/robot/dashboard/dashboard_journey_test.dart --reporter expanded` — **244 passed, 2 gated skips**.
- `caffeinate -i env TZ=Australia/Hobart flutter test --reporter expanded` — **2,564 passed, 7 skipped**, approximately **9 minutes 30 seconds**. Two skips retain the inherited header-layout gate; five pre-existed this work.
- macOS-platform widget checks passed in light/dark themes at **1.5× text scale** with one-row toolbar alignment, pointer selection, visible control focus, native Enter/arrow selection and Escape dismissal. Light/dark/changed-seed rendering and selected/lightened-tooltip colours are covered. No separate live native-app visual inspection was performed; representative widget fixtures are not approved window minima.
- Initial checks exposed a pointer-opened-menu Escape focus gap, semantics merge-node assertion issues, and an incorrect synthetic pointer re-entry assumption in the new pin test. These were corrected before the passing focused/full runs. The L19 wrapping-header plot-height failure remains gated rather than reported as fixed.
- Work Item 03 persistence and Work Items 04–05 card-scoped keyboard/menu/inspection behavior remain required feature work.
- **Commit scope:** after verification, the user explicitly selected `Commit prerequisites and 02` because the new slice overlaps uncommitted 0065/Work Item 01 source and tests. Include those reviewed foundations and their feature planning/progress documents with this slice; retain the incomplete layout status and exclude the unrelated `macos/Podfile.lock` change.
