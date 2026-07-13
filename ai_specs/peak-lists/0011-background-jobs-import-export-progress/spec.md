---
type: Spec
title: Background Jobs for Import/Export Progress
---

## Problem

Peak Bagger's current batch import/export flows report progress only inside their initiating dialog or screen-local status area. `Import GPX File(s)` and `Import Peak List` use local loading spinners, while `Export Peak Data` and `Export Peak Lists` rely on Settings status text. That means users cannot start one of these longer-running operations, navigate elsewhere in the app, and still keep durable visibility into actual progress or later completion state. The current behavior also hides useful work units such as file counts and row counts behind indeterminate spinners or coarse final summaries. [L1] [L2] [L5]

## Proposed Outcome

Add an app-wide `Background Jobs` capability for the four in-scope batch import/export flows. Starting one of these flows creates a single running background job that survives dialog close and same-session navigation, reports real progress in user-meaningful units, and finishes with a durable panel entry plus non-modal completion snackbar messaging. The shared shell app bar becomes the stable access point, and the current screen-local progress ownership in dialogs and Settings is replaced by a non-modal right-side jobs panel without introducing platform background execution, concurrent jobs, cancellation, retry queues, or persistent job history. [L1] [L2] [L3] [L4] [L6] [L7] [L9] [L10] [L11] [L12] [L13]

## User Stories

1. As a user starting `Import GPX File(s)` or `Import Peak List`, I can close the initiating dialog, move to another screen, and still see actual progress for the work I started. [L1] [L2] [L5] [L9]
2. As a user starting `Export Peak Data` or `Export Peak Lists`, I can leave Settings while the export runs and later check a shared background-jobs surface instead of returning to the original screen. [L1] [L2] [L9]
3. As a user, I can open a shared `Background Jobs` panel from anywhere in the main app shell to see the running job first, inspect finished job details, and clear or dismiss finished entries when I no longer need them. [L4] [L11] [L12] [L15]
4. As a user, I get lightweight completion messaging that does not interrupt unrelated work, while still letting me open the jobs panel or relevant imported list when useful. [L8] [L10] [L15]
5. As a user whose app is closed mid-job, I am told on next launch that the in-flight work was cancelled rather than silently losing the operation. [L6] [L11] [L14]

## Requirements

1. Use `Background job` as the canonical project term for app-managed long-running import/export work with shared status not tied to the initiating screen. This slice covers only `Import GPX File(s)`, `Import Peak List`, `Export Peak Data`, and `Export Peak Lists`. It does not cover single-file GPX export from the map or ObjectBox admin screens. [L1]
2. Starting any in-scope flow must create one app-managed background job that continues after the initiating dialog closes and while the user navigates between the main shell destinations `Dashboard`, `Map`, `My Peak Lists`, `ObjectBox Admin`, and `Settings`. The app must not block same-session navigation while a background job is running. [L2]
3. Phase 1 is in-app background only. The feature must not promise continued execution when the OS backgrounds the app, and it must not add platform-level background execution services. If the app is terminated while a background job is running, the work stops and the next launch must recover that interrupted job as a retained `cancelled` job entry plus a one-time snackbar such as `Import cancelled when app was closed` or `Export cancelled when app was closed`. That recovery snackbar must include `Open Jobs`, must not auto-open the jobs panel, and the recovered cancelled job remains until dismissed or cleared like other finished jobs. [L6]
4. Only one import/export background job may be in `running` state at a time. If the user tries to start another in-scope import/export while one is already running, block the new start and show a clear user-visible message naming the running job. This block must not prevent the user from navigating elsewhere in the app. [L3]
5. The shared shell app bar must expose a `Background Jobs` entry point whenever a running or retained finished job exists in the current app session, and must show no jobs entry when no such jobs exist. This entry point must be reachable from every shell destination. [L4]
6. Opening `Background Jobs` must show a non-modal right-side panel in the shared app shell rather than a modal dialog. This panel is shell-owned overlay chrome, not a screen-owned `Scaffold.endDrawer`, and it must remain available from every shell destination without repurposing map-specific drawer state. The user must be able to keep working in the current screen while the panel remains open. The running job appears first, and completed, failed, or cancelled jobs appear below it. While the jobs panel is open, dismissal actions such as Escape or an explicit close control close the jobs panel before lower-priority shell surfaces. [L12]
7. Starting handoff must be immediate. `Import GPX File(s)` and `Import Peak List` dialogs close after the job is accepted. `Export Peak Data` and `Export Peak Lists` may leave the user on Settings, but ongoing progress ownership moves to `Background Jobs` rather than staying owned by the Settings status area. Each accepted start must show lightweight started messaging with an `Open Jobs` action. [L9]
8. Once actual processing has started, background-job UI must show real progress rather than only an indeterminate spinner. Each running job row must show the job label, the current file name when a single file is being processed, and a percent when total work is known. [L5]
9. `Import GPX File(s)` progress must report `files completed / total files`. GPX import does not need a row-based progress unit. [L5]
10. `Import Peak List` progress must report `rows processed / total rows` for the selected CSV file. [L5]
11. `Export Peak Data` progress must report `rows written / total peaks` for the generated `peaks.csv` file. [L5]
12. `Export Peak Lists` progress must report both `files completed / total lists` and the current file's `rows written / total rows`. [L5]
13. Background-job completion must not auto-navigate the user to another screen. Successful GPX import may still select the first imported track or route in app state, but must not force navigation to Map. Successful peak-list import may still select the imported list only when `My Peak Lists` is currently visible; otherwise it must not change the user's visible screen context. [L8]
14. Success and failure completion notifications for background jobs must use snackbars rather than modal completion dialogs. Success snackbars should communicate `Import complete` or `Export complete` plus a short counts summary. Failure snackbars should communicate `Import failed` or `Export failed` plus the first error summary. Completion snackbars must include `Open Jobs`, and successful peak-list import may also include `Open List` when the imported list can be resolved. Tapping `Open List` must navigate to `My Peak Lists` and select the imported list; completion itself remains non-navigating unless the user taps that action. Detailed summaries stay in the jobs panel entry. [L10]
15. Jobs that reach their normal final summary remain `completed` even when they include warnings, skipped items, unchanged items, unsupported items, or recoverable per-row/per-file errors. Use `failed` only when the job aborts before that normal final summary can be produced. Use `cancelled` only for recovered app-closure interruption. Completed jobs with warnings must show a warning indicator and warning details rather than being promoted to failed. [L14]
16. Background-jobs history is session-scoped. Running jobs cannot be dismissed. Completed, failed, and cancelled jobs stay visible until the user dismisses them individually or uses a panel-level `Clear finished` action. On relaunch, finished-job history is otherwise empty except for any recovered cancelled state needed to report the interrupted in-flight job. [L11]
17. Phase 1 background jobs are not user-cancellable once started, and failed jobs must not offer a `Retry` action in the jobs panel. Users restart failed work from the original entry point. The jobs system must not retain selected files, typed peak-list names, or prepared export plans solely to support retry. [L7] [L13]
18. Each jobs-panel row must be compact by default and expandable for details. Expanded details must be flow-specific: GPX import shows added, unchanged, unsupported, errors, and warning message; peak-list import shows imported, skipped, ambiguous, warnings, and any `import.log` note; peak-data export shows rows written and destination path; peak-list export shows files written, skipped lists, skipped rows, warnings, and destination directory. Raw log viewing is out of scope for the panel in Phase 1. [L15]

## Technical Decisions

1. Implement an app-wide background-job orchestration layer owned by shared shell state rather than keeping progress ownership inside each initiating dialog or screen. The shell integration point should align with the existing shared app bar and shell chrome in `lib/router.dart`. [L2] [L4] [L9] [L12]
2. Reuse existing flow entry points and seams where possible: `GpxImportDialog`, `PeakListImportDialog`, `peakCsvExportRunnerProvider`, `peakListCsvExportRunnerProvider`, `mapProvider.importGpxFiles`, `peakListImportRunnerProvider`, existing repository/provider seams, file-writer seams, and dialog/provider overrides used by current tests. Extend these flows with deterministic progress reporting rather than introducing unrelated duplicate service layers. Where the existing UI-facing result contracts are too narrow for jobs-panel details, this slice may extend those contracts instead of inventing duplicate summary paths. In particular, peak-list import jobs must be able to surface `ambiguous` counts plus any `import.log` note/status needed by Requirement 18. [L1] [L5] [L9]
3. Normalize app-wide job state around a single running job plus retained finished job entries, while preserving each flow's existing result counts, warning surfaces, and state side effects. The jobs system is an orchestration layer, not a replacement data model for GPX import, peak-list import, or export result contracts. [L3] [L8] [L14] [L15]
4. Keep the app-wide jobs surface non-modal and shell-owned. Implement it as shell overlay chrome rather than `Scaffold.endDrawer` reuse. Do not make Settings the long-term owner of export progress, and do not keep import dialogs alive as secondary live progress views after job acceptance. [L2] [L9] [L12]
5. Add or extend progress seams only where needed to observe actual work units safely in tests and UI. Prefer callbacks, streams, or notifier-friendly progress models that can be faked in tests over polling or UI-derived progress. Automated tests must not require real file pickers, live filesystem dialogs, network access, or API keys. [L5]
6. If app-closure recovery needs lightweight persisted metadata to show the recovered `cancelled` state on next launch, keep that persistence minimal and scoped to interrupted-job reporting only. It must not become persistent job history, background resumption, or a retry queue. That metadata must support one-time launch messaging plus creation of the recovered cancelled job row, and must not replay repeatedly once the interruption has been restored for the session. [L6] [L11] [L13]

## Testing Strategy

1. Use behavior-first TDD for the background-job orchestration and progress normalization logic before wiring every entry point.
2. Add unit or service coverage for the shared jobs controller or equivalent shell-owned state covering:
   1. single-flight blocking when a job is already running [L3]
   2. start, running, completed, failed, and cancelled state transitions [L6] [L14]
   3. current-session retention, dismiss, and `Clear finished` behavior [L11]
   4. progress payload normalization for each in-scope flow [L5]
3. Extend service or notifier coverage for the four in-scope flows so automated tests can assert real progress units and preserved completion summaries:
   1. GPX import file-count progress plus existing added/unchanged/unsupported/error summary behavior [L5] [L8] [L15]
   2. peak-list import row-count progress, warning handling, and `import.log` note handling [L5] [L15]
   3. peak-data export row-count progress and destination path summary [L5] [L15]
   4. peak-list export file-count plus current-file row-count progress and warning/skip summaries [L5] [L15]
4. Add widget coverage for the shared shell and entry surfaces covering:
   1. shared app bar jobs-entry visibility when jobs exist versus when none exist [L4]
   2. non-modal right-side panel open and close behavior [L12]
   3. running job listed first, finished jobs below, and panel actions for dismiss and `Clear finished` [L11] [L12]
   4. import dialogs closing on accepted start and exports handing off progress ownership away from Settings-only status UI [L9]
    5. snackbars for start, completion, and failure with `Open Jobs` and optional `Open List` actions [L10]
    6. no auto-navigation on completion, while preserving allowed selection side effects [L8]
    7. next-launch recovery snackbar behavior for interrupted jobs, including `Open Jobs` and no auto-opened panel [L6]
5. Extend robot or journey coverage for at least one import journey and one export journey that start a background job, navigate to another shell destination while the job runs, and verify durable progress plus final summary through the shared jobs surface and snackbar actions. Because this is a critical cross-shell user journey, keep stable key-first selectors for the app-bar entry, jobs panel, row state, dismiss and clear actions, and any `Open Jobs` or `Open List` affordances.
6. Prefer fake repositories, provider overrides, fake file pickers, fake export writers, and deterministic progress emitters. Automated tests must not depend on live disk dialogs, network calls, or secrets.
7. Add automated recovery coverage for interrupted jobs, including persisted recovery metadata write/read/clear behavior, restoration into a retained `cancelled` job entry on next launch, one-time launch snackbar behavior, and protection against replaying the same recovered interruption repeatedly within later launches or sessions.

## Out of Scope

1. Single-file GPX export from the map track or route UI. [L1]
2. Single-file GPX export from ObjectBox admin. [L1]
3. Multiple concurrent import/export jobs. [L3]
4. Platform background execution, OS notifications, or true background resume after app termination. [L6]
5. User cancellation controls for running jobs. [L7]
6. Panel-level retry for failed jobs or retained replayable import/export inputs. [L13]
7. Persistent job history beyond the current app session. [L11]
8. Raw log viewing inside the jobs panel. [L15]

## Notes

1. Relevant implementation files include `lib/router.dart`, `lib/screens/map_screen.dart`, `lib/widgets/gpx_import_dialog.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/widgets/map_action_rail.dart`, `lib/screens/peak_lists_screen.dart`, `lib/screens/settings_screen.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_provider.dart`, `lib/providers/peak_list_csv_export_provider.dart`, `lib/services/gpx_importer.dart`, `lib/services/peak_list_import_service.dart`, `lib/services/peak_csv_export_service.dart`, and `lib/services/peak_list_csv_export_service.dart`. [L1] [L2] [L5] [L9] [L12]
2. Relevant automated coverage starting points include `test/widget/gpx_import_dialog_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/widget/peak_csv_export_settings_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, `test/providers/map_provider_import_test.dart`, `test/services/peak_list_import_service_test.dart`, `test/services/gpx_export_service_test.dart`, `test/services/peak_list_csv_export_service_test.dart`, and the existing robot journeys under `test/robot/peaks/` and `test/robot/gpx_tracks/`. [L5] [L8] [L10] [L15]
