---
type: Work Item
title: Peak Lists Desktop Robot Journey For Interactive Mini-Map History
parent: ../spec.md
---

## What to build
Extend the desktop-focused Peak Lists robot journey coverage so it exercises the interactive `peak list mini-map` plus local camera-history replay on `PeakListsScreen` using the deterministic local seam from the earlier slices. The journey must use existing stable selectors such as `peak-lists-mini-map` and `peak-lists-mini-map-interaction-region` where they are sufficient, add new stable selectors only if the current keys are insufficient for deterministic history assertions, and verify that interactive mini-map navigation plus `Cmd+[` and `Cmd+]` history replay works without relying on real network calls, real map services, or secrets.

## Required context
- `test/robot/peaks/peak_lists_robot.dart` already exposes stable selectors for `peak-lists-mini-map`, mini-map markers, clusters, and the mini-map popup. Extend this robot first before adding new ad hoc test helpers elsewhere.
- `test/robot/peaks/peak_lists_journey_test.dart` already contains deterministic `PeakListsScreen` journeys using in-memory repositories and app-shell navigation. Keep this slice aligned with those patterns.
- Reuse the deterministic local camera/history seam from Work Item 1 for assertions about committed camera state, replay, forward-history clearing, and reset behavior instead of relying only on pixel-position inference.
- Preserve the exact selector names already called out by the Spec, and add new stable selectors only when the existing keys are insufficient for deterministic history assertions.

## Acceptance criteria
- [x] `test/robot/peaks/peak_lists_robot.dart` exposes any additional deterministic robot helpers needed to drive interactive `peak list mini-map` navigation and `Cmd+[` / `Cmd+]` history replay while preserving existing stable selectors such as `peak-lists-mini-map` and `peak-lists-mini-map-interaction-region`.
- [x] `test/robot/peaks/peak_lists_journey_test.dart` includes at least one desktop-focused journey that exercises interactive mini-map navigation plus history replay on `PeakListsScreen`.
- [x] The robot journey verifies accepted camera-history replay through the deterministic local seam rather than relying only on inferred pixel movement.
- [x] The robot journey verifies forward-history clearing after moving backward and then making a new accepted camera change.
- [x] The robot journey verifies reset behavior when the selected peak list changes.
- [x] New stable selectors are added only if the current keys are insufficient for deterministic history assertions through the local seam.
- [x] Automated robot coverage remains deterministic and uses fake repositories, provider overrides, and local seams only, with no real network calls, real map services, or secrets.

## Covers
- User Stories: 1-3
- Requirements: 2, 8, 11-14
- Technical Decisions: 2-5
- Testing Strategy: 6-7
- Interview Ledger: L2-L3, L5, L7-L8

## Blocked by
- `01-peak-lists-screen-level-mini-map-keyboard-controls-and-local-camera-history.md`
- `02-peak-list-mini-map-interactive-camera-controls-and-commit-semantics.md`
