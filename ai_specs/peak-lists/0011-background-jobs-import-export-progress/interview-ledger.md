---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which user-facing flows should Phase 1 cover, and what durable term should the Spec use for this capability?

Recommended Answer:
- Use `background job` as the canonical term.
- Phase 1 covers `Import GPX File(s)`, `Import Peak List`, `Export Peak Data`, and `Export Peak Lists`.
- Do not include single-file GPX export from the map or ObjectBox admin screens in this slice.

Answer: agreed

Decision: Use `background job` as the canonical term for app-managed long-running import/export work, and limit Phase 1 scope to the four batch flows `Import GPX File(s)`, `Import Peak List`, `Export Peak Data`, and `Export Peak Lists`.

Negative Requirements:
- Do not include single-file GPX export from the map track/route UI.
- Do not include single-file GPX export from ObjectBox admin.

### L2

Status: current

Question: What should happen to a running import/export after the user leaves the initiating dialog or screen?

Recommended Answer:
- The job keeps running after the dialog closes or the user navigates to another screen.
- Job visibility must live in an app-wide shared surface rather than staying owned by the initiating screen.

Answer: agreed

Decision: Background jobs must keep running after the initiating dialog closes and while the user navigates elsewhere in the app, with visibility and control living in an app-wide shared surface rather than the initiating screen.

### L3

Status: current

Question: Should the app allow more than one import/export background job to run at the same time?

Recommended Answer:
- Allow only one running background job at a time in Phase 1.
- If the user starts another job while one is running, block it and show a clear message naming the running job.

Answer: agreed

Decision: Phase 1 background jobs are single-flight. Only one import/export job may be running at a time, and attempts to start another must be blocked with a clear message naming the running job.

### L4

Status: current

Question: Where should the shared background-job entry point live?

Recommended Answer:
- Put a `Background Jobs` entry point in the shared app bar.
- Show nothing when no jobs exist.
- Make it reachable from every shell destination when a running or retained finished job exists.

Answer: agreed

Decision: The shared shell app bar must expose the `Background Jobs` entry point whenever a running or retained finished job exists in the current session, and must show no entry when no jobs exist.

### L5

Status: current

Question: What exact progress contract should each background job show while running?

Recommended Answer:
- Always show job label, current file name when one file is being processed, and percent when total work is known.
- `Import GPX File(s)`: `files completed / total files`.
- `Import Peak List`: `rows processed / total rows`.
- `Export Peak Data`: `rows written / total peaks`.
- `Export Peak Lists`: `files completed / total lists`, plus current-file `rows written / total rows`.
- Do not fall back to a fake spinner once actual processing has started.

Answer: agreed

Decision: Background jobs must show real progress units matched to each flow, using file counts for GPX import, row counts for peak-list import, row counts for peak-data export, and file-plus-row progress for peak-list export.

### L6

Status: current

Question: What should happen if the app leaves the foreground or is closed while a background job is running?

Recommended Answer:
- Phase 1 supports in-app background only.
- Do not promise continued execution when the OS backgrounds the app.
- If the app is terminated, stop the work and recover it on next launch as cancelled with a clear message.

Answer: agreed

Decision: Phase 1 supports in-app background navigation only. App termination interrupts the job, and the next launch must recover it as cancelled with clear user-facing messaging.

Negative Requirements:
- Do not add platform background execution services in this slice.

### L7

Status: current

Question: Should a running background job be cancellable by the user?

Recommended Answer:
- Phase 1 jobs are not cancellable once started.

Answer: agreed

Decision: Phase 1 background jobs are run-to-completion operations once started and do not expose user cancellation controls.

### L8

Status: current

Question: How should completion affect app state when the user may be on another screen?

Recommended Answer:
- Do not auto-navigate to another screen on completion.
- Preserve data refreshes and useful selection side effects without stealing the user's current screen context.
- GPX import may still select the first imported track or route in app state.
- Peak-list import may select the imported list only if `My Peak Lists` is currently visible.

Answer: agreed

Decision: Background-job completion must not auto-navigate to another screen. GPX import may still select the first imported track or route in app state, and peak-list import may select the imported list only when `My Peak Lists` is currently visible.

### L9

Status: current

Question: Should the initiating UI stay open as a live progress view or hand off immediately to the shared jobs surface?

Recommended Answer:
- Hand off immediately to `Background Jobs`.
- Import dialogs close after the job is accepted.
- Export starts may keep the user on Settings, but progress ownership moves to `Background Jobs`.
- Show lightweight started messaging with an `Open Jobs` action.

Answer: agreed

Decision: Initiating UIs hand off immediately to the shared jobs surface after job acceptance. Import dialogs close, Settings may remain visible for exports, and start confirmation is lightweight rather than a second blocking progress UI.

### L10

Status: current

Question: How interruptive should completion notifications be when the user is elsewhere in the app?

Recommended Answer:
- Use a snackbar, not a modal popup, for success and failure completion notifications.
- Include `Open Jobs`.
- For successful peak-list import, optionally include `Open List` when the imported list can be resolved.

Answer: agreed

Decision: Background-job success and failure notifications must use snackbars rather than modal completion dialogs, with `Open Jobs` available and optional `Open List` for successful peak-list import when resolvable.

### L11

Status: current

Question: How long should completed and failed jobs remain visible in the shared jobs surface?

Recommended Answer:
- Keep finished jobs only for the current app session.
- Running jobs cannot be dismissed.
- Completed, failed, and cancelled jobs stay until the user dismisses them.
- Add panel-level `Clear finished`.

Answer: agreed

Decision: Background-jobs history is session-scoped. Running jobs are non-dismissible, and completed, failed, or cancelled jobs remain until the user dismisses them or uses `Clear finished`.

### L12

Status: current

Question: What exact surface should `Background Jobs` open from the shared app bar?

Recommended Answer:
- Open a non-modal right-side panel from the app shell.
- Let the user keep working while the panel stays open.
- Show the running job first and finished jobs below.

Answer: agreed

Decision: `Background Jobs` opens as a non-modal right-side panel in the shared app shell, with the running job pinned first and finished jobs listed below.

### L13

Status: current

Question: If a background job fails, should the jobs panel offer direct retry?

Recommended Answer:
- Do not offer `Retry` from the panel in Phase 1.
- Leave the failed job visible with details.
- Restart from the original entry point instead of retaining files, typed names, or export plans for replay.

Answer: agreed

Decision: Phase 1 failed jobs do not support panel retry. Users restart from the original entry point, and the jobs system does not retain replayable import/export inputs for retry.

### L14

Status: current

Question: How should the app classify jobs that finish with warnings, skipped items, unchanged items, unsupported items, or recoverable per-row/per-file errors?

Recommended Answer:
- Keep those jobs `completed` when they reach their normal end state.
- Use `failed` only for aborted jobs.
- Use `cancelled` only for interrupted app-closure recovery.

Answer: agreed

Decision: Jobs that reach their normal final summary remain `completed` even when they include warnings, skipped items, unchanged items, unsupported items, or recoverable per-row/per-file errors. `failed` is reserved for aborted jobs, and `cancelled` is reserved for interrupted app-closure recovery.

### L15

Status: current

Question: How much detail should each job show after completion?

Recommended Answer:
- Each row is compact by default with expandable details.
- GPX import details show added, unchanged, unsupported, errors, and warning message.
- Peak-list import details show imported, skipped, ambiguous, warnings, and any `import.log` note.
- Peak-data export details show rows written and destination path.
- Peak-list export details show files written, skipped lists, skipped rows, warnings, and destination directory.
- Do not dump raw logs into the panel in Phase 1.

Answer: agreed

Decision: Each background job row is compact by default with expandable flow-specific completion details, and Phase 1 excludes raw log viewing inside the jobs panel.
