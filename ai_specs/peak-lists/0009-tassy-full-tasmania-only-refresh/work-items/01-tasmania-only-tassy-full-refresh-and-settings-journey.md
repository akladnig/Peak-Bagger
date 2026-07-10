---
type: Work Item
title: Tasmania-Only Tassy Full Refresh And Settings Journey
parent: ../spec.md
---

## What to build

Rework the explicit `Update Tassy Full Peak List` path so `Tassy Full` is refreshed only from Tasmanian source peaks. Keep the existing Settings entry point and confirmation flow, but update its supporting copy to the exact Spec text. The refresh must continue to exclude `Tassy Full` itself from the source set, use stored `Peak.region` as the membership source of truth, recreate a missing `Tassy Full`, remove existing non-Tasmanian peaks from `Tassy Full`, preserve existing Tasmanian peaks already stored in `Tassy Full` when they are absent from all source peak lists, re-add deleted source-backed Tasmanian peaks, dedupe source-backed peaks by `peakOsmId`, keep the highest source `points` value, overwrite `points` for existing source-backed peaks, preserve `points` for target-only Tasmanian peaks, keep failure behavior atomic, and show added, updated, and removed counts after a successful refresh.

## Required context

- `lib/services/tassy_full_peak_list_sync_service.dart` is the current refresh seam and already owns `Tassy Full` aggregation, target replacement, and the `TassyFullPeakListSyncResult` shape.
- `lib/services/peak_list_repository.dart` exposes `refreshTassyFullPeakList()` and is the right repository seam to keep the Settings action out of storage details.
- `lib/screens/settings_screen.dart` contains the visible tile copy, confirmation dialog, success/failure dialogs, and the post-refresh `peakListRevisionProvider` increment plus `mapProvider.reconcileSelectedPeakList()` call.
- Keep region lookup behind an existing data seam instead of reimplementing it in the widget layer. Follow the Spec's repository/service direction rather than adding a new persistence layer or parallel state model.
- Existing focused coverage lives in `test/services/tassy_full_peak_list_sync_service_test.dart`, `test/widget/tassy_full_peak_list_settings_test.dart`, `test/robot/peaks/tassy_full_refresh_robot.dart`, and `test/robot/peaks/peak_refresh_journey_test.dart`. Keep the current deterministic in-memory style and stable robot selectors.

## Acceptance criteria

- [ ] The manual `Tassy Full` refresh path treats the exact peak-list name `Tassy Full` as the special target list, excludes `Tassy Full` itself from source aggregation, and only includes source-backed peaks whose stored `Peak.region == 'tasmania'`.
- [ ] The refresh removes any existing non-Tasmanian peaks already stored in `Tassy Full`, recreates `Tassy Full` when it is missing, preserves existing Tasmanian peaks already stored in `Tassy Full` when they are absent from all source peak lists, and re-adds any Tasmanian peak that is still present in source peak lists even if the user had previously deleted it directly from `Tassy Full`.
- [ ] When the same Tasmanian peak appears in multiple source peak lists, the refresh dedupes by `peakOsmId`, keeps the highest source `points` value, overwrites `points` for existing source-backed `Tassy Full` peaks, and preserves the stored `points` value for Tasmanian peaks kept only because they already exist in `Tassy Full`.
- [ ] If manual refresh fails, the existing `Tassy Full` data remains unchanged and the app continues to show the existing failure dialog pattern.
- [ ] The Settings tile keeps the title `Update Tassy Full Peak List`, changes its subtitle to `Updates the Tassy Full Peak List using Tasmanian peaks from other peak lists`, and changes the confirmation message to `This will update Tassy Full using Tasmanian peaks from other peak lists and remove non-Tasmanian peaks. Do you wish to proceed?`.
- [ ] After a successful manual refresh, the app still invalidates peak-list consumers and reconciles any active peak-list selection so the UI reflects the updated list immediately.
- [ ] After a successful manual refresh, the success result shown to the user reports removed non-Tasmanian peaks alongside added and updated counts.
- [ ] Service-level tests cover Tasmania-only filtering by `Peak.region`, removal of existing non-Tasmanian `Tassy Full` peaks, recreation of a missing `Tassy Full`, preservation of existing Tasmanian target-only peaks, re-adding deleted source-backed Tasmanian peaks, and highest-points precedence across multiple source lists.
- [ ] Widget tests cover the updated Settings subtitle and confirmation copy, success and failure refresh dialogs, and removed-count reporting in the success dialog.
- [ ] Robot coverage keeps the existing Settings refresh journey, including the unchanged title, changed supporting copy, successful refresh result reporting, and stable selectors/deterministic seams already used by the existing robot tests.

## Covers

- User Stories: 1, 2
- Requirements: 3-13, 18-21
- Technical Decisions: 1, 3-5
- Testing Strategy: 1-2, 4-6
- Interview Ledger: L1-L6

## Blocked by

None - ready to start
