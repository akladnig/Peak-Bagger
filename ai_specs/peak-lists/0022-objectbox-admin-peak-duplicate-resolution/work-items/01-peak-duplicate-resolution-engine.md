---
type: Work Item
title: Peak Duplicate Resolution Engine
parent: ../spec.md
---

## What to build
Add the repository or service-level mutation that resolves one duplicate `Peak` into one `Surviving peak`, atomically rewrites all supported app-owned peak references, normalizes same-parent collisions, and deletes the duplicate row only after every supported rewrite succeeds.

## Required context
- `lib/services/peak_repository.dart` already owns peak save, delete, and peak-list rewrite seams through `PeakListRewritePort` and `ObjectBoxPeakListRewritePort`. Extend or factor these seams instead of introducing a second unrelated duplicate-maintenance path.
- Supported reference surfaces for this item are defined by existing models and repositories: `lib/models/peak_list.dart`, `lib/models/peaks_bagged.dart`, `lib/models/gpx_track.dart`, `lib/models/route.dart`, `lib/models/route_waypoint.dart`, plus the relevant persistence code in `lib/services/peak_list_repository.dart`, `lib/services/peaks_bagged_repository.dart`, and `lib/services/route_repository.dart`.
- Existing delete behavior in `lib/services/peak_delete_guard.dart` and `lib/screens/objectbox_admin_screen.dart` should remain ordinary-delete-only. This item is the separate replacement mutation that later UI work will call.
- Reuse in-memory and fake persistence seams already used by peak, peak-list, ascent, track, and route tests. Prefer behavior-first TDD at the service or repository layer before widget wiring.
- Follow `GLOSSARY.md` terminology, especially `Peak duplicate resolution` and `Surviving peak`.

## Acceptance criteria
- [x] Behavior-first TDD drives this item from repository or service tests first, proving the duplicate-resolution mutation before UI integration.
- [x] One duplicate-resolution entrypoint accepts a duplicate `Peak` and one `Surviving peak`, treats the live ObjectBox `Peak` store as the source of truth, and performs all supported app-owned rewrites plus duplicate deletion under one atomic write boundary.
- [x] The rewrite scope covers all supported stored references from the Spec: `PeakList` items keyed by `peakOsmId`, `PeaksBagged.peakId`, `GpxTrack.peaks` ObjectBox relations, and saved route waypoint `peakOsmId` values.
- [x] The mutation does not rewrite free-text historical labels in this iteration. Linked identifiers are updated where required, while stored route waypoint `peakName` text remains unchanged unless it is already derived elsewhere.
- [x] `PeakList` collision normalization keeps one surviving membership per list, preserving the first existing list order and first existing points value in list order when both duplicate and surviving peaks already appear.
- [x] `PeaksBagged` collision normalization keeps one row per `gpxId + surviving peakId`; when both rows already exist, the existing surviving row is kept and the duplicate-resolved row is removed.
- [x] `GpxTrack.peaks` collision normalization keeps one surviving relation per track after rewrite.
- [x] Route waypoint rewrite logic updates saved route `peakOsmId` links to the surviving peak, preserves distinct waypoint rows when they are genuinely different route waypoints, and does not create a second identical waypoint solely from migration.
- [x] If any supported rewrite step fails, no partial rewrite remains: the duplicate peak is not deleted, previously written parent records are rolled back, and the caller receives a failure result suitable for descriptive UI feedback.

## Covers
- User Stories: 1, 2
- Requirements: 1, 5-11, 13
- Technical Decisions: 1-5
- Testing Strategy: 1-2, 5
- Interview Ledger: L1-L3, L5-L8

## Blocked by
None - ready to start
