---
type: Work Item
title: Filtered My Peak Lists Content And Selection Handoff
parent: ../spec.md
---

## What to build

Apply the approved `/peaks` region-filter state to visible `My Peak Lists` content so the summary pane, selected list, `peak list mini-map`, and details pane stay synchronized as filters change. When the current filter removes the selected list, immediately move selection to the first remaining visible peak list in the current filtered order; when no visible peak lists remain, clear the current selection; and keep the empty-state, summary pane, mini-map, and details pane consistent with that deterministic handoff behavior.

## Required context

- `lib/screens/peak_lists_screen.dart` already owns the summary pane, selected-list state, empty-state rendering, `peak list mini-map`, and details-pane updates. Keep this slice vertical inside that existing screen/state boundary unless a very small helper is clearly needed.
- `lib/services/peak_list_visibility.dart` already contains canonical-region normalization and `mixed-region peak list` applicability logic. Reuse that region-visibility seam when filtering visible `My Peak Lists` content.
- `lib/models/peak_list.dart` already defines `PeakList.mixedRegion`; preserve that vocabulary and behavior exactly rather than introducing a second mixed-region concept.
- Existing deterministic coverage lives in `test/widget/peak_lists_screen_test.dart`, which already exercises `/peaks` selection, panes, and `peak list mini-map` behavior through fake repositories and mocked `SharedPreferences`.
- Keep tests widget-first for this slice and reuse existing fake repository seams rather than real network, real map services, or secrets.

## Acceptance criteria

- [ ] `My Peak Lists` shows the union of all peak lists applicable to the currently selected manifest regions.
- [ ] A peak list with a canonical manifest region is visible when its region matches any selected region, a `mixed-region peak list` is visible when at least one of its applicable regions is selected, and peak lists whose stored `region` is neither a manifest region nor `mixed` remain hidden in this slice.
- [ ] If the user turns every `/peaks` `region FAB` off, `My Peak Lists` shows no visible peak lists, keeps the empty state visible, and does not silently restore all regions.
- [ ] When the current filter removes the currently selected peak list from the visible set, `My Peak Lists` immediately selects the first remaining visible peak list in the current filtered order.
- [ ] When the current filter leaves no visible peak lists, `My Peak Lists` clears the current selection.
- [ ] After either selection handoff or selection clearing, the summary pane, `peak list mini-map`, and details pane update immediately to match the new visible selection state.
- [ ] Filter changes do not leave `PeakListsScreen` in a stale state where the selected row, selected title, mini-map content, or details pane still reflect a now-hidden peak list.
- [ ] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies filter-driven selection handoff to the first remaining visible list in filtered order, selection clearing when no visible peak lists remain, and immediate summary-pane, `peak list mini-map`, and details-pane updates that follow the new selection state.
- [ ] Widget coverage in `test/widget/peak_lists_screen_test.dart` also verifies the all-off empty-state behavior within the full filtered `My Peak Lists` screen flow rather than only through isolated state helpers.

## Covers

- User Stories: 1, 3
- Requirements: 4-5, 7-8
- Technical Decisions: 2
- Testing Strategy: 1-2, 8
- Interview Ledger: L3, L5-L6, L9, L11

## Blocked by

- `01-manifest-backed-peaks-region-filter-state.md`
