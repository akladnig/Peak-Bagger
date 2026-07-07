---
type: Work Item
title: Track Speed Analysis Journey Coverage
parent: ../spec.md
---

## What to build
Add deterministic robot or journey coverage for the `Track Speed Analysis` flow from `Settings` through successful load and in-place refresh. The journey must verify the user-visible navigation boundary, stable selectors, active-run disabling, and refresh behavior that keeps the previously rendered report visible while a new run is in progress.

## Required context
- Follow the existing robot structure under `test/robot/`, including dedicated robot helpers plus focused journey tests that coordinate deterministic fake completions rather than live services.
- Reuse the app's stable `Key` selector convention. This item depends on selectors added by Work Item 02 for the settings tile, screen root, refresh action, loading indicator, empty state, error state, disabled active-run actions, and key report sections.
- Use deterministic fakes or repository-backed fixtures for `GpxTrack` data and route-graph metadata. Automated coverage must not depend on live network calls, live Overpass refreshes, or real API keys.
- Keep this slice focused on end-to-end local behavior; do not create separate test infrastructure unless a seam is independently valuable or blocks multiple slices.

## Acceptance criteria
- [ ] At least one robot or journey test opens `Settings`, enters `Track Speed Analysis`, waits through a deterministic successful load, and verifies that the report can be refreshed without losing the prior rendered results.
- [ ] The robot coverage uses stable app-owned selectors for the settings tile, screen root, refresh action, loading indicator, empty state, error state, disabled active-run actions, and key report sections.
- [ ] The journey asserts user-visible behavior around active-run disabling so `Refresh Analysis` and `Retry` cannot be triggered concurrently while analysis is already running.
- [ ] The journey remains local and deterministic, backed by fakes or fixtures for analysis outcomes rather than live services.

## Covers
- User Stories: 1, 4
- Requirements: 3, 13-15
- Testing Strategy: 4-5
- Interview Ledger: L5, L8, L11

## Blocked by
- `02-settings-track-speed-analysis-screen.md`
