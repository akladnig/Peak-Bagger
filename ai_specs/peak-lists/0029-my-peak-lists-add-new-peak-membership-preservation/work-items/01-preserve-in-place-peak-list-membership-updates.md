---
type: Work Item
title: Preserve In-Place Peak List Membership Updates
parent: ../spec.md
---

## What to build

Correct the `My Peak Lists` `Add New Peak` save path so adding peaks mutates the currently selected existing `PeakList` in place instead of replacing it by name or creating a new row. A successful save must preserve the selected list's existing `peakListId`, name, colour, and pre-existing memberships while appending only the newly chosen memberships from the current multi-select save and recomputing derived bounds and derived region from the combined membership set. On any repository or persistence failure during `Add New Peak`, the selected list must remain exactly as it existed before save began, with no partial removal, rewrite, or silent drop of existing memberships.

## Required context

- `lib/services/peak_list_repository.dart` already owns `PeakList` persistence, item-row mutations, derived-data recomputation, and duplicate-name save behavior. Keep the fix inside the existing repository seam and prefer the smallest correction that preserves the selected existing `PeakList.peakListId` as the source-of-truth identity for this flow.
- `lib/widgets/peak_list_peak_dialog.dart` currently drives the multi-select add submission through `addPeakItems(...)`. Align the repository contract with this live multi-select flow instead of changing the picker UX or visible picker contents.
- Existing deterministic repository coverage lives in `test/services/peak_list_repository_test.dart`. Reuse in-memory `PeakListStorage`, `PeakListItemEntityStorage`, and `PeakRepository` seams. If repository or persistence failure cannot be forced with the current seams, add the smallest dedicated failure seam needed for this slice.
- Treat `ai_specs/peak-lists/011-pl-add-edit.md` as stale for this flow. The current multi-select implementation is the canonical contract.

## Acceptance criteria

- [x] Behavior-first TDD coverage starts at the repository or service seam and proves adding peaks to a non-empty existing list preserves the original `peakListId`, existing memberships, name, and colour while recomputing derived bounds and derived region from the combined membership set.
- [x] A successful `My Peak Lists` `Add New Peak` save updates the currently selected existing `PeakList` in place rather than replacing it by name, creating a new `PeakList` row, or resetting the prior list identity to `0`.
- [x] A successful `My Peak Lists` `Add New Peak` save preserves all existing peak memberships already in the selected list and appends only the newly chosen memberships from the current multi-select save.
- [x] The repository path used by `Add New Peak` does not clear and repopulate the selected list in a way that drops pre-existing memberships.
- [x] On any repository or persistence failure during `Add New Peak`, the selected list remains exactly as it existed before save began, with no partial removal, rewrite, or silent drop of existing memberships.
- [x] Repository coverage proves atomic failure behavior for repository or persistence failures against the selected existing list without requiring filesystem dialogs, network calls, or secrets.

## Covers

- User Stories: 1, 3
- Requirements: 2-5, 7
- Technical Decisions: 1-2, 4
- Testing Strategy: 1, 4
- Interview Ledger: L1, L2

## Blocked by

None - ready to start
