---
type: Spec
title: My Peak Lists Add And Map Responsiveness Follow-Up
---

## Problem

`0029` fixed the data-loss regression where `My Peak Lists` `Add New Peak` could clear an existing list, but the current implementation has reintroduced broader interaction slowness that `#158` and `#159` previously addressed. The current follow-up must preserve the in-place membership and rollback safety fix while restoring smooth `Map` pan and zoom behavior and avoiding renewed blocking work in `My Peak Lists` refresh paths. Nearby `#160` `Peak visibility mode` changes also mean the restored map responsiveness contract now has to hold across `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`. [L1] [L2] [L7] [L8]

## Proposed Outcome

`My Peak Lists` `Add New Peak` keeps the corrected in-place save behavior, closes immediately after a successful save, preserves the selected list identity, and auto-selects the first newly added peak by deterministic alphabetical order once the existing deferred summary refresh settles. At the same time, `Map` pan and zoom regain the responsiveness contract established by `#158` and `#159`, with `Show Peak Clusters` and `Show Peaks` decoupling heavy peak-list-derived work from continuous motion and `Hide Peaks` remaining the cheapest path by skipping visible-mode peak processing. Peak-list import and export remain unchanged. [L1] [L2] [L3] [L4] [L5] [L8]

## User Stories

1. As a user maintaining `My Peak Lists`, when I add peaks to an existing list, the list keeps its current identity and memberships, the dialog closes promptly on success, and the UI settles back to the same list with one of the newly added peaks selected. [L2] [L3] [L4] [L5]
2. As a user adding multiple peaks at once, the automatic post-save selection is deterministic and picks the first newly added peak by case-insensitive alphabetical `name`, then smaller `osmId` when names tie. [L4] [L5]
3. As a map user, I can pan and zoom smoothly again while `Peak visibility mode` is `Show Peak Clusters` or `Show Peaks`, without losing the current settled correctness contract after motion stops. [L2] [L8]
4. As a map user using `Hide Peaks`, I get the cheapest map interaction path and the app does not continue doing visible-mode peak work behind the scenes. [L8]

## Requirements

1. Scope this follow-up to preserving `My Peak Lists` `Add New Peak` correctness while restoring broader responsiveness for `Map` pan and zoom. Keep peak-list import and export behavior unchanged for this slice. [L1] [L2]
2. Treat the responsiveness and visibility-mode contracts already captured in `0027-peak-list-interaction-performance-regression`, `0028-map-peak-visibility-mode-fab`, and the relevant current `#160` map-state changes as the authoritative baseline for this work. Do not solve this slice by reverting the repaired add-flow and responsiveness behavior wholesale. [L1] [L7]
3. A successful `My Peak Lists` `Add New Peak` save must keep the selected existing `PeakList` identity and selected title, then close the dialog immediately after the in-place save succeeds. [L3]
4. After a successful add, `My Peak Lists` must refresh through the existing deferred summary path rather than forcing a synchronous full recompute before dialog close. Do not add new loading copy, spinner copy, or disabled-control UI for this refresh. [L3]
5. After a successful add, `My Peak Lists` must automatically switch peak selection to one of the newly added peaks. [L4]
6. If multiple newly added peaks are eligible for the automatic post-save selection, choose the first by case-insensitive alphabetical stored `Peak.name`; if names tie, choose the smaller `Peak.osmId`. [L5]
7. The newly selected peak row may appear when the deferred summary refresh settles. The fix must not restore synchronous heavy recomputation only to make that row appear before the dialog closes. [L3] [L4] [L5]
8. Preserve the existing `0029` failure safety contract for `Add New Peak`: repository or persistence failure leaves the selected list unchanged, preserves the current selected list identity, keeps the add dialog session open, and allows retry or cancel without rebuilding the current selection.
9. Restoring this slice must not regress the existing `0027` responsiveness contract for `Map` `Peak Lists` drawer taps or `My Peak Lists` `Region FAB` taps while reworking the add-flow refresh path. The immediate interaction path for those controls must update visible accepted control state first rather than synchronously waiting for full peak-list-derived recomputation to finish. [L2] [L6]
10. `Map` pan and zoom responsiveness coverage for this follow-up must apply across all three `Peak visibility mode` states. [L8]
11. In `Show Peak Clusters` and `Show Peaks`, continuous map motion must prioritize smooth camera and basemap interaction over per-tick peak-list-derived recomputation. During continuous motion, the app must not require a fresh peak-list-derived refresh or a fresh full main-map peak projection or viewport rebuild on every camera tick just to keep the map moving; reusing or transforming the last settled peak viewport frame during motion is acceptable. [L8]
12. Once map motion settles in `Show Peak Clusters` or `Show Peaks`, the visible peak rendering and related peak-list-derived state must converge to the correct final result for the latest accepted map state within about `250 ms` on the normal development machine. Treat this as a local responsiveness target for final verification, not a guaranteed cross-device SLA. [L8]
13. In `Hide Peaks`, the map must remain the cheapest path and must not continue doing the peak marker rendering, clustering, hover hit-testing, or equivalent main-map peak-processing work required for visible modes. If performance is still poor in `Hide Peaks`, treat that as part of this regression rather than as acceptable leftover cost. [L8]
14. This follow-up must preserve the current `Peak visibility mode` labels, icon contract, low-zoom hide rule, and remembered selection semantics from `0028`; this is a responsiveness and add-flow follow-up, not a visibility-mode redesign. [L1] [L8]

## Technical Decisions

1. Preserve the repository-side in-place membership-preservation and rollback-safety fix in `lib/services/peak_list_repository.dart` rather than reverting it as part of the responsiveness repair. [L7]
2. Rework the current screen-level refresh behavior in `lib/screens/peak_lists_screen.dart`, including add-success refresh sequencing and deferred summary scheduling, instead of restoring name-based replacement behavior or broad synchronous recomputation. [L3] [L7]
3. Reuse the existing app-owned deferred `My Peak Lists` summary seam and settled-state supersession rules from `0027` wherever possible, extending them only as needed for post-add selection continuity. [L3] [L6]
4. Treat the current `Peak visibility mode` state machine from `0028` as authoritative and optimize the hot paths underneath it rather than redesigning the visible mode cycle or selection model. For continuous motion, treat the `MapScreen` live-camera and settled-viewport behavior as the implementation seam to preserve and tighten rather than moving this contract into a new source of truth. [L1] [L8]
5. Prefer the smallest correction in existing Flutter, Riverpod, repository, and widget seams that preserves the restored responsiveness contract and the corrected add-flow contract together. [L2] [L7]

## Testing Strategy

1. Use behavior-first TDD for any logic, state, or widget change that affects add-success selection ordering, deferred refresh behavior, or continuous map hot-path separation.
2. Preserve deterministic repository coverage proving in-place membership preservation and rollback safety for `Add New Peak`, extending the existing `0029` repository seam only where this follow-up changes behavior. [L6] [L7]
3. Add widget-level regression coverage proving a successful add closes immediately, keeps the same selected list title, and eventually highlights the deterministic newly added peak after the deferred summary refresh settles. [L3] [L4] [L5] [L6]
4. Add widget-level regression coverage proving add failure still leaves the dialog session intact, preserves the same selected list identity, and keeps the current retry or cancel path available. [L6]
5. Add deterministic map widget regression coverage across all three `Peak visibility mode` states, proving visible modes decouple heavy peak-list-derived work from continuous pan or zoom and `Hide Peaks` gates visible-mode peak processing early. Reuse the existing `MapScreen` motion seam and `MapRebuildDebugCounters`-style observability in `test/widget/map_screen_rebuild_test.dart` wherever possible instead of relying on provider-only proof for continuous-motion behavior. [L6] [L8]
6. Reuse the existing `0027` deterministic seams and regressions for `Map` drawer responsiveness, `My Peak Lists` `Region FAB` responsiveness, and stale-work supersession rather than rebuilding that suite unless this follow-up changes the contract they assert. [L6]
7. Avoid fragile wall-clock assertions in automated tests. Prove the regression through deterministic deferred-refresh seams, controlled completion order, observable hot-path gating boundaries, and widget-level motion tests that exercise `MapScreen` rather than only provider state.
8. Final manual verification must use the existing real migrated local post-`0024` data that previously reproduced the slowdown and must recheck:
   - `My Peak Lists` `Add New Peak` success and failure behavior,
   - automatic post-save selection of the first newly added peak by the agreed ordering rule,
   - `My Peak Lists` `Region FAB` responsiveness,
   - `Map` pan and zoom responsiveness in `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`,
   - `Map` `Peak Lists` drawer responsiveness. [L6] [L8]

## Out of Scope

1. Reverting the repaired add-flow and responsiveness behavior wholesale.
2. Redesigning the current multi-select `Add New Peak` picker UX, picker contents, or visible labels.
3. Changing peak-list import or export behavior beyond preserving current working behavior.
4. Redesigning `Peak visibility mode` labels, icons, state order, low-zoom behavior, or remembered selection semantics from `0028`.
5. Unrelated map, import, export, or peak-list feature work outside the add-flow and responsiveness regressions described here.

## Notes

1. Relevant current implementation and regression surfaces include `lib/screens/peak_lists_screen.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/services/peak_list_repository.dart`, `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `test/services/peak_list_repository_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/widget/map_screen_rebuild_test.dart`, and `test/widget/map_peak_list_selection_test.dart`.
2. This follow-up builds on the contracts already captured in `0027-peak-list-interaction-performance-regression`, `0028-map-peak-visibility-mode-fab`, and `0029-my-peak-lists-add-new-peak-membership-preservation`.
3. For continuous map motion, the concrete local baseline is the existing `MapScreen` behavior that keeps camera movement responsive by avoiding fresh peak-list-derived refreshes and fresh full peak projection work on every gesture tick, then converging to the correct settled state after motion ends.
