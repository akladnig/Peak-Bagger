---
type: Work Item
title: Restore Map Peak-List Interaction Responsiveness
parent: ../spec.md
---

## What to build

Restore smooth `Map` interaction for the confirmed regression surfaces by decoupling `Peak Lists` drawer taps and continuous camera motion from synchronous peak-list-derived recomputation. `All Peaks` and specific peak-list drawer interactions must acknowledge the latest accepted selection immediately, while main-map peak projection, visible-region reconciliation, peak filtering, chip visibility, and `Peak ownership ring` rendering settle through a supersedable deferred pipeline that preserves the current selection, visibility, and labeling contract.

## Required context

- `lib/providers/map_provider.dart` already owns accepted `Map` peak-list selection state, visible-bounds updates, and visible-region snapshot reconciliation. Keep immediate drawer control-state updates inside that existing seam rather than introducing another source of truth.
- `lib/providers/peak_list_selection_provider.dart` currently performs synchronous `PeakListRepository.getPeakListItemsForList(...)` reads while building drawer entries, app-bar chips, metadata-filter scope peaks, and `Peak ownership ring` outputs. Reuse its deferred refresh scheduler seam and related provider tests instead of replacing the selection pipeline wholesale.
- `lib/screens/map_screen.dart` and `lib/services/peak_projection_cache.dart` already own continuous camera updates, visible-bounds sync, and main-map peak projection or viewport work. Treat continuous motion and discrete selection changes as separate performance boundaries inside those existing seams.
- `lib/widgets/map_peak_lists_drawer.dart` already owns the `Map` `Peak Lists` drawer rows, `All Peaks` control, and pin interactions. Preserve current labels, row structure, and pin behavior.
- `lib/services/peak_list_visibility.dart` already defines visible-region and `Mixed-region peak list` applicability rules. Reuse that seam instead of redefining visibility semantics.
- Existing deterministic seams and coverage live in `test/widget/map_peak_list_selection_test.dart`, `test/widget/map_screen_rebuild_test.dart`, and `test/providers/peak_list_selection_provider_test.dart`. Reuse in-memory repositories, provider overrides, debug counters, and test-controlled completion seams rather than wall-clock assertions or live datasets.

## Acceptance criteria

- [ ] Tapping `All Peaks` or a specific `Map` `Peak Lists` drawer row updates the newly accepted control state immediately without synchronously waiting for full membership-derived recomputation.
- [ ] Continuous `Map` zoom and pan no longer force peak-list-dependent recomputation on every camera tick in the affected regression path.
- [ ] During in-motion camera updates, the app prioritizes smooth basemap and camera motion over per-tick peak-list-dependent filtering, visible-region reconciliation, `Peak ownership ring` derivation, or related main-map projection work.
- [ ] Membership-derived peak filtering, chip visibility reconciliation, `Peak ownership ring` derivation, and related peak-list-dependent map content refresh after the immediate selection acknowledgment or motion settle through an app-owned deferred pipeline.
- [ ] Rapid consecutive `Map` peak-list selection changes and overlapping motion or settle refreshes follow `latest interaction wins`, and stale queued or in-flight completions cannot overwrite a newer accepted selection state.
- [ ] The immediate and settled `Map` interaction paths preserve current labels, selection rules, chip behavior, pin behavior, and visible-region rules for the affected peak-list surfaces.
- [ ] The implementation does not add new spinner copy, progress copy, or disabled-control contracts for `Map` peak-list interaction unless a temporary correctness guard is proven strictly necessary.
- [ ] Settled `Map` content after deferred refresh matches the latest accepted selection, including rendered peaks, app-bar chips, and any visible peak-list-dependent styling derived from the selection.
- [ ] Deterministic provider or widget coverage proves both hot-path decoupling and stale-work supersession for drawer selection and continuous map motion without relying on wall-clock latency assertions.
- [ ] Final manual verification is performed against the existing real migrated local post-`0024` data that reproduces the slowdown, confirming smooth `Map` pan and zoom, near-immediate `Peak Lists` drawer feedback, and correct post-motion settle behavior on the normal development machine.

## Covers

- User Stories: 1, 2, 4
- Requirements: 1-4, 6-11, 13
- Technical Decisions: 1-3, 5-7
- Testing Strategy: 1-6, 8
- Interview Ledger: L1-L4, L6-L9

## Blocked by

None - ready to start
