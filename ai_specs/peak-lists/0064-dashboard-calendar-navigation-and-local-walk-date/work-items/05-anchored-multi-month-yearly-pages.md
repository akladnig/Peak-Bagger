---
type: Work Item
title: Browse anchored multi-month and yearly pages
parent: ../spec.md
---

## What to build

Extend item 4's shared state/service/UI flow to complete 3-/6-/12-month pages, clipped Monday-based weekly aggregation, Year to Date, and All Time. Deliver exact summaries, tooltips, eligibility/bounds and tests through all three adapters and both chart modes, retaining the same four-button one-row toolbar.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS-only/maximised, Riverpod state ownership, semantic theme and accessible desktop controls).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 3–4, 6–10, 12–16, and 19–21; Technical Decisions 1–7; Testing Strategy 1, 3–6, and 8. Read sibling `interview-ledger.md`, especially L4–L7/L10, and `GLOSSARY.md`.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/work-items/04-week-month-calendar-navigation.md` and its page controller, routed reference clock and shared toolbar; retain its conditional supported-dimension gate for dependent layout work.
- `lib/services/summary_card_service.dart`, `lib/services/elevation_summary_service.dart`, `lib/services/peaks_bagged_summary_service.dart`, `lib/services/year_to_date_summary_service.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/core/date_formatters.dart`, and the three metric adapters.
- Existing `summary_card_service_test.dart`, `elevation_summary_service_test.dart`, `peaks_bagged_summary_service_test.dart`, and `year_to_date_summary_service_test.dart` under `test/services/`; the card/tooltip/Dashboard tests under `test/widget/`; item 4's `test/providers/summary_page_controller_test.dart`.
- Old fixed 13/26 weekly viewport counts, trailing ranges, and half-window shifts are superseded evidence, not the accepted calendar-page contract. Preserve the existing metric/first-climb model and palette.

## Acceptance criteria

- [x] Implement the following uniformly for Peaks Bagged, Elevation, and Distance in both line and column modes. Preserve preset labels/order `Week`, `Month`, `Last 3 Months`, `Last 6 Months`, `Last 12 Months`, `Year to Date`, `All Time` and the default `Last 12 Months`.
- [x] Initial default `Last 12 Months` and every different preset open their current-period page, even when latest activity is older. Last 3/6/12 Months include the current month and preceding 2/5/11 complete months; their page sequence remains anchored to the current month, independent of navigation.
- [x] `Last 3 Months` uses three complete calendar months with Monday-based weekly buckets and steps three calendar months; `Last 6 Months` uses six complete months with those weekly buckets and steps six months; `Last 12 Months` uses twelve complete months with monthly buckets and steps twelve months. Use calendar arithmetic/end-exclusive boundaries, not fixed elapsed-day durations.
- [x] In October 2026, 3-month pages are August–October, May–July, February–April, and so on. With latest activity in June, last opens May–July, not April–June. first/last and clamping use this established sequence; apply equivalent alignment to 6-/12-month and All Time pages without inventing differently aligned edge pages.
- [x] All weekly grouping is Monday–Sunday, clipped to the page's calendar months. For August–October 2026, the week beginning Monday 27 July includes only 1–2 August. Its hover range is the actually included days; July contributes nothing to that page, and a recorded day is neither dropped nor counted in two adjacent pages.
- [x] Build however many weekly buckets the calendar requires rather than exactly 13/26. Primary/secondary boundaries are identical, and no secondary-series activity is required to retain a qualifying primary page. Preserve primary eligibility and metric/peak-count/new-peak/first-climb definitions, units, rounding, and palettes.
- [x] Selected page, chart, visible range through the final included day, total and average agree. Retain exact average labels `Monthly Avg:` for Last 3/6/12 Months and Year to Date, `Annual Avg:` for All Time, and Week `Daily Avg:` / Month `Weekly Avg:` from item 4. Count zero-valued included buckets/periods consistently; a clipped preceding-month Monday cannot add a fourth/seventh month to 3-/6-month averages.
- [x] `Year to Date` remains the existing current-year monthly view, excludes records after the reference date, and retains its elapsed-month average. All four controls are disabled and do not select historical years. Its disabled arrow descriptions identify previous/next actions without promising historical-year navigation.
- [x] `All Time` uses yearly buckets with up to twelve visible years per current-year-anchored page; Previous/Next step twelve calendar years within earliest-history/current-year bounds. first/last locate earliest/latest qualifying records in that sequence; the oldest page may include fewer than twelve recorded-history years. Preserve alignment when clamping.
- [x] Retain first → prev → next → last, `Icons.first_page` / existing chevrons / `Icons.last_page`, lowercase `first` / `last` accessible names/tooltips, and these exact enabled-arrow tooltips:

  | Preset | Prev tooltip | Next tooltip |
  | --- | --- | --- |
  | `Week` | `Previous Week` | `Next Week` |
  | `Month` | `Previous Month` | `Next Month` |
  | `Last 3 Months` | `Previous 3 Months` | `Next 3 Months` |
  | `Last 6 Months` | `Previous 6 Months` | `Next 6 Months` |
  | `Last 12 Months` | `Previous 12 Months` | `Next 12 Months` |
  | `All Time` | `Previous 12 Years` | `Next 12 Years` |

- [x] Navigation visits consecutive pages including zero-data gaps without wrapping/skipping. Bound backwards at earliest primary-qualifying record page and forwards at current period/year. Disable controls by destination: an older latest-record page can disable last while retaining Next toward today; a one-historical-page dataset must not disable that forward range. Year to Date always disables all four.
- [x] Exclude Track days after the Mac-local reference day for every preset and both series, including endpoint selection, using canonical/legacy decoding from item 2. Future positions in complete pages remain zero buckets, and Year to Date retains its elapsed-month meaning. Future-only data uses the existing no-qualifying-data state; the cutoff is not import validation or data repair.
- [x] Preserve `No elevation data yet`, `No distance data yet`, `No peaks bagged yet`, and unaffected `No walks yet`; loading does not flash no-data. Zero-valued pages inside qualifying history remain browsable. Preserve Dashboard routes/readiness/failure reporting, no-network behavior, and absence of persisted summary/navigation state.
- [x] Keep one-row toolbar, card geometry/reordering, text scaling and accessible keyboard/pointer/focus/disabled styling from item 4; do not introduce wrapping or numerical window targets. Verify light/dark and enlarged text at representative existing card constraints. If new layout work actually depends on Pending supported dimensions, retain item 4's decision gate rather than inferring a minimum.
- [x] Add service/widget/provider regressions for complete 3-/6-/12-month steps, October 2026/latest-June alignment, clipped 27 July edge-week hover in both modes, zero periods/averages, aligned series, All Time twelve-year steps/shorter oldest page, current-period entry/default, Year to Date exclusion/navigation/average, future-only/future-within-page/beyond-page fixtures, and all exact toolbar tooltips/states. Use deterministic dates and independently known Hobart offsets across both DST transitions. No additional strict TDD mandate is added.

### Verification

Run from the project root, using item 4's provider/clock fixtures and safe repository/mapping/tile overrides. Dispose containers/controllers; tests use no production data, external service, live tiles, or credentials.

```sh
TZ=Australia/Hobart flutter test \
  test/services/summary_card_service_test.dart \
  test/services/elevation_summary_service_test.dart \
  test/services/peaks_bagged_summary_service_test.dart \
  test/services/year_to_date_summary_service_test.dart \
  test/providers/summary_page_controller_test.dart \
  test/widget/elevation_card_test.dart \
  test/widget/distance_card_test.dart \
  test/widget/peaks_bagged_card_test.dart \
  test/widget/summary_chart_tooltip_test.dart \
  test/widget/dashboard_screen_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

Also run the parent Spec's exact Testing Strategy 8 focused block. Record actual macOS wide-layout toolbar checks and any genuinely dimension-dependent verification gate; fixture sizes are not new supported-minimum contracts.

### Completion evidence — 2026-10-17

- Extended `SummaryCardService.calendarPage` / `pageNavigation` to all presets. Current-month/current-year anchors determine complete pages, endpoint jumps and clamping; 3-/6-/12-month adjacency uses calendar-month steps. All Time uses twelve-year steps and trims only the oldest page's pre-history years. Year to Date always selects the current year and disables all four controls.
- All three metric adapters now render through the same Riverpod-selected calendar-page path. Removed the superseded pixel-window caches, half-window shifting and fixed 13/26-bucket viewport sizing. Each page determines chart boundaries, range through its final day, totals, averages and button availability; secondary activity is not required. Existing metric eligibility, peak first-climb definitions, units/rounding, palettes, routes and persistence boundaries remain intact.
- Weekly buckets end at the next Monday, clipping both page edges. August–October 2026 has 14 buckets, starting with 1–2 August; the adjacent May–July page ends with 27–31 July. Hover titles use the shared range formatter in both modes. Monthly averages count included calendar months; the twelve-month default includes zero-valued months, and Year to Date retains its elapsed-month denominator. Updated historical tests that encoded trailing windows, half-window movement or recorded-month-only default averages.
- Added service/provider/shared-card regressions for all remaining presets and all three adapters in both modes: October/latest-June alignment, complete steps/clamping, consecutive empty pages, primary-only eligibility/repeated peaks, identical secondary boundaries, current/default entry, mode preservation, exact tooltips/states, shorter All Time oldest page, Year to Date fixed navigation/average, and future dates within/beyond pages plus future-only states. Canonical Track dates remain component-preserving. Both Hobart DST transitions assert independently known `+11 → +10` / `+10 → +11` offsets and verify every included day is counted once across daily, weekly and monthly buckets.
- Final `flutter analyze`: **no issues**. Work Item focused block plus `test/widget/summary_calendar_navigation_test.dart`: **146 passed**. Parent Testing Strategy 8's exact nine-file focused block: **101 passed**, including the routed elevation journey. Final `TZ=Australia/Hobart flutter test --reporter expanded`: **2,417 passed, 5 skipped**. This includes date derivation/import/migration and existing Dashboard journeys/readiness/navigation. An initial full-suite attempt was interrupted by the shell's 120-second timeout; the complete rerun with a sufficient timeout passed. Final normal-entry `flutter build macos --debug`: **passed**; the existing ObjectBox Swift Package Manager warning is non-fatal.
- Actual macOS verification used a temporary fake-data entry point rendering the real Dashboard with mock preferences, in-memory repositories, fixed reference clock and no usable Latest Walk geometry/live tiles. At the observed maximised **1710 × 1073** native window, inspected light/dark and 1×/1.5× text. The three timeline toolbars remained one row. Tab exposed visible focus on first; Enter opened February–April 1989 with `700 m` total / `233 m` monthly average; Tab/Enter on Next opened May–July 1989 with matching zero chart/total/average. Card selections remained independent. Temporary preview was stopped and removed, and the normal entry point rebuilt. Window-only screenshots in the session temporary directory: `spec0064-item05-light.png`, `spec0064-item05-focus.png`, `spec0064-item05-dark-enlarged-first.png`, `spec0064-item05-light-enlarged-gap.png`.
- Authority review: the parent Spec supersedes historical trailing/half-window behavior. No intentional shared-rule exception or foundation replacement is proposed. Existing Dashboard card-title ellipsis at enlarged text remains the item 4 alignment gap; toolbar controls and period text remain accessible. These observations and regression fixture sizes do not establish supported minimum dimensions.

### Journey verification

- Journey: existing routed Dashboard elevation navigation/inspection/mode/clock journey and the existing Dashboard journeys exercised by the full suite.
- Commands: the exact parent Testing Strategy 8 focused block and full Hobart suite above.
- Result: **pass**. Existing deterministic clock/provider/repository/mapping seams and card-scoped selectors retained; no journey expansion was required for this slice.
- Remaining scope: item 6 completes direct horizontal page settling and adversarial refresh/rollover/movement reconciliation. This completion does not claim those later contracts.

## Covers

- User Stories: 3–4; 5 (partial-week inspection/synchronized summaries).
- Requirements: 3–4; 6–10; 12–16; 19–21 (remaining presets and shared invariants); preserve 18's toolbar constraint from item 4.
- Technical Decisions: 1–4; 6–7.
- Testing Strategy: 1; 3–6; 8.
- Interview Ledger: L1; L4–L7; L10; preserve L9's one-row constraint.
- Approved refinement decisions: current-period/default entry and future-date cutoff in Spec Notes; R4; respect item 2's R1/R5 date decoding.

## Blocked by

- [04-week-month-calendar-navigation.md](04-week-month-calendar-navigation.md)

## Blocking decisions

- Retain item 4's conditional gate for **Pending — minimum usable macOS width**, **Pending — minimum usable macOS height**, **Pending — supported macOS resize range**, and **Pending — feature-specific wide-layout thresholds**. Calendar/page logic, existing-card regressions and observed native wide-window checks are complete. Verification across an approved minimum/resize range remains gated until those values are resolved in the profile/Spec; no numerical target or wrapping-toolbar redesign is inferred.
