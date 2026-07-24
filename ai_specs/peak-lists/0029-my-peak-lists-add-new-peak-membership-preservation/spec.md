---
type: Spec
title: My Peak Lists Add New Peak Membership Preservation
---

## Problem

Adding peaks through `My Peak Lists` currently risks deleting all existing peaks from the selected list. The reported behavior also suggests the flow may be creating a replacement list identity instead of updating the selected existing `PeakList` in place. That turns a normal multi-select add into a data-loss regression for an established user-maintained list.

## Proposed Outcome

`My Peak Lists` `Add New Peak` keeps the current multi-select picker UX but saves against the selected existing `PeakList` in place. Successful saves preserve the same `peakListId` and all pre-existing memberships while appending the newly chosen peaks. Repository or persistence failures leave the selected list unchanged and continue to use the current failure surface.

## User Stories

1. As a user maintaining `My Peak Lists`, when I add peaks to an existing list, the list keeps all of its existing peaks and only gains the new selections.
2. As a user returning to the selected list after an add, I stay on the same list identity instead of having that list replaced or reset.
3. As a user who hits a repository or persistence failure during `Add New Peak`, I do not lose existing list memberships.

## Requirements

1. Scope this slice to the `My Peak Lists` `Add New Peak` regression. Preserve the current multi-select picker behavior and visible results for this flow; do not use this fix to redesign the picker UX. [L3]
2. Treat the currently selected existing `PeakList` as the source-of-truth list identity for `Add New Peak`. Saving this flow must update that same list in place rather than replacing it by name or creating a new list row. [L1]
3. A successful `Add New Peak` save must preserve the selected list's existing `peakListId`, name, colour, and selected-list continuity while recomputing derived bounds and derived region from the combined membership set after the add. [L1]
4. A successful `Add New Peak` save must preserve all existing peak memberships already in the selected list and append only the newly chosen memberships from the current multi-select save. [L1]
5. This flow must not reset the prior list identity to `0`, create a shadow replacement `PeakList`, or clear and repopulate the selected list in a way that drops pre-existing memberships. [L1]
6. After a successful add, `My Peak Lists` must refresh against the same selected list so the details pane reflects the combined membership set containing both the prior peaks and the newly added peaks. [L1]
7. On any repository or persistence failure during `Add New Peak`, the selected list must remain exactly as it existed before save began. Existing memberships must not be partially removed, rewritten, or silently dropped. [L2]
8. On a repository or persistence failure during `Add New Peak`, the app must preserve the same selected list identity, continue to use the current failure dialog path, keep the `Add New Peak` dialog open, and allow retry or cancel from the same add session rather than silently recovering by replacing the list. [L2]
9. On a repository or persistence failure during `Add New Peak`, the in-progress multi-select session must preserve the user's currently selected peaks and entered points so the user can retry without rebuilding the selection. [L2]
10. Treat `ai_specs/peak-lists/011-pl-add-edit.md` as stale for this flow. The current multi-select implementation is canonical for this slice, and the fix must not change what is currently visible in the picker. [L3]

## Technical Decisions

1. The source-of-truth identity for this regression is the selected existing `PeakList.peakListId` carried into the `Add New Peak` flow, not any name-based replacement behavior. [L1]
2. Keep the fix vertical through the current app-owned seams in `lib/widgets/peak_list_peak_dialog.dart`, `lib/screens/peak_lists_screen.dart`, and `lib/services/peak_list_repository.dart`; prefer the smallest correction that preserves list identity and memberships. [L1] [L3]
3. Reuse the current failure surface for save errors rather than introducing a new error UX for this regression, and keep the current add dialog session available for retry after repository or persistence failures. [L2]
4. Treat duplicate or otherwise defensively rejected selections as out of contract for this regression slice; the required atomicity guarantees apply to repository or persistence failures against the selected existing list. [L2]
5. Preserve the live multi-select add behavior as the canonical product contract for this slice even though older repo docs describe a different interaction. [L3]

## Testing Strategy

1. Use behavior-first TDD for the repository or service logic that handles `Add New Peak`, starting with coverage that proves adding peaks to a non-empty list preserves prior memberships and the original `peakListId` while recomputing derived bounds and derived region from the combined membership set. [L1]
2. Add regression coverage around the current `My Peak Lists` add flow proving a successful multi-select add keeps the same selected list identity and shows the prior peaks plus the newly added peaks after refresh. Prefer existing widget seams in `test/widget/peak_list_peak_dialog_test.dart` and `test/widget/peak_lists_screen_test.dart`. [L1] [L3]
3. Add regression coverage proving a forced repository or persistence failure leaves the selected list memberships unchanged, preserves the existing failure dialog path, keeps the `Add New Peak` dialog open, and retains the in-progress selected peaks and entered points for retry. [L2]
4. Prefer existing in-memory peak-list storage, repository test doubles, provider overrides, and stable widget selectors. If the current add path cannot be forced into a repository or persistence failure deterministically with those seams, add the smallest dedicated failure seam needed for this slice. Automated coverage must not require filesystem dialogs, network calls, or secrets. [L2] [L3]
5. Do not add new automated assertions that redesign or narrow the current picker contents for this slice; coverage should preserve the current multi-select behavior while verifying the data-safety regression fix. [L3]

## Out of Scope

1. Redesigning `Add New Peak` from multi-select to single-select.
2. Changing what is currently visible in the picker.
3. Reworking duplicate-prevention UX or picker filtering behavior beyond whatever is directly required to preserve existing memberships safely.
4. Unrelated `My Peak Lists`, import, export, or map-selection changes.

## Notes

1. Relevant current behavior and likely implementation surfaces include `lib/widgets/peak_list_peak_dialog.dart`, `lib/screens/peak_lists_screen.dart`, `lib/services/peak_list_repository.dart`, `test/services/peak_list_repository_test.dart`, `test/widget/peak_list_peak_dialog_test.dart`, and `test/widget/peak_lists_screen_test.dart`.
2. Earlier docs under `ai_specs/peak-lists/011-pl-add-edit.md` conflict with the live multi-select contract and should not drive this regression fix.
