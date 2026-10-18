---
type: Work Item
title: Deliver full-order card traversal and timeline/menu keyboard actions
parent: ../spec.md
---

## What to build

Deliver the Dashboard-wide card focus/traversal slice with full-order lazy reveal, named visible focus, timeline actions, and temporary dropdown keyboard scope through UI, state/scroll coordination, and widget tests. Resolve targets by stable card ID against the entire displayed/stored order rather than only mounted focus nodes. Work Item 05 adds Time bucket inspection, 06 adds non-timeline/shell/Time Retry actions, and 07 adds keyboard reorder/save recovery; they complete the approved replacement access.

Apply ADS-1.0 and Desktop wide/macOS-only keyboard/pointer obligations with Riverpod application-state ownership and explicit transient focus/menu/controller lifecycle ownership. Technical Decision 11 records an intentional alignment gap: L16 confirms destination-only F6 and no keyboard entry for other shell actions/card-order Retry, but does not approve an ADS-1.0 exception or settle provisional L10 governance. Preserve that boundary while delivering the enumerated shortcuts.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/02-time-chart-views-and-menu.md` and its implementation.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`, `ai_specs/peak-lists/0065-dashboard-weekly-tooltip-and-year-navigation/spec.md`: current calendar actions and destinations, with 0065 precedence.
- `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/router.dart`: lazy grid, stable `dashboard-card-...` identity, stored/displayed order, shell boundaries and route activation.
- `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_page_browser.dart`, `lib/providers/summary_page_controller.dart`, `lib/widgets/dashboard/distance_card.dart`, `lib/widgets/dashboard/elevation_card.dart`, `lib/widgets/dashboard/peaks_bagged_card.dart`, and Time implementation: actual toolbar/page state and opt-in menu interfaces.
- `test/widget/dashboard_screen_test.dart`, `test/widget/summary_card_navigation_test.dart`, `test/widget/summary_calendar_navigation_test.dart`, `test/providers/dashboard_layout_provider_test.dart`, existing timeline-card tests.
- `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`: stable selectors, controlled clocks/provider overrides and fake tile conventions.

## Acceptance criteria

- [x] Normal Dashboard Tab/Shift+Tab traversal has one focus stop per card in the current displayed/stored order, including Time. Skip internal buttons, chart buckets, menu items and surrounding app navigation; preserve pointer operation of internal controls. Each focused card has a meaningful accessible name and visible focus distinct from hover, inspection and selection in light/dark themes.
- [x] Traverse the entire stored order, including off-screen cards not yet built by `GridView.builder`. Reveal each target, wait for construction, then focus it by stable ID; never skip an unmounted target. Tab from last wraps to first; Shift+Tab from first wraps to last. Retain correct target/order after pointer reordering; coordinate scrolling, construction and focus without stale requests or post-disposal callbacks.
- [x] With Time focused, W invokes toolbar Next page, B Previous page, P opens its existing Period dropdown, and C opens its existing Chart type dropdown. Use the same calendar steps, bounds, enabled states and reference-date reconciliation as pointer/trackpad controls; do not introduce a combined actions menu.
- [x] With Distance, Elevation or Peaks Bagged focused, W/B invoke its existing Next/Previous page, P opens Period and C directly activates its binary line/column toggle. Add no chart-type menu to these cards, and preserve independent page state, existing type defaults, labels, eligibility, palettes, header/chart presentation and chart preferences.
- [x] With any of the four timeline cards focused, Home invokes First and End Last with exactly that toolbar's own earliest/latest qualifying destinations, per-destination enabled state, bounds, one-off jump behavior and refresh/rollover reconciliation. Preserve `First`, `Last`, `Previous Year`, `Next Year` and other preset-specific names; keyboard actions must not create a separate calendar algorithm.
- [x] Dashboard dropdowns use Down/j for next item, Up/k for previous item, Enter to apply, Escape to dismiss without a new choice. Selection or Escape from a keyboard-opened menu restores owning-card focus. Preserve exact existing Period choices and Time's ordered `Stacked column view`/`Line view`/`Clustered column view`, icons and selected-item indication, plus pointer behavior.
- [x] Tab/Shift+Tab from an open dropdown dismisses it and continues to the next/previous card using full-order reveal and endpoint wrapping, rather than tabbing through menu items or controls. Dropdown focus is temporary and introduces no card-traversal stop. Focus-return signals allow Work Item 05 to preserve valid inspection and distinguish period/type clearing from initial focus.
- [x] Only active Dashboard/focused-card context handles letter shortcuts; only the open dropdown handles its interaction keys while open. Disable chart/page shortcuts during dropdown ownership, preserve typing and normal modified editing/copy shortcuts including Cmd+C, and avoid double dispatch. Inactive Dashboard and temporary shell focus must not trigger card actions; retain clear integration points for 06's temporary shell scope and 07's explicit Cmd+Shift reorder shortcuts.
- [x] Keep existing grid/card geometry, Time's wrapping summary header, one-row toolbar, text scale, routes/back outcomes, loading/empty behavior, stored-order identity and pointer interactions. No iOS/touch/compact shell, new numeric minima/breakpoints, native full-screen choice or global window policy is added. L18's contextual footer/hints, accessible-only shortcut explanations, shortcut editor and Help screen remain deferred; required names/focus feedback remain present.
- [x] Extend behavior-focused Dashboard/timeline/menu widget coverage with controlled card-scoped inputs: full forward/reverse traversal through every initially unbuilt card under short existing regression viewports; both endpoint wraps; repeat after reordering; internal/shell stop exclusion; named visible card focus; pointer controls; W/B/P/C/Home/End destinations; exact menu keys/selection/dismissal/focus return; Tab continuation; and no inactive/menu/shell double dispatch or editing interception. Use stable card/menu/item selectors, existing provider/repository/clock seams, synthetic Tracks, fake tiles if Latest Walk is rendered, controlled intermediate pumps for lazy-focus races and explicit resource cleanup. Preserve existing robot selectors/journeys; no strict TDD/new robot mandate.
- [x] Run `flutter analyze`, affected Dashboard/Time/summary/card/provider tests under `TZ=Australia/Hobart`, and the complete `TZ=Australia/Hobart flutter test` suite. Check macOS-wide light/dark pointer/keyboard operation, distinct focus and enlarged text without reducing scale. Record actual results and conditional layout gates; fixture dimensions do not approve usable minima.

## Covers

- User Stories: 5 (traversal/menu/page actions), 6 (timeline replacement access).
- Requirements: 15 (keyboard menu closure), 20, 27, 30–32, 37 (shortcut scoping).
- Technical Decisions: 1, 6, 9–11, 13.
- Testing Strategy: 1, 4 (menu keyboard), 7–11 (traversal/timeline/menu portions).
- Interview Ledger: L3, L5, L11, L13–L14; L16 constrains shell scope. L18 remains explicitly deferred.

## Blocked by

- Uses the verified independent chart/menu foundation from [02 — Add Time's three chart views and chart-type menu](02-time-chart-views-and-menu.md). The user authorised independent Work Item 04 implementation on 2026-10-19 (L22), retaining L19's layout gate and incomplete dependent checks; Work Items 01–02 remain incomplete.

## Blocking decisions

- Conditional gate: **minimum usable macOS width**, **minimum usable macOS height**, **supported macOS resize range**, **native macOS full-screen choice**, and **feature-specific wide-layout thresholds** remain Pending in the profile. Resolve/record only an actually dependent value in profile/Spec before dependent reveal/layout implementation or dimension-dependent verification. Existing card geometry and short regression fixtures may be used without declaring new approved minima; settled traversal/state work may proceed.

## Implementation and verification — 2026-10-19

**Independent Work Item 04 scope completed under L22.** The checked criteria above cover traversal, timeline/menu actions, preservation of existing presentation and executed independent verification. They do not complete Work Items 01–02, resolve Pending profile values, or claim the inherited Time long-header height/reachability checks passed. Those two existing gated regression checks remain skipped under L19. Work Items 05–07 remain required for the full keyboard feature.

### Delivered behavior

- Dashboard owns focus nodes by stable card ID and resolves targets against the current Riverpod-owned displayed order. Reveal offsets use the existing grid's actual constraints, column count, spacing and aspect ratio. Scheduled construction/focus requests reject superseding Tabs, scope loss, inactivity and disposal; visited cards retain their state as the lazy grid scrolls.
- Each card has a named focusable semantic node and a theme-primary focus outline distinct from the existing hover outline. Internal controls remain pointer-operable. The board intercepts ordinary card traversal before surrounding shell controls become Tab stops.
- Timeline W/B/Home/End reuse each adapter's existing page controller, current eligibility and enabled destinations. P opens Period; C opens Time's three-choice menu or directly toggles the other cards' existing binary control. Bounds are no-ops without unnecessarily invalidating valid inspection; changed reference dates still reconcile through the shared calendar owner.
- `DashboardDropdown` keeps existing Material menus and adds j/k/arrow selection, Enter, Escape and full-order Tab continuation. Keyboard-opened menus return owning-card focus with explicit entry/unchanged-return/changed-return signals for Work Item 05. Pointer dismissal preserves outside typing focus. Menu ownership is identity-based and released even if refreshed data removes a closing menu.
- Per-card action bindings and scoped focus ownership provide integration points for Work Items 06–07. No new chart preferences, routes, shell keyboard entries or shortcut-help surfaces were added. Technical Decision 11's existing ADS-1.0 shell-access gap remains recorded rather than treated as an approved exception.

### Executed checks

- `flutter analyze` — **passed, no issues**.
- `env TZ=Australia/Hobart flutter test test/widget/dashboard_keyboard_test.dart test/widget/dashboard_screen_test.dart test/widget/dashboard_readiness_test.dart test/widget/time_card_test.dart test/widget/summary_card_navigation_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart test/providers/dashboard_layout_provider_test.dart test/providers/summary_page_controller_test.dart test/providers/time_chart_type_provider_test.dart test/robot/dashboard/dashboard_journey_test.dart --reporter expanded` — **285 passed, 2 existing layout-gated skips**.
- `caffeinate -i env TZ=Australia/Hobart flutter test --concurrency=4 --reporter failures-only` — **2,612 passed, 7 skipped**. Two retain L19's layout gate; five predate this slice. An earlier expanded full-suite attempt reached 1,960 passes before its 20-minute command timeout; the ensuing stream/SIGTERM finalization errors belong to that terminated attempt, not the successful completion run.
- Added 17 Dashboard keyboard widget regressions covering initially unbuilt targets in both directions at short existing two-/three-column fixtures, wrapping, real pointer reordering, overlapping focus/order requests, reference-clock advancement, every preset's toolbar-equivalent destinations on all four timelines, exact menu choices/keys, focus-return signals, dismissal/refresh races, pointer controls, modifiers, editing and inactive/shell scope exclusion.
- macOS-themed light/dark widget checks verify named focus, semantic focus state, distinct focus borders, pointer controls and one-row toolbars at **1.5× text scale**. These are deterministic desktop widget checks, not a separate live native-app visual inspection or approval of fixture dimensions as usable minima.
- Updated the existing pending-scroll/type-selection regression to select while its menu is actually open; callbacks retained after dismissal are now correctly ignored, with separate coverage for that stale-callback case and disposal.
- Intended commit scope includes this implementation, tests and L22/progress artifacts. The pre-existing `macos/Podfile.lock` change is unrelated.
