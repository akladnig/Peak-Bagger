---
type: Spec
title: Tassy Full Tasmania-Only Refresh
---

## Problem

`Tassy Full` currently behaves as an automatically refreshed super-set of every other peak list, which now conflicts with the intended project meaning of `Tassy Full` as a Tasmania-only list. The current behavior also allows non-Tasmanian peaks from lists such as `FVG 500` and `FVG Lesser Peaks` to appear in `Tassy Full`, and it keeps mutating `Tassy Full` as a side effect of unrelated peak-list edits. [L1][L2]

## Proposed Outcome

Keep `Tassy Full` as a project-managed Tasmania-only list. Remove automatic refresh from source-list mutations, keep the explicit Settings refresh action, rebuild that action around Tasmanian source peaks only, remove any non-Tasmanian peaks during refresh, and enforce the same Tasmania-only contract in the direct `Tassy Full` add flow. [L1][L2][L3][L6][L7]

## User Stories

1. As a user maintaining `Tassy Full`, I want the Settings refresh to use only Tasmanian source peaks so the list no longer pulls in peaks from non-Tasmanian lists. [L1][L2][L6]
2. As a user who curates `Tassy Full` directly, I want manual Tasmanian additions to remain possible while non-Tasmanian peaks are blocked, so the list stays trustworthy without losing local curation. [L3][L4][L5][L7]
3. As a user editing other peak lists, I do not want those edits to silently mutate `Tassy Full`, so `Tassy Full` changes only when I edit it directly or explicitly run its refresh action. [L1]

## Requirements

1. Treat the exact peak-list name `Tassy Full` as a special Tasmania-only list rather than an all-lists super-set. [L1]
2. Remove best-effort automatic `Tassy Full` refresh from non-`Tassy Full` peak-list mutation paths, including add, update, import, save, and delete flows. Those source-list mutations must still complete successfully without mutating `Tassy Full`. Removing that refresh must not remove the existing peak-list revision invalidation or active-selection reconciliation needed for the source-list UI to reflect the successful mutation. [L1]
3. Keep the Settings action title as `Update Tassy Full Peak List`. Change its subtitle to `Updates the Tassy Full Peak List using Tasmanian peaks from other peak lists`. [L6]
4. Keep the existing confirmation flow for the Settings action, but change the confirmation message to `This will update Tassy Full using Tasmanian peaks from other peak lists and remove non-Tasmanian peaks. Do you wish to proceed?` [L6]
5. Manual refresh must continue to exclude `Tassy Full` itself from the source aggregation set. [L1]
6. Manual refresh must use each peak's stored `Peak.region` value as the membership source of truth. A peak is eligible for source-backed inclusion in `Tassy Full` only when `Peak.region == 'tasmania'`, even if it appears in another peak list. [L2]
7. Manual refresh must exclude non-Tasmanian peaks from source aggregation, including peaks coming from non-Tasmanian lists such as `FVG 500` and `FVG Lesser Peaks`. [L1][L2]
8. Manual refresh must remove any existing non-Tasmanian peaks already stored in `Tassy Full`. [L3][L5]
9. If `Tassy Full` does not exist when manual refresh runs, the refresh must recreate it from the Tasmania-only refresh result. [L1][L2]
10. Manual refresh must preserve any existing Tasmanian peaks already stored in `Tassy Full` when those peaks are absent from all source peak lists. [L4]
11. Manual refresh must re-add any Tasmanian peak that is present in source peak lists, even if the user had previously deleted that peak directly from `Tassy Full`. [L5]
12. When the same Tasmanian peak appears in multiple source peak lists, manual refresh must dedupe by `peakOsmId` and keep the highest source `points` value for that source-backed peak. [L4][L5]
13. When a Tasmanian source-backed peak already exists in `Tassy Full`, manual refresh must overwrite its stored `points` value with the refresh result derived from source peak lists. Tasmanian peaks preserved only because they already exist in `Tassy Full` must keep their existing stored `points` value. [L4][L5]
14. `Tassy Full` direct add flows must enforce the Tasmania-only rule. Non-Tasmanian peaks must not be addable to `Tassy Full`. [L3][L7]
15. In the `Add New Peak` flow for `Tassy Full`, non-Tasmanian peaks must be hidden from the search results rather than shown as selectable invalid options. [L7]
16. If a non-Tasmanian peak still reaches the `Tassy Full` save path through an unexpected route, the add must fail without changing the list and must show `Peak List Update Failed` with the exact message `Tassy Full only accepts Tasmanian peaks.` [L3][L7]
17. In `Tassy Full` multi-select add submissions, validation must happen before the first write. If any selected peak is non-Tasmanian, the entire submission must fail with no list changes. [L3][L7]
18. Direct point edits and direct deletions for Tasmanian peaks in `Tassy Full` remain allowed. A later manual refresh may restore a deleted Tasmanian peak only when that peak is still present in source peak lists. [L5]
19. After a successful manual `Tassy Full` refresh, the app must continue to invalidate peak-list consumers and reconcile any active peak-list selection so the UI reflects the updated list immediately. [L6]
20. After a successful manual `Tassy Full` refresh, the success result shown to the user must report removed non-Tasmanian peaks alongside added and updated counts. [L3][L6]
21. If manual refresh fails, the app must keep the existing `Tassy Full` data unchanged and continue to show the existing failure dialog pattern. [L6]

## Technical Decisions

1. Use `Peak.region` rather than `PeakList.region` as the source of truth for deciding whether a peak is Tasmanian enough to belong in `Tassy Full`. This keeps membership tied to peak data even when a source list contains mixed-region entries. [L2]
2. Keep the explicit Settings action as the only repository-driven refresh entry point for `Tassy Full`; remove the provider-level auto-refresh wrapper behavior instead of adding a second opt-out path. [L1]
3. Extend the refresh logic so it can inspect peak region data through an existing peak-source seam, such as `PeakRepository` or `PeakSource`, rather than duplicating region lookup logic in the UI. [L2][L7]
4. Keep the implementation within the existing Riverpod, repository, and dialog-helper patterns. No new persistence layer, schema change, or parallel `Tassy Full` state model is needed. [L1][L6]
5. Keep direct-edit validation as a defense in depth behind the filtered add dialog, so the Tasmania-only contract remains enforced even if future flows bypass the filtered search UI. [L3][L7]
6. Keep `Tassy Full` multi-add atomic by validating the full submission before the first write rather than relying on partial success or rollback. [L3][L7]

## Testing Strategy

1. Extend existing focused regression coverage rather than introducing a separate test harness style. Cover logic, provider behavior, widget behavior, and the existing critical Settings journey. [L1][L2][L6][L7]
2. Service-level tests should cover Tasmania-only filtering by `Peak.region`, removal of existing non-Tasmanian `Tassy Full` peaks, recreation of a missing `Tassy Full`, preservation of existing Tasmanian target-only peaks, re-adding deleted source-backed Tasmanian peaks, and highest-points precedence across multiple source lists. [L2][L3][L4][L5]
3. Provider-level tests should verify that non-`Tassy Full` list mutations no longer refresh `Tassy Full`, while the source mutation itself still succeeds and still performs any existing revision or selection updates required by that source flow. Include at least one flow that previously depended on the auto-refresh wrapper for list invalidation rather than only for `Tassy Full` mutation. [L1]
4. Widget tests should cover the updated Settings subtitle and confirmation copy, success and failure refresh dialogs, removed-count reporting in the success dialog, `Tassy Full` add-dialog filtering of non-Tasmanian peaks, atomic failure for invalid `Tassy Full` multi-add submissions, and the exact fallback failure message `Tassy Full only accepts Tasmanian peaks.` [L6][L7]
5. Robot coverage should keep the existing Settings refresh journey, including the unchanged title, changed supporting copy, and successful refresh result reporting. It does not need a separate robot journey for hidden invalid peaks if widget coverage proves the filtered add-dialog behavior. [L6][L7]
6. Prefer deterministic seams already present in the codebase, including `PeakListRepository.test(InMemoryPeakListStorage(...))`, provider overrides, and in-memory peak sources or repositories instead of real services. [L2][L6][L7]

## Out of Scope

1. Renaming `Tassy Full`.
2. Changing the behavior of non-`Tassy Full` peak lists beyond removing their automatic influence on `Tassy Full`.
3. Migrating or correcting stored peak region data outside the scope needed for `Tassy Full` membership enforcement.
4. Adding new navigation routes, new settings surfaces, or a new state-management layer for peak lists.
