---
type: Work Item
title: Enforce Tasmania-Only Tassy Full Direct Add Flow
parent: ../spec.md
---

## What to build

Update the direct `Tassy Full` add flow so only Tasmanian peaks can be added. In the `Add New Peak` flow for the exact list name `Tassy Full`, hide non-Tasmanian peaks from search results rather than showing them as invalid options. Keep direct point edits and direct deletions for Tasmanian peaks allowed. Add defense-in-depth validation behind the filtered UI so that if a non-Tasmanian peak still reaches the `Tassy Full` save path through an unexpected route, the add fails before the first write, the list remains unchanged, and the app shows `Peak List Update Failed` with the exact message `Tassy Full only accepts Tasmanian peaks.`. Multi-select adds to `Tassy Full` must validate the full submission before the first write and fail atomically when any selected peak is non-Tasmanian.

## Required context

- `lib/widgets/peak_list_peak_dialog.dart` owns the `Add New Peak` UI, search result shaping, selected-peak state, current multi-add save loop, and the existing `Peak List Update Failed` dialog surface.
- `lib/services/peak_list_repository.dart` owns `addPeakItem(...)`; use the existing repository/service pattern for defense-in-depth validation instead of relying only on widget filtering.
- Current widget coverage for the add flow and selectors lives in `test/widget/peak_list_peak_dialog_test.dart` and `test/widget/peak_lists_screen_test.dart`. Reuse the existing stable keys such as `peak-list-peak-search-input`, `peak-multi-select-row-<id>`, `peak-multi-select-checkbox-<id>`, `peak-list-peak-save`, and `peak-list-peak-failure-close`.
- Keep the implementation within the existing Riverpod, repository, and dialog-helper patterns. Avoid a separate test-infrastructure item; extend the current widget-focused seams directly.

## Acceptance criteria

- [ ] In the `Add New Peak` flow for the exact peak-list name `Tassy Full`, non-Tasmanian peaks are hidden from search results rather than shown as selectable invalid options.
- [ ] `Tassy Full` direct add flows enforce the Tasmania-only rule and do not allow non-Tasmanian peaks to be added.
- [ ] In `Tassy Full` multi-select add submissions, validation happens before the first write. If any selected peak is non-Tasmanian, the entire submission fails with no list changes.
- [ ] If a non-Tasmanian peak still reaches the `Tassy Full` save path through an unexpected route, the add fails without changing the list and shows `Peak List Update Failed` with the exact message `Tassy Full only accepts Tasmanian peaks.`.
- [ ] Direct point edits and direct deletions for Tasmanian peaks in `Tassy Full` remain allowed. A later manual refresh may restore a deleted Tasmanian peak only when that peak is still present in source peak lists.
- [ ] Widget coverage proves the filtered add-dialog behavior, atomic failure for invalid `Tassy Full` multi-add submissions, and the exact fallback failure message `Tassy Full only accepts Tasmanian peaks.` using the existing stable dialog selectors and deterministic test seams.

## Covers

- User Stories: 2
- Requirements: 14-18
- Technical Decisions: 4-6
- Testing Strategy: 1, 4
- Interview Ledger: L3, L5, L7

## Blocked by

None - ready to start
