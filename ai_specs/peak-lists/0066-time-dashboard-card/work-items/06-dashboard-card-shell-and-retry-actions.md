---
type: Work Item
title: Add remaining card actions, temporary shell navigation, and Time Retry shortcut
parent: ../spec.md
---

## What to build

Complete replacement keyboard access for non-timeline Dashboard cards, temporary destination-only shell navigation and the visible Time preference warning Retry. Integrate card selection/focus with existing providers, map actions and GoRouter destinations, maintaining pointer outcomes and no extra normal Tab stops. Reuse Work Item 03's displayed-warning/retry identity and 04's full-order focus/menu scoping; verify using deterministic card and routed Dashboard tests.

Apply ADS-1.0 and Desktop wide/macOS-only named visible focus, logical selection, semantics, compact keyboard/pointer feedback, semantic light/dark styling and respected text scaling, retaining ObjectBox/Riverpod/GoRouter ownership. Record Technical Decision 11's intentional conflict: **reason** is the explicit L16 destination-only product choice; **scope** is Background Jobs, its panel controls, other shell notification actions and card-order Retry; **approval status** confirms product scope only, not an approved ADS-1.0 exception or settled L10 governance. Do not claim complete keyboard accessibility.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/work-items/03-time-chart-preference-recovery.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/04-dashboard-card-traversal-and-timeline-keys.md` and their active feedback/focus/shortcut interfaces.
- `lib/widgets/dashboard/latest_walk_card.dart`, `lib/widgets/dashboard/year_to_date_card.dart`, `lib/widgets/dashboard/my_lists_card.dart`, `lib/widgets/dashboard/my_ascents_card.dart`: existing browsing/sort/row/map semantics and enabled states.
- `lib/providers/my_lists_summary_provider.dart`, `lib/providers/my_ascents_summary_provider.dart`, `lib/providers/map_provider.dart`, `lib/services/latest_walk_summary.dart`, `lib/services/my_ascents_summary_service.dart`, `lib/services/peak_list_summary_service.dart`: existing data projections/action boundaries and selection identity.
- `lib/screens/dashboard_screen.dart`, `lib/router.dart`, `lib/app.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/theme.dart`: stable card order, routed shell destination actions/activation, named focus/row styling and feedback ownership.
- `test/widget/latest_walk_card_test.dart`, `test/widget/year_to_date_card_test.dart`, `test/widget/my_lists_card_test.dart`, `test/widget/my_ascents_card_test.dart`, `test/widget/dashboard_screen_test.dart`, `test/widget/dashboard_readiness_test.dart`.
- `test/providers/my_lists_summary_provider_test.dart`, `test/providers/my_ascents_summary_provider_test.dart`, `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`: provider/route overrides, stable rows/card selectors and fake tile harness conventions.

## Acceptance criteria

- [ ] Latest Walk focused: B invokes existing `Previous track`, W existing `Next track`, respecting enabled states and keeping focus on the card while browsing. Enter opens the currently displayed Track through its existing map action; preserve `showTrack`/existing `/map` outcome, selection/loading/empty and pointer behavior.
- [ ] Separate My Year to Date focused: B/W invoke existing `Previous year`/`Next year` with that card's existing bounds, keeping card focus. Do not substitute timeline Year to Date calendar semantics or change the statistics card's values/presentation.
- [ ] On initial focus of populated My Lists/My Ascents, select the first row. Empty cards select no row and Enter opens nothing. Down/j and Up/k move next/previous without wrapping and reveal the selected row, including off-screen rows. Rows remain outside normal Tab traversal; selection and keyboard focus are visibly distinct from hover in light/dark themes.
- [ ] My Lists Enter uses the selected row's existing list map action, including `preparePeakListMapNavigation`, its failure/should-navigate policy and existing `/map` route outcome. My Ascents Enter uses the selected row's existing Track action. Preserve pointer actions, existing feedback and route/back behavior rather than bypassing preparation or introducing routes.
- [ ] S toggles My Ascents' existing date sort, retaining the selected row by identity when possible and keeping it usable/visible. Persist no new row-selection/sort/navigation preference in this feature; application/screen state has an explicit Riverpod owner, while focus/scroll presentation has explicit lifecycle owners.
- [ ] F6 from a focused Dashboard card temporarily focuses the currently selected shell destination. Within that scope, Up/Down or k/j highlights destinations without activating; Enter activates through the existing shell action. Escape/F6 returns to the previous Dashboard card without navigation. Tab/Shift+Tab returns through that card and resumes next/previous full-order/wrapping traversal, including reveal of unbuilt targets.
- [ ] Normal Dashboard traversal still has one meaningful visible focus stop per card, excluding shell destinations/internal actions. Temporary shell focus must not also dispatch card shortcuts. F6 remains destination-only: add no keyboard entry path/Tab stop for Background Jobs, its panel controls, other shell notification actions or card-order Retry; preserve their pointer actions. This implements confirmed L16 scope while retaining the documented ADS-1.0 alignment gap.
- [ ] While a Time preference warning SnackBar is actually visible, R from any focused Dashboard card invokes that displayed warning's existing Retry, even if Time is off-screen. Preserve current-card focus and deduplicate pending retries. A read Retry retains the newer-explicit-choice guard; save Retry writes the latest selected type. Reuse 03's exact `Couldn’t load Time chart preference.` / `Couldn’t save Time chart preference.` with action `Retry`, warning lifetime, once-only delivery and latest-choice policies.
- [ ] Without a visible Time preference warning, R does nothing, including when a Time warning is only queued or a card-order failure SnackBar is displayed. R never retries card-order saves. Keep SnackBar actions pointer-operable and outside normal Dashboard Tab traversal.
- [ ] Card shortcuts operate only in active Dashboard/focused-card context and do not intercept typing or modified editing/copy shortcuts including Cmd+C. Temporary shell/dropdown interaction keys have a single owner and do not double-dispatch browsing, sorting, row navigation or R. Preserve 04's timeline actions; Cmd+Shift reorder behavior arrives in 07 without converting ordinary modified arrow/editing input into row actions.
- [ ] Preserve all chart controls/data/defaults/formatting/header presentation/chart preferences on existing cards; add no combined actions menu, extra route/navigation surface, runtime network dependency, schema change, iOS/compact layout, global window policy or guessed minimum dimensions. L18's hints/footer, accessible-only shortcut explanations, shortcut editing and Help screen remain deferred; accessible names, focus/selection feedback and required inspected values remain required.
- [ ] Add focused card/provider and routed Dashboard widget coverage for B/W/Enter enabled/empty states; first-row/non-wrapping selection and scroll; selected list/Track map outcomes and preparation failures; S sorting/selection retention; distinct hover/selection/focus; selected-destination F6 entry, highlight versus activation, all return paths and resumed traversal; R from each relevant card with Time off-screen, no visible warning/no-op, no card-order Retry, no focus loss and retry deduplication. Verify inactive/menu/shell contexts do not double-dispatch and typing/modified shortcuts remain intact.
- [ ] Use stable existing card/row selectors and explicit shell/menu selectors, controlled clocks/synthetic Tracks/preference failures/provider/repository overrides, routed harnesses and controlled pumps for focus/retry races. Fake tile access when Latest Walk is rendered, preserve robot selectors/journeys, and dispose containers/controllers/listeners/resources. No live services/credentials/user database, strict TDD or new robot journey is required.
- [ ] Run `flutter analyze`, affected card/provider/Time/Dashboard/routed widget tests under `TZ=Australia/Hobart`, and complete `TZ=Australia/Hobart flutter test`. Verify affected macOS-wide light/dark keyboard/pointer/focus/selection and enlarged text without reducing scale. Record actual results and gate any genuinely Pending-dimension-dependent verification; test sizes do not approve minima or full standard compliance.

## Covers

- User Stories: 6.
- Requirements: 20, 27, 33–36, 37 (shortcut scoping).
- Technical Decisions: 1, 4, 6, 9–11, 13.
- Testing Strategy: 1, 8–9, 11–12 (replacement access, R and narrowed shell portions).
- Interview Ledger: L9, L11–L14, L16. L18 remains deferred; the earlier L13 blanket-access statement is narrowed by L16 rather than silently treated as fulfilled.

## Blocked by

- [03 — Remember Time's chart type with lifecycle-safe failure recovery](03-time-chart-preference-recovery.md).
- [04 — Deliver full-order card traversal and timeline/menu keyboard actions](04-dashboard-card-traversal-and-timeline-keys.md).
