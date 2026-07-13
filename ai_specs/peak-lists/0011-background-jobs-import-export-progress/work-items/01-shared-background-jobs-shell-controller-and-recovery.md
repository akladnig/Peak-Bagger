---
type: Work Item
title: Shared Background Jobs Shell, Controller, and Recovery
parent: ../spec.md
---

## What to build
Build the shell-owned `Background Jobs` foundation for the four in-scope import/export flows: a shared controller/state model for one running job plus retained finished entries, the shared app-bar entry, the non-modal right-side overlay panel, dismiss and `Clear finished` behavior, single-flight blocking, and interrupted-job recovery on next launch. This slice must keep the jobs surface separate from `Scaffold.endDrawer` reuse, preserve current-session-only history, and provide the one-time recovered-cancellation snackbar with `Open Jobs` without auto-opening the panel.

## Required context
- `lib/router.dart` owns the shared shell app bar and is the required integration point for app-wide entry visibility and overlay chrome.
- `lib/screens/map_screen.dart` already has map-specific right-edge drawer and dismissal behavior. This item must keep `Background Jobs` as shell overlay chrome rather than repurposing map drawer state.
- Existing persistence patterns already use `SharedPreferences` in providers such as `lib/providers/map_provider.dart` and theme/settings providers. Recovery metadata for interrupted jobs should follow that lightweight pattern and remain scoped to interrupted-job reporting only.
- Existing widget coverage already asserts shared app-bar behavior via `shared-app-bar` and shell destination keys such as `nav-dashboard`, `nav-map`, `nav-peak-lists`, `nav-objectbox-admin`, and `nav-settings`.
- Follow the Spec's deterministic-test expectation: controller and widget coverage must use provider overrides and fakes, not live dialogs, filesystem access, network access, or API keys.

## Acceptance criteria
- [ ] Behavior-first TDD drives the shared jobs controller or equivalent shell-owned state before flow wiring, covering single-flight blocking, start/running/completed/failed/cancelled transitions, current-session retention, dismiss, and `Clear finished` behavior.
- [ ] The shared shell app bar exposes a `Background Jobs` entry only when a running or retained finished job exists in the current session, hides it when no jobs exist, and keeps it reachable from `Dashboard`, `Map`, `My Peak Lists`, `ObjectBox Admin`, and `Settings`.
- [ ] Opening `Background Jobs` shows a non-modal right-side shell overlay panel, not `Scaffold.endDrawer`, and the current screen remains usable while the panel is open.
- [ ] The panel lists the running job first and retained `completed`, `failed`, and `cancelled` jobs below it; running jobs are not dismissible; finished jobs can be dismissed individually or through panel-level `Clear finished`.
- [ ] When a user tries to start another in-scope background job while one is already `running`, the new start is blocked and a clear user-visible message names the running job without blocking same-session navigation.
- [ ] Failed jobs do not expose a `Retry` action, and the foundation does not retain replayable import/export inputs for retry behavior.
- [ ] If the app is terminated while a background job is running, the next launch restores one retained `cancelled` job entry plus a one-time snackbar such as `Import cancelled when app was closed` or `Export cancelled when app was closed`, includes `Open Jobs`, does not auto-open the jobs panel, and does not replay the same recovered interruption repeatedly after restoration.
- [ ] Widget coverage proves app-bar entry visibility, panel open/close behavior, running-first ordering, dismiss and `Clear finished`, and next-launch recovery snackbar behavior through deterministic provider-backed state rather than real background execution.

## Covers
- User Stories: 3, 5
- Requirements: 3-6, 15-17
- Technical Decisions: 1, 3-6
- Testing Strategy: 1-2, 4.1-4.3, 4.7, 7
- Interview Ledger: L2-L4, L6-L7, L11-L14

## Blocked by
None - ready to start
