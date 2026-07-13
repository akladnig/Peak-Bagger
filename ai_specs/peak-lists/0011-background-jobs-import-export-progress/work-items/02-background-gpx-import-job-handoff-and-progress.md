---
type: Work Item
title: Background GPX Import Job Handoff and Progress
parent: ../spec.md
---

## What to build
Integrate the existing `Import GPX File(s)` flow with `Background Jobs` so an accepted import hands off immediately to the shared jobs system, closes the dialog, continues while the user navigates across the shell, and reports real `files completed / total files` progress with current-file visibility and preserved completion details. This slice must replace dialog-owned completion/failure ownership for accepted GPX jobs with snackbar plus jobs-panel behavior while preserving the allowed first imported track or route selection side effect without auto-navigation to `Map`.

## Required context
- `lib/widgets/gpx_import_dialog.dart` currently owns the import spinner plus modal `Import Complete` and `Import Failed` dialogs. After job acceptance, this item must move long-running ownership out of that dialog rather than keeping a secondary live progress view.
- `lib/widgets/map_action_rail.dart` wires the existing `Import GPX File(s)` entry point and the `importAsRoute` toggle path that currently calls `mapProvider.importGpxFiles` or `mapProvider.importRouteFiles`.
- `lib/providers/map_provider.dart` owns current GPX track/route side effects, including selecting the first imported track or route in app state. Preserve those state updates while keeping completion non-navigating.
- Progress seams should stay close to existing GPX import logic and test seams in `mapProvider`/`GpxImporter`; avoid introducing an unrelated duplicate import service layer.
- Existing focused coverage starts in `test/widget/gpx_import_dialog_test.dart`, `test/providers/map_provider_import_test.dart`, and `test/robot/gpx_tracks/`. Keep provider overrides, fake file pickers, and deterministic GPX fixtures.

## Acceptance criteria
- [ ] After the user accepts `Import GPX File(s)`, the dialog closes immediately, a running background job is created, and a lightweight started snackbar includes `Open Jobs`.
- [ ] Once actual processing begins, the running GPX job shows real `files completed / total files` progress, the current file name when one file is being processed, and a percent when total work is known; it does not fall back to an indeterminate spinner after actual processing starts.
- [ ] Accepted GPX background jobs no longer show modal `Import Complete` or `Import Failed` dialogs; success and failure ownership moves to the jobs panel plus snackbar behavior.
- [ ] Successful GPX jobs do not auto-navigate to `Map`, but may still select the first imported track or route in app state.
- [ ] GPX job completion details in the jobs panel show added, unchanged, unsupported, errors, and warning message, and jobs that reach their normal final summary remain `completed` even when warnings, unchanged items, unsupported items, or recoverable per-file errors are present.
- [ ] Success snackbar behavior uses `Import complete` plus a short counts summary and `Open Jobs`; failure snackbar behavior uses `Import failed` plus the first error summary and `Open Jobs`.
- [ ] Focused notifier/service coverage proves deterministic GPX progress reporting and preserved completion summaries, and widget coverage proves dialog close-on-accept plus snackbar handoff without real file dialogs or live filesystem dependencies.

## Covers
- User Stories: 1, 4
- Requirements: 1-2, 7-9, 13-18
- Technical Decisions: 2-5
- Testing Strategy: 3.1, 4.4-4.6, 6
- Interview Ledger: L1-L2, L5, L8-L10, L14-L15

## Blocked by
- `01-shared-background-jobs-shell-controller-and-recovery.md`
