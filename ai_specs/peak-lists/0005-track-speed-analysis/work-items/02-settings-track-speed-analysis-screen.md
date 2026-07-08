---
type: Work Item
title: Settings Track Speed Analysis Screen
parent: ../spec.md
---

## What to build
Add the read-only `Track Speed Analysis` screen under `Settings` and wire it to the shared analysis seam from Work Item 01. The screen must start analysis automatically on first open, keep standard back navigation to `Settings`, render the four aggregate report sections with deterministic table ordering, preserve the last successful results during manual refresh, and expose the exact local loading, empty, and failure states and action behavior from the Spec.

## Required context
- `lib/screens/settings_screen.dart` is the entry point for the new `Track Speed Analysis` tile and already uses stable `Key` selectors plus local push navigation patterns for settings sub-screens.
- `lib/router.dart` shows the shell-navigation constraints. This feature stays under `Settings` and must not become a new top-level shell destination.
- Follow existing provider patterns under `lib/providers/` for screen state and injected services. The UI should own only screen state such as initial load, refresh progress, active-run disabling, stale-run protection, and error presentation.
- Use stable app-owned selectors for the settings tile, screen root, refresh action, loading indicator, empty state, error state, disabled active-run actions, and key report sections so widget and robot coverage stay deterministic.
- Existing widget tests under `test/widget/` consistently assert settings scrolling, loading/error states, and stable keys. Match those conventions instead of introducing ad hoc test hooks.
- `pubspec.yaml` shows no dependency change is expected for this UI slice; preserve existing Flutter/Riverpod/go_router patterns.

## Acceptance criteria
- [ ] `Settings` includes a new tile that opens a dedicated read-only `Track Speed Analysis` screen, uses standard back navigation to return to `Settings`, and does not add a new top-level shell destination.
- [ ] The screen starts analysis automatically on first open and provides a visible `Refresh Analysis` action that reruns the analysis against current local data.
- [ ] The first-load state shows the exact copy `Analysing tracks...`.
- [ ] The empty state shows the exact title `No analysis data yet`, the exact body copy `Import timestamped Tasmanian tracks and recalculate track statistics to build walking-speed analysis.`, and the exact action label `Refresh Analysis`.
- [ ] The failure state shows the exact title `Analysis failed`, a concise error summary in the body, and the exact action label `Retry`.
- [ ] During a manual refresh after at least one successful analysis run, the screen keeps the prior report visible while showing a lightweight in-progress indicator near `Refresh Analysis`, and a refresh does not blank the screen first when prior results exist.
- [ ] Only one analysis run may be active at a time; while analysis is running, `Refresh Analysis` and `Retry` are disabled, a stale completion from an older or superseded run does not overwrite newer visible state, and a completed run does not update disposed screen state after the user leaves the screen.
- [ ] The successful state renders exactly these aggregate sections in this order: speed by `track type`, speed by `hiking difficulty`, speed by `track type + hiking difficulty`, and speed by gradient band, with each section showing bucket label, median speed, sample count, total moving distance, and total moving time.
- [ ] The screen includes a short note that analysis uses the same filtered-track basis as current track statistics when available, so the user can understand why changing filter settings and running `Recalculate Track Statistics` can change report results.
- [ ] The UI remains usable on desktop and narrow/mobile layouts; if summary tables do not fit horizontally, the UI allows scrolling instead of clipping data, and large text settings do not hide the primary state copy or the refresh action.
- [ ] The screen remains aggregate-only and does not add drill-down into underlying tracks or legs, per-track detail lists, map highlighting, CSV export, raw matched-leg inspection, or editing workflow.
- [ ] Behavior-first TDD drives this item, and widget coverage verifies the new settings entry tile, first-load state, empty state, failure state, successful aggregate tables, disabled `Refresh Analysis` and `Retry` during an active run, and refresh-in-place behavior that keeps prior results visible while loading.

## Covers
- User Stories: 1, 4
- Requirements: 1, 3, 10-17
- Technical Decisions: 1, 6
- Testing Strategy: 1, 3
- Interview Ledger: L5, L8-L11

## Blocked by
- `01-shared-track-speed-analysis-seam-and-aggregate-service.md`
