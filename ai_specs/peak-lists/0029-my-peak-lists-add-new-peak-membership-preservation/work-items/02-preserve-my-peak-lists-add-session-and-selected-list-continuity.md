---
type: Work Item
title: Preserve My Peak Lists Add Session And Selected-List Continuity
parent: ../spec.md
---

## What to build

Keep the current `My Peak Lists` `Add New Peak` multi-select picker UX exactly as it is today while wiring the dialog and `PeakListsScreen` refresh path to the corrected in-place save behavior. After a successful add, `My Peak Lists` must refresh against the same selected list so the details pane reflects the combined membership set containing both the prior peaks and the newly added peaks. On any repository or persistence failure during `Add New Peak`, the app must preserve the same selected list identity, continue to use the current `Peak List Update Failed` dialog path, keep the `Add New Peak` dialog open, and preserve the in-progress selected peaks and entered points so the user can retry or cancel from the same add session.

## Required context

- `lib/widgets/peak_list_peak_dialog.dart` owns the `Add New Peak` dialog title, multi-select state, entered points, save button, and the existing `Peak List Update Failed` failure dialog surface. Preserve the current visible picker behavior and dialog session state rather than redesigning the flow.
- `lib/screens/peak_lists_screen.dart` owns selected-list continuity, dialog launch, details-pane refresh, and post-save selected-peak handling for `My Peak Lists`. Keep refresh and navigation boundaries inside this seam.
- `lib/providers/peak_list_provider.dart` exposes `peakListMembershipRefreshRunnerProvider`, which already refreshes list-dependent UI and reconciles selected peak-list state. Reuse this deterministic seam before adding any new refresh pathway.
- Existing widget coverage and stable selectors live in `test/widget/peak_list_peak_dialog_test.dart` and `test/widget/peak_lists_screen_test.dart`. Reuse keys such as `peak-list-peak-dialog`, `peak-list-peak-save`, `peak-list-peak-failure-close`, `peak-list-peak-cancel`, `peak-list-peak-search-input`, `peak-selected-points-<id>`, `peak-selected-row-<id>`, and `peak-lists-selected-title`.
- If the current add path cannot be forced into a repository or persistence failure deterministically with provider overrides and in-memory repositories, add the smallest dedicated failure seam needed for this slice and keep it scoped to the existing widget test path.

## Acceptance criteria

- [x] The current `My Peak Lists` `Add New Peak` multi-select picker behavior and visible picker contents remain unchanged for this slice.
- [x] After a successful `Add New Peak` save, `My Peak Lists` refreshes against the same selected existing list identity and the details pane shows the combined membership set containing both the prior peaks and the newly added peaks.
- [x] After a successful `Add New Peak` save, the selected list preserves the same `peakListId`, name, colour, and selected-list continuity instead of being replaced or reset.
- [x] On any repository or persistence failure during `Add New Peak`, the app preserves the same selected list identity, continues to use the current `Peak List Update Failed` dialog path, and keeps the `Add New Peak` dialog open.
- [x] On any repository or persistence failure during `Add New Peak`, the in-progress multi-select session preserves the user's currently selected peaks and entered points so the user can retry without rebuilding the selection.
- [x] Widget regression coverage proves a successful multi-select add keeps the same selected list identity and visible results after refresh using the existing stable selectors and provider overrides.
- [x] Widget regression coverage proves a forced repository or persistence failure leaves the selected list memberships unchanged, keeps the `Add New Peak` dialog open, preserves the current failure dialog path, and retains the in-progress selected peaks and entered points for retry.
- [x] Automated coverage does not add new assertions that redesign or narrow the current picker contents for this slice.

## Covers

- User Stories: 1-3
- Requirements: 1, 6, 8-10
- Technical Decisions: 2-3, 5
- Testing Strategy: 2-5
- Interview Ledger: L1-L3

## Blocked by

- `01-preserve-in-place-peak-list-membership-updates.md`
