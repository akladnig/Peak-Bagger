---
type: Spec
title: Peak List Interaction Performance Regression
---

## Problem

Recent post-`0024` peak-list membership changes restored relational source-of-truth behavior, but the affected `Map` and `My Peak Lists` interaction paths now feel much slower during normal use. In the current codebase, peak-list visibility and selection flows still perform synchronous `PeakListRepository.getPeakListItemsForList(...)` reads inside hot UI and provider paths, including `Map` peak-list selection, visible-region filtering, and `My Peak Lists` summary derivation. That makes `Map` zoom and pan, `Map` `Peak Lists` drawer selection, and `My Peak Lists` app-bar `Region FAB` taps feel blocked against relational membership work that the `Peak list mini-map` no longer appears to trigger. [L1] [L2] [L3] [L4]

## Proposed Outcome

Restore smooth interaction for the affected peak-list surfaces by decoupling expensive peak-list-derived recomputation from the immediate tap and continuous camera-motion paths while preserving the current user-visible selection, visibility, and labeling contract. The app should update selection state immediately, keep `Map` pan and zoom smooth, settle deferred peak-list-dependent rendering to the correct final state shortly after motion or rapid selection changes complete, and prove the regression with deterministic automated coverage plus real migrated local-data verification. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8]

## User Stories

1. As a user on `Map`, I can zoom and pan smoothly again even when peak-list-derived rendering is enabled by my current selection state. [L1] [L4] [L6]
2. As a user opening the `Map` `Peak Lists` drawer, I can tap `All Peaks` or specific peak lists and see the new selection state respond effectively immediately instead of waiting on heavy membership work. [L1] [L2] [L3] [L6]
3. As a user on `My Peak Lists`, I can tap app-bar `Region FAB`s and get fast region-filter feedback without blocking while the larger list summaries recompute. [L1] [L2] [L3] [L6]
4. As a user making several selection changes quickly, I always end up with the most recent requested selection and peak rendering, without stale intermediate results winning. [L3] [L7]

## Requirements

1. Scope this slice to the confirmed regression surfaces only: `Map` zoom and pan responsiveness, `Map` `Peak Lists` drawer selection taps, and `My Peak Lists` app-bar `Region FAB` taps. Keep `Peak list mini-map`, import/export, and peak edit dialogs out of scope unless implementation proves they share the same blocking path. [L1]
2. Preserve current labels, selection rules, visibility rules, chip behavior, and region-filter semantics for the affected surfaces. This is a responsiveness regression fix, not a peak-list UX redesign. [L2]
3. The immediate interaction path for `Map` peak-list selection and `My Peak Lists` region-filter taps must update visible control state first rather than synchronously waiting for full peak-list-derived recomputation to finish. [L3] [L6]
4. Expensive peak-list-derived recomputation may run after the immediate interaction path, provided the final selected lists, summary rows, and rendered peaks settle to the correct result for the latest accepted state. During that settle window, immediate control state may acknowledge the latest accepted selection before membership-derived summary rows or rendered peaks finish converging, but stale work must never revert the accepted control state or overwrite newer settled content. [L3] [L7]
5. For `My Peak Lists`, app-bar `Region FAB` taps must not depend on synchronous per-list membership reads or full summary derivation during the immediate `PeakListsScreen` interaction path. Membership-derived summary rows may refresh after the immediate control-state update, but the settled screen must match the latest accepted region selection. [L3] [L6] [L7]
6. Do not add new spinner copy, progress copy, or disabled control contracts for these interactions unless implementation proves that a temporary guard is strictly required to prevent incorrect state. [L2] [L3]
7. During continuous `Map` zoom and pan, the app must prioritize smooth basemap and camera motion over per-tick peak-list-dependent recomputation. Peak-list-dependent peak rendering may be throttled, coalesced, or refreshed at gesture end rather than on every camera tick. [L4] [L6]
8. In-motion lag is acceptable only while the user is still moving the map. Once motion settles, the visible peak rendering must converge to the correct final state for the active selection within about 250 ms on the normal development machine. [L4] [L6]
9. `Map` `Peak Lists` drawer taps and `My Peak Lists` `Region FAB` taps should show the newly selected control state within about 100 ms and feel effectively immediate on the normal development machine. Treat this as a local responsiveness target, not a guaranteed cross-device SLA. [L6]
10. Rapid consecutive `Map` peak-list selections and `My Peak Lists` region-filter taps must follow a `latest interaction wins` rule. The app must keep controls responsive, avoid locking them for deferred recomputation, and supersede stale in-flight work so the final rendered peaks and selection surfaces match the most recent user action. [L7]
11. The implementation must preserve correctness of settled results when deferred recomputation spans multiple rapid interactions. Older queued or in-flight selection-derived results must not overwrite a newer accepted state after they complete. [L3] [L7]
12. Treat the regression as fixed only after verification against the existing real migrated local post-`0024` data shape that currently reproduces the slowdown. Small deterministic fixtures alone are not sufficient for final signoff. [L5]

## Technical Decisions

1. Keep the current peak-list feature contract intact and solve this as a hot-path separation problem: move relational membership reads, list-summary recomputation, and peak-list visibility derivation off the immediate tap and per-frame camera paths rather than redesigning the selection model. [L2] [L3] [L4]
2. Reuse existing Flutter and Riverpod seams where possible. Prefer coalescing, caching, staged state updates, or end-of-motion refresh boundaries over introducing new user-facing loading states. [L2] [L3] [L4]
3. Treat continuous map motion and discrete selection changes as independent performance boundaries. Camera updates may keep transient live-map state while deferring peak-list-dependent work until motion settles, but discrete selection controls still need immediate visual acknowledgment. [L3] [L4] [L6]
4. On `My Peak Lists`, solve the regression by moving membership-derived list filtering and summary derivation out of repeated synchronous widget-build reads and behind an app-owned state-management seam that can defer and supersede refresh work while preserving the current settled screen contract. [L3] [L6] [L7]
5. `Latest interaction wins` is the authoritative concurrency rule for rapid peak-list or region-filter changes. Any deferred refresh pipeline must be cancellable or supersedable at the state-management layer so stale completions cannot overwrite newer accepted state. [L7]
6. Preserve existing source-of-truth data and migrated relational membership semantics from `0024`; this slice optimizes when derived reads happen, not what data is considered authoritative. [L2] [L5]

## Testing Strategy

1. Add deterministic widget-level regression coverage proving `Map` zoom and pan no longer force peak-list-dependent recomputation on every camera tick, or otherwise proving the expensive membership-derived work is decoupled from the camera hot path. Reuse existing map rebuild or debug-counter seams where possible. [L4] [L8]
2. Add deterministic widget or provider regression coverage proving rapid `Map` `Peak Lists` drawer selections and `My Peak Lists` `Region FAB` taps obey `latest interaction wins` and do not allow stale recomputation to overwrite newer state. [L7] [L8]
3. Keep automated coverage on deterministic fixtures, fakes, provider overrides, and existing test seams rather than real large datasets, wall-clock latency assertions, or live local-data dependencies in CI. [L5] [L8]
4. Any deferred recomputation pipeline added for `Map` or `My Peak Lists` must expose a deterministic automated-test seam that lets tests control completion order and prove stale work is superseded without relying on wall-clock latency assertions. [L7] [L8]
5. Do not require fragile time-based performance assertions in automated tests. Verify behavior through decoupled rebuild or recomputation boundaries, supersession semantics, and correct settled state instead. [L8]
6. Perform final manual verification against the real migrated local post-`0024` peak-list data that currently reproduces the slowdown, confirming smooth `Map` pan and zoom, near-immediate `Peak Lists` drawer feedback, and near-immediate `Region FAB` feedback on the normal development machine. [L5] [L6] [L8]

## Out of Scope

1. Redesigning `Map` peak-list selection UX, region-filter UX, labels, chip semantics, or visibility rules. [L2]
2. Adding new general loading or disabled-state UI for the affected controls unless correctness leaves no smaller alternative. [L2] [L3]
3. Reworking the already responsive `Peak list mini-map` path unless implementation proves it unexpectedly shares the same regression source. [L1]
4. Changing the relational membership source-of-truth contract introduced by `0024`. [L5]
5. Introducing CI wall-clock performance gates or benchmark infrastructure as the primary regression proof for this slice. [L8]

## Notes

1. Relevant current hotspots and seams likely include `lib/providers/peak_list_selection_provider.dart`, `lib/services/peak_list_visibility.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `lib/screens/peak_lists_screen.dart`, `lib/screens/map_screen.dart`, and `lib/services/peak_list_repository.dart`.
2. The current codebase already has map rebuild and interaction coverage such as `test/widget/map_screen_rebuild_test.dart`, `test/widget/map_peak_list_selection_test.dart`, `test/widget/peak_lists_screen_test.dart`, and related peak-list or map widget tests that should be extended instead of introducing entirely new test styles.
3. This slice is explicitly downstream of `ai_specs/peak-lists/0024-peak-list-membership-performance-and-export-responsiveness/spec.md` and should preserve its relational membership contract while repairing the new responsiveness regression.
