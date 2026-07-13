---
type: Work Item
title: Cross-Shell Background Jobs Journey Coverage
parent: ../spec.md
---

## What to build
Add deterministic robot or journey coverage for the critical cross-shell `Background Jobs` behavior using at least one import journey and one export journey. The journeys must start a background job, navigate to another shell destination while the job runs, and verify durable progress, final summaries, snackbar actions, and retained panel behavior through stable key-first selectors.

## Required context
- Follow the existing robot structure under `test/robot/`, including focused robot helpers plus journey tests coordinated through deterministic provider overrides and fake completions.
- Reuse stable `Key` selector conventions for new shell and jobs-surface affordances, including the shared app-bar entry, jobs panel root, row state, dismiss action, `Clear finished`, and `Open Jobs`. If an `Open List` selector is included in shared jobs chrome, keep it app-owned and deterministic as well.
- This item should cover one import journey through `Import GPX File(s)` and one export journey through a Settings export flow so the selected dependencies remain sufficient.
- Keep the journeys local and deterministic; do not rely on real filesystem dialogs, live disk writes, network calls, or API keys.

## Acceptance criteria
- [ ] At least one deterministic journey starts `Import GPX File(s)`, hands off to `Background Jobs`, navigates to another shell destination while the job is still running, and verifies durable progress plus final summary through the shared jobs surface and snackbar behavior.
- [ ] At least one deterministic journey starts either `Export Peak Data` or `Export Peak Lists` from `Settings`, navigates to another shell destination while the export runs, and verifies durable progress plus final summary through the shared jobs surface and snackbar behavior.
- [ ] The robot coverage uses stable key-first selectors for the app-bar jobs entry, jobs panel root, running/finished row state, dismiss action, `Clear finished`, and snackbar `Open Jobs` affordances.
- [ ] The journeys assert that background-job completion does not auto-navigate the user away from the screen they are on while still allowing explicit snackbar actions to open the shared jobs surface.
- [ ] The journeys remain local and deterministic, backed by fakes, fixtures, or controllable progress emitters rather than live services or real OS-level background behavior.

## Covers
- User Stories: 1-4
- Requirements: 2, 5-7, 14, 16, 18
- Technical Decisions: 1-5
- Testing Strategy: 5-6
- Interview Ledger: L2, L4-L5, L9-L12, L15

## Blocked by
- `01-shared-background-jobs-shell-controller-and-recovery.md`
- `02-background-gpx-import-job-handoff-and-progress.md`
- `04-settings-export-background-jobs-for-peak-data-and-peak-lists.md`
