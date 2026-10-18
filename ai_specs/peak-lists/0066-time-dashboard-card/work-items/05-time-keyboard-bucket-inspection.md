---
type: Work Item
title: Add Time's keyboard bucket inspection and page-boundary transitions
parent: ../spec.md
---

## What to build

Complete the Time-specific keyboard inspection slice on the card focus/menu/page paths from Work Item 04. Drive accessible inspection from the same eligible buckets and calendar state used by pointer interaction, preserving distinct initial-focus, cleared-inspection, W/B page, directional page-crossing and menu-return transitions. Include deterministic widget/race coverage for all three chart types.

Apply ADS-1.0 and Desktop wide/macOS-only focus/semantics/pointer rules, semantic light/dark styling and respected text scale. Retain ObjectBox domain ownership, Riverpod page/application state, GoRouter navigation and explicit transient focus/inspection/controller disposal. Preserve the parent Spec's L16 accessibility limitation without claiming full standard compliance or an approved exception.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/04-dashboard-card-traversal-and-timeline-keys.md` and its focus/menu implementation; Time metrics/renderers from 01–02.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`, `ai_specs/peak-lists/0065-dashboard-weekly-tooltip-and-year-navigation/spec.md` (0065 precedence).
- `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_page_browser.dart`, `lib/providers/summary_page_controller.dart`, `lib/services/summary_card_service.dart`, `lib/screens/dashboard_screen.dart`: shared inspection presentation, authoritative page navigation, pending-input reconciliation and focus ownership.
- `lib/theme.dart`, `lib/core/number_formatters.dart`, `lib/core/date_formatters.dart` and Time adapter/formatters: exact colours, durations and reference date titles.
- `test/widget/summary_chart_tooltip_test.dart`, `test/widget/summary_card_navigation_test.dart`, `test/widget/summary_calendar_navigation_test.dart`, `test/providers/summary_page_controller_test.dart`, `test/widget/dashboard_screen_test.dart`, Time/menu tests from prior slices and `test/robot/dashboard/dashboard_robot.dart`.

## Acceptance criteria

- [ ] On genuine keyboard focus entry to Time with a rendered chart, immediately inspect the selected page's latest bucket containing eligible Tracks, including zero/zero-duration activity. If the page has no eligible Tracks, inspect its first bucket; loading and wholly-empty states inspect no bucket. Determine activity from eligible Track presence, not nonzero duration.
- [ ] Left/h inspects the previous bucket and Right/l the next. The first directional key after focus moves from the already-inspected initial bucket, including boundary behavior; it does not merely initialize. Expose the same reference date, `Total Time: <duration>` and `Moving Time: <duration>` rows as pointer hover/pin, in that order, and make the inspected date/both values available to assistive technology in every chart type, including coincident lines and zero-valued buckets.
- [ ] At first/last bucket, Left/h or Right/l uses the toolbar's previous/next calendar page sequence and bounds, including empty intervening pages. Land on the last bucket of the previous page or first bucket of the next page respectively. At the overall limit, stay on the boundary bucket. Retain card focus and agreement among selected page/header/chart/range/controls; do not substitute the W/B initialization policy.
- [ ] Escape outside a menu clears inspection but retains Time card focus. The next Left/Right/h/l initializes the latest-eligible/first-empty bucket without also stepping; later directional keys step normally. Preserve the cleared state until a directional key initializes rather than automatically reinitializing on incidental focus notifications.
- [ ] After W/B invokes the toolbar Next/Previous and changes page, inspect the destination's latest eligible bucket or first bucket if empty. Reuse the same period steps, limits and reconciliation as toolbar/trackpad; do not initialize to last/first merely because directional boundary crossing does so.
- [ ] P opens Period and C Chart type under Work Item 04's scoped menus. Returning from a dismissed/unchanged menu preserves still-valid inspection. Changing period or type clears old inspection, retains the approved selected-page behavior, and leaves inspection cleared until a directional key initializes without stepping. Menu focus return never unconditionally restarts inspection. Same-type selection is a no-op; changing type preserves page.
- [ ] Down/j, Up/k, Enter, Escape and Tab/Shift+Tab belong exclusively to an open dropdown; chart/page shortcuts are disabled there. On selection/dismissal return owning-card focus; Tab/Shift+Tab dismisses and continues full-order/wrapping traversal, including lazy reveal. Never double-dispatch menu interaction to chart navigation.
- [ ] All three renderers preserve identical eligibility, calendar buckets, primary-only header, exact formatting, palette and date titles. Work Item 01's subset stack and 02's line/coincident/clustered rules remain intact. Visible focus is distinct from hover/inspection; pointer hover/click/pinning and menu operation remain usable.
- [ ] Reuse existing reference-clock reconciliation on activation/refresh/interaction without a midnight timer, allowed-history preservation/clamping, current-page following and historical remapping. Data/page/type refresh clears obsolete inspection; superseded pending movement, reference-day changes, removed eligibility, focus targets and disposal cannot restore stale inspection/page/header values or call disposed owners. Keep card-focus entry separate from menu focus return.
- [ ] Scope keys to active Dashboard and Time card only, preserving text editing and modified shortcuts including Cmd+C; dropdown/shell contexts must not also dispatch Time actions. Keep other cards' chart controls/defaults/presentation/eligibility/preferences and existing routes/global geometry/window policy unchanged. Do not add hints/footer, accessible-only shortcut explanations, remapping or Help screen under deferred L18; required accessible inspected values remain in scope.
- [ ] Add behavior-focused widget tests across stacked/line/clustered views: initial focus with latest nonzero and zero-duration activity, first-empty bucket, loading/wholly-empty, first-key stepping, both directional aliases, boundary crossing/landing, empty gaps/limits, W/B destinations, Escape/re-entry, P/C menu ownership, unchanged/dismissed return versus changed period/type clearing, Tab/Shift+Tab full-order/wrapping continuation, accessible date/both values, pointer equivalence, refresh/rollover and disposal. Deliberately overlap page inputs and superseding data/menu/type actions with controlled intermediate pumps and advance past old callbacks; do not settle after every input and hide races.
- [ ] Use existing synthetic Track/clock/provider/repository seams and stable card-scoped chart/menu/item keys, preserving robot selectors/journeys. Fake tiles if needed and dispose containers/controllers/listeners/resources; require no real services/storage/user database/credentials and no new strict TDD or robot journey.
- [ ] Run `flutter analyze`, affected Time/summary/page-controller/Dashboard widget tests under `TZ=Australia/Hobart`, and complete `TZ=Australia/Hobart flutter test`. Verify affected macOS-wide light/dark pointer/keyboard/focus/assistive values and enlarged text without scale reduction. Report executed results; apply the parent's Pending-value gate to genuinely dimension-dependent work rather than approving fixture sizes as minima.

## Covers

- User Stories: 5.
- Requirements: 13, 15, 19, 28–31.
- Technical Decisions: 1, 5–6, 9–11, 13.
- Testing Strategy: 1, 4 (keyboard inspection), 8–10.
- Interview Ledger: L11, L14–L15. L18 discovery/editor/Help work remains deferred.

## Blocked by

- [04 — Deliver full-order card traversal and timeline/menu keyboard actions](04-dashboard-card-traversal-and-timeline-keys.md).
