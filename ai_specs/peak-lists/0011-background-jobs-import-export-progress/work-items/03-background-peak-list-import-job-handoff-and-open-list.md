---
type: Work Item
title: Background Peak List Import Job Handoff and Open List
parent: ../spec.md
---

## What to build
Integrate the existing `Import Peak List` flow with `Background Jobs` so an accepted import hands off immediately to the shared jobs system, closes the dialog, reports real `rows processed / total rows` progress for the selected CSV file, and finishes with jobs-panel details and snackbar actions instead of dialog-owned completion/failure surfaces. Extend the current peak-list import result contract only as needed so jobs can surface `ambiguous` counts and any `import.log` note/status, and support `Open List` navigation to `My Peak Lists` with the imported list selected when resolvable.

## Required context
- `lib/widgets/peak_list_import_dialog.dart` currently owns loading, duplicate-name confirmation, `Peak List Created` / `Peak List Updated`, and `Peak List Import Failed` dialogs. This item must preserve the pre-acceptance shell and duplicate-name behavior while moving accepted long-running ownership into `Background Jobs`.
- `lib/providers/peak_list_provider.dart` currently narrows the richer `PeakListImportService` result into `PeakListImportPresentationResult`. Extend that contract instead of inventing a second summary path if jobs-panel details need more fields.
- `lib/services/peak_list_import_service.dart` already provides service-level data such as `ambiguousCount`, warning entries, log entries, and `warningMessage`. Reuse those results for Requirement 18 details.
- `lib/router.dart` and `lib/screens/peak_lists_screen.dart` already support navigating to `My Peak Lists` with a selected list through the existing route/query path.
- Existing focused coverage starts in `test/services/peak_list_import_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart`. Keep fake CSV input, in-memory repositories, provider overrides, and stable selectors.

## Acceptance criteria
- [ ] After the user accepts `Import Peak List`, the dialog closes immediately, a running background job is created, and a lightweight started snackbar includes `Open Jobs`.
- [ ] The running peak-list import job shows real `rows processed / total rows` progress for the selected CSV file, includes the current file name, and shows a percent when total work is known.
- [ ] Accepted peak-list background jobs no longer show modal completion or failure dialogs; success and failure ownership moves to the jobs panel plus snackbar behavior while keeping the existing duplicate-name confirmation and pre-acceptance dialog flow.
- [ ] The jobs integration may extend the current UI-facing result contract so the completed peak-list import row can show imported, skipped, ambiguous, warnings, and any `import.log` note/status required by the Spec.
- [ ] Successful peak-list import completion does not auto-navigate away from the current screen. It may still select the imported list only when `My Peak Lists` is currently visible; otherwise it must not change the visible screen context.
- [ ] Success snackbar behavior uses `Import complete` plus a short counts summary and `Open Jobs`, and may include `Open List` when the imported list can be resolved. Tapping `Open List` navigates to `My Peak Lists` and selects the imported list.
- [ ] Failure snackbar behavior uses `Import failed` plus the first error summary and `Open Jobs`.
- [ ] Focused service/notifier coverage proves deterministic row-count progress and the extended completion summary contract, and widget coverage proves dialog close-on-accept, preserved duplicate-name flow, failure presentation through the background-job path, and `Open List` behavior through existing routing without real file dialogs or live filesystem dependencies.

## Covers
- User Stories: 1, 4
- Requirements: 1-2, 7, 10, 13-18
- Technical Decisions: 2-5
- Testing Strategy: 3.2, 4.4-4.6, 6
- Interview Ledger: L1-L2, L5, L8-L10, L14-L15

## Blocked by
- `01-shared-background-jobs-shell-controller-and-recovery.md`
