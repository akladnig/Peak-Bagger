---
type: Work Item
title: App Refresh And Journey Coverage
parent: ../spec.md
---

## What to build
Wire successful peak duplicate resolution through the existing admin and map refresh seams so repaired peaks become visible again in app-wide peak consumers, then add the critical ObjectBox Admin robot journey proving the end-to-end duplicate-resolution flow refreshes the map and peak-list add behavior.

## Required context
- The spec depends on existing refresh seams rather than new global plumbing. Relevant current seams include `objectboxAdminProvider.notifier.refresh()`, `peakRevisionProvider`, `MapNotifier.reloadPeakMarkers()`, and `MapNotifier.reconcileSelectedPeakList()`.
- The reported `Agamamemon` failure mode is specifically about app-wide visibility after duplicate cleanup, including the Peak Lists add-peak dialog and map rendering. This item should verify those real consumer paths rather than only repository state.
- `test/robot/objectbox_admin/objectbox_admin_robot.dart` already provides stable selectors and app harness overrides for ObjectBox Admin. Extend that robot only where the new duplicate-resolution controls need deterministic selectors.
- Keep automated verification local and deterministic: in-memory repositories, fake admin repositories, fake peak-list/track/route stores, and provider overrides only. Do not depend on startup-side repair logic, live assets, or network work.

## Acceptance criteria
- [ ] After a successful duplicate resolution, the app refreshes ObjectBox Admin data, keeps the surviving peak selected, and refreshes app-wide peak consumers through the existing refresh seams rather than requiring a separate manual refresh path.
- [ ] A surviving peak retained in the live store after duplicate cleanup becomes discoverable again through the Peak Lists add-peak dialog under the same live-store conditions as other stored peaks.
- [ ] A surviving peak retained in the live store after duplicate cleanup becomes eligible for map rendering again under the same live-store conditions as other stored peaks.
- [ ] Existing ordinary delete behavior remains unchanged in the refreshed admin and map flows when the admin is not using `Resolve Duplicate...`.
- [ ] A robot-driven ObjectBox Admin journey covers the critical Flutter path: open ObjectBox Admin, resolve one duplicate peak into one surviving peak, confirm the action, observe the surviving peak remains selected, and verify the refreshed app state reflects the repaired peak in peak-dependent UI.
- [ ] Any new robot selectors introduced for duplicate resolution are stable, app-owned keys and limited to the new controls needed by the journey.

## Covers
- User Stories: 1, 2
- Requirements: 1, 12-14
- Technical Decisions: 2-5
- Testing Strategy: 4-5
- Interview Ledger: L1-L2, L4-L6

## Blocked by
- `01-peak-duplicate-resolution-engine.md`
- `02-objectbox-admin-resolve-duplicate-flow.md`
