---
type: Spec
title: ObjectBox Admin Peak Duplicate Resolution
---

## Problem

The current app can end up with broken peak visibility after manual duplicate cleanup in the live ObjectBox store. In the reported `Agamamemon` case, a new peak was added to peak data and peak lists, a duplicate was deleted, and the surviving peak no longer appeared in the Peak Lists add-peak dialog or on the map. The existing ObjectBox Admin peak delete flow is safety-first and only supports plain delete or delete-blocked feedback; it does not support replacing one `Peak` with a surviving canonical `Peak` while migrating app-owned references. That leaves duplicate cleanup without a supported product workflow and makes already-broken local data hard to repair safely. [L1] [L2] [L3] [L6] [L7]

## Proposed Outcome

Add a durable ObjectBox Admin `Peak duplicate resolution` workflow that lets an admin choose a duplicate peak, choose a `Surviving peak`, confirm the replacement, atomically migrate app-owned references, delete the duplicate row, and immediately refresh app-wide peak consumers so the surviving peak appears correctly in the map and peak-list flows without a separate data refresh. Ordinary peak delete remains unchanged and continues to block on dependencies when the admin is not explicitly resolving a duplicate. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8]

## User Stories

1. As a power user maintaining peaks in ObjectBox Admin, I can resolve one duplicate peak into one surviving canonical peak without manually editing peak lists, ascents, tracks, and saved route references one-by-one. [L2] [L3] [L4] [L7]
2. As a user repairing already-broken local peak data like the current `Agamamemon` case, I can run an explicit admin repair flow that restores app-wide peak visibility without silent startup rewrites or asset reimports. [L1] [L3] [L6]
3. As an admin doing true destructive cleanup, I still get the current safety-first ordinary `Delete` behavior when a peak is referenced and I am not intentionally replacing it with a surviving peak. [L3] [L4]

## Requirements

1. Keep the live ObjectBox `Peak` store as the canonical source of truth for manual peak create, edit, delete, and duplicate-resolution work. Successful duplicate resolution must update app behavior from that live store immediately, without requiring a separate region asset import, seed refresh, or startup-only repair pass. [L1]
2. Add an explicit `Resolve Duplicate...` action for `Peak` records in ObjectBox Admin. This action must be separate from ordinary `Delete` and must be available through the existing ObjectBox Admin peak-maintenance workflow rather than a new app route. [L3] [L4]
3. The duplicate-resolution flow must start from the duplicate peak record, allow the admin to choose one surviving canonical peak, and require an explicit confirmation step before mutation. The confirmation copy must state the result in this shape: `Move references to <surviving peak> and delete <duplicate peak>?` [L4]
4. Ordinary peak `Delete` must remain available for true deletions and must keep the current dependency-blocked behavior when references exist. Duplicate replacement semantics must not be hidden behind the ordinary delete action. [L3] [L4]
5. Successful `Peak duplicate resolution` must migrate app-owned references from the duplicate peak to the surviving peak before deleting the duplicate row. This migration scope must include all currently stored app-owned peak references in this first supported workflow: [L2] [L7]

```text
- PeakList items keyed by peakOsmId
- PeaksBagged.peakId
- GpxTrack.peaks ObjectBox relations
- Route.routeWaypoints[].peakOsmId for saved route waypoints
```

6. The workflow must not rewrite free-text historical labels in this iteration. Linked peak identifiers must be updated where required, but fields such as stored route waypoint `peakName` remain unchanged unless that text is already derived from the linked surviving peak at render time. [L7]
7. Duplicate resolution must be atomic across the supported app-owned reference rewrites and duplicate deletion. Either every intended rewrite succeeds and the duplicate peak is deleted, or nothing changes. The workflow must not partially migrate one reference type while leaving others behind. [L5]
8. If duplicate resolution fails, the app must leave both peaks untouched, keep them inspectable/selectable in ObjectBox Admin, and show a failure dialog that names the blocking dependency types and, when practical, affected records. [L5]
9. The app must support repairing already-broken local duplicate states through the same explicit ObjectBox Admin flow. It must not silently repair orphaned references at startup, and it must not guess a surviving peak from fuzzy name or coordinate similarity. [L3] [L6]
10. If the app can detect an orphaned reference situation with exactly one unambiguous surviving peak candidate, the duplicate-resolution flow may prefill that surviving peak selection, but the admin must still confirm before any mutation occurs. [L6]
11. When duplicate resolution encounters a collision because the surviving peak is already linked from the same parent record, normalize that parent record to one surviving linked identity instead of creating duplicates. Apply these parent-type-specific rules: [L2] [L8]

```text
- PeakList: keep the first existing list position and the first existing points value in list order.
- PeaksBagged: keep one row per gpxId + surviving peakId; if both rows already exist, preserve the existing surviving row and remove the duplicate-resolved row.
- GpxTrack.peaks: keep one relation to the surviving peak per track.
- Route.routeWaypoints[].peakOsmId: preserve both waypoint rows only when they are distinct route waypoints; do not create a second identical waypoint solely because of migration.
```

12. After a successful duplicate resolution, refresh the ObjectBox Admin table, keep the surviving peak selected, and refresh app-wide peak consumers immediately so the repaired peak is visible in the map and Peak Lists add-peak flow without a separate manual refresh. [L1] [L4]
13. The current broken visibility symptoms must be fixed as a product outcome of successful duplicate resolution. A surviving peak that remains in the live store after duplicate cleanup must be discoverable again through the Peak Lists add-peak dialog and eligible for map rendering under the same live-store conditions as any other stored peak. [L1] [L2]
14. The duplicate-resolution action must expose a clear in-progress/concurrent-action state in the Flutter UI so the admin cannot submit the same resolution multiple times while the rewrite is running. [L4] [L5]

## Technical Decisions

1. Implement duplicate cleanup as an explicit ObjectBox Admin workflow rather than overloading ordinary delete. Keep normal delete and duplicate resolution as separate product actions with distinct mutation paths. [L3] [L4]
2. Reuse the existing ObjectBox Admin route, selection model, dialogs, and refresh seams instead of creating a second maintenance screen. Relevant existing seams include `objectboxAdminProvider.notifier.refresh()`, `peakRevisionProvider`, `MapNotifier.reloadPeakMarkers()`, and `MapNotifier.reconcileSelectedPeakList()`. [L1] [L4]
3. Treat duplicate resolution as a repository or service-level mutation that coordinates all supported reference rewrites and the final duplicate delete under one atomic write boundary. The implementation must cover both identifier-based references (`peakOsmId`, `peakId`) and ObjectBox relations (`GpxTrack.peaks`). [L2] [L5] [L7]
4. Reuse the project glossary terms `Peak duplicate resolution` and `Surviving peak` in product and workflow artifacts so duplicate replacement is not described ambiguously as a plain delete. [L3] [L4]
5. Prefer existing ObjectBox Admin test seams, in-memory repositories, fake admin repositories, and provider overrides over live storage migrations or startup-side implicit repair logic. Saved route waypoint rewrites should use the existing route model and repository seams rather than ad hoc JSON editing at the widget layer. [L5] [L6] [L7]

## Testing Strategy

1. Use behavior-first TDD for the duplicate-resolution logic, starting with service or repository tests that prove atomic reference migration and parent-type collision normalization before wiring the full admin UI.
2. Extend repository or service coverage for duplicate resolution to cover: [L2] [L5] [L7] [L8]
   1. plain duplicate resolution that migrates all supported reference types
   2. all-or-nothing rollback when any reference rewrite fails
   3. peak-list collision normalization preserving first list order and first points value
   4. `PeaksBagged` collision normalization to one `gpxId + peakId` row
   5. `GpxTrack.peaks` relation deduplication to one surviving relation per track
   6. route waypoint `peakOsmId` rewrites that preserve distinct waypoints but avoid duplicate identical waypoint creation
3. Extend ObjectBox Admin widget coverage to prove: [L3] [L4] [L5] [L6]
   1. `Resolve Duplicate...` is exposed separately from ordinary delete for peak records
   2. the surviving-peak selection and explicit confirmation flow appear with the required copy
   3. duplicate resolution disables repeat submission while in progress
   4. success refresh keeps the surviving peak selected and refreshes peak-dependent UI state
   5. failure leaves both peaks untouched and shows descriptive failure feedback
4. Extend the existing ObjectBox Admin robot or journey coverage for the critical Flutter journey: open ObjectBox Admin, resolve one duplicate peak into one surviving peak, confirm the action, and observe that the surviving peak is retained while app-wide peak data is refreshed. Reuse deterministic provider overrides and add stable selectors only where the new duplicate-resolution controls require them. [L4] [L5] [L6]
5. Use in-memory ObjectBox-style repositories, fake admin repositories, fake route/track/peak-list stores, and provider overrides. Automated tests must not depend on live region assets, live network calls, or startup-only repair behavior. [L1] [L6]

## Out of Scope

1. Silent startup repair of duplicate or orphaned peak references. [L6]
2. Fuzzy duplicate matching or automatic surviving-peak choice based on similar names or coordinates. [L3] [L6]
3. Rewriting free-text historical labels such as stored route waypoint `peakName` values in this iteration. [L7]
4. Changing region asset files or import seed data as part of the duplicate-resolution feature itself. [L1]
5. Changing ordinary delete behavior for non-duplicate peak deletion beyond keeping its current blocked-delete semantics. [L3] [L4]

## Notes

1. Relevant implementation files include `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/services/peak_repository.dart`, `lib/services/peak_delete_guard.dart`, `lib/services/peak_list_repository.dart`, `lib/providers/map_provider.dart`, `lib/models/gpx_track.dart`, `lib/models/peaks_bagged.dart`, `lib/models/peak_list.dart`, `lib/models/route.dart`, and `lib/models/route_waypoint.dart`.
2. Relevant automated coverage starting points include `test/widget/objectbox_admin_shell_test.dart`, `test/widget/objectbox_admin_browser_test.dart`, `test/robot/objectbox_admin/objectbox_admin_robot.dart`, plus repository or service tests around peak, peak-list, ascent, track, and route persistence.
