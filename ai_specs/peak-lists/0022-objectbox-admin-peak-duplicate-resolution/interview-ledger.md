---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: For this issue, what should be the canonical source of truth for a manually added or deduplicated peak like `Agamamemon`?

Recommended Answer:
- The live ObjectBox `Peak` store is canonical for manual peak create/edit/delete work.
- If a duplicate peak is deleted and a replacement peak is kept, app-wide peak consumers must reflect that change immediately without requiring a separate region import or refresh step.
- Peak-list membership that pointed at the deleted duplicate must move to the surviving canonical peak, not disappear silently.
- Bundled region assets remain seed/import sources only; they do not need to be edited for this fix unless explicitly chosen for rebuild persistence.

Answer: agreed

Decision: The live ObjectBox `Peak` store is the canonical source of truth for manual peak create, edit, duplicate resolution, and delete work, and app-wide peak consumers must reflect deduplication changes immediately without requiring a separate asset refresh.

Reason: The reported `Agamamemon` symptoms affect multiple UI surfaces that already read from the shared live peak store.

### L2

Status: current

Question: When a duplicate peak is removed and one surviving canonical peak remains, how should existing references be handled?

Recommended Answer:
- Migrate all app-owned references from the deleted duplicate to the surviving peak before the duplicate is removed.
- This includes peak-list membership, selected/addable peak visibility, and any other app-owned peak-id lookups that would otherwise orphan the surviving peak from UI flows.
- If both the deleted and surviving peaks are already present in the same peak list, keep one entry for the surviving peak and do not create duplicates.
- If a reference cannot be migrated safely, surface it as an explicit failure instead of silently dropping it.

Answer: agreed

Decision: Duplicate cleanup must migrate app-owned references to one surviving canonical peak before the duplicate is deleted, and unsafe migrations must fail explicitly instead of silently dropping references.

### L3

Status: current

Question: Should this be treated as a one-off repair for the current `Agamamemon` and deleted-duplicate data, or as durable duplicate-resolution behavior for future peak cleanup?

Recommended Answer:
- Make it durable app behavior, not a one-off patch.
- Keep normal peak deletion safety-first: deleting a referenced peak stays blocked by default.
- Add an explicit duplicate-resolution path where an admin chooses the surviving canonical peak, the app migrates app-owned references to that peak, and only then removes the duplicate.
- Include a repair path for already-broken local data when the surviving target is known and unambiguous; do not do fuzzy name-based reassignment.

Answer: agreed

Decision: Peak duplicate cleanup is a durable ObjectBox Admin workflow, while ordinary peak delete remains a separate safety-first action that stays blocked when dependencies exist.

Negative Requirements:
- Do not solve this as a one-off data patch only for `Agamamemon`.
- Do not weaken ordinary peak deletion into implicit duplicate replacement.

### L4

Status: current

Question: How should admins trigger and complete duplicate resolution in the product?

Recommended Answer:
- Add an explicit `Resolve Duplicate...` action for `Peak` records in ObjectBox Admin, separate from normal `Delete`.
- The flow starts from the duplicate peak row or details pane, lets the admin choose one surviving canonical peak, then requires a confirmation step before mutation.
- The confirmation copy should name both peaks and make the result explicit: `Move references to <surviving peak> and delete <duplicate peak>?`
- Keep normal `Delete` unchanged: it remains available for true deletions and stays blocked when dependencies exist.
- After a successful duplicate resolution, refresh the admin table, keep the surviving peak selected, and refresh app-wide peak, map, and peak-list data immediately.

Answer: agreed

Decision: ObjectBox Admin must expose an explicit `Resolve Duplicate...` flow for `Peak` records with surviving-peak selection, an explicit confirmation step, and immediate post-success admin and app refresh.

### L5

Status: current

Question: What should the admin see if peak duplicate resolution cannot be completed cleanly for some references?

Recommended Answer:
- Make the operation atomic for app-owned references: either all intended reference migrations succeed and the duplicate is deleted, or nothing changes.
- Show a failure dialog that names the blocking dependency types and, when practical, the affected records.
- Do not partially migrate peak lists while leaving `PeaksBagged` or `GpxTrack` references behind.
- Keep both peaks untouched and still selectable after failure so the admin can inspect and retry.

Answer: agreed

Decision: Peak duplicate resolution must be atomic across app-owned reference rewrites, and failures must leave both peaks untouched while surfacing a descriptive failure dialog.

Reason: Partial migration would create new hidden data corruption instead of repairing the existing duplicate state.

### L6

Status: current

Question: For already-broken local data like the current `Agamamemon` case, how should the repair path be exposed?

Recommended Answer:
- Add an explicit admin repair action, not a silent startup fix.
- Surface it in ObjectBox Admin as part of `Peak duplicate resolution`, so the admin deliberately selects the duplicate and the surviving peak, then runs the same atomic migration flow.
- Do not guess replacements automatically from name similarity or coordinates.
- If the app can detect an orphaned reference with exactly one unambiguous surviving peak, prefill that surviving peak in the admin flow, but still require confirmation.

Answer: agreed

Decision: Existing broken local duplicate data must be repaired through the same explicit ObjectBox Admin `Peak duplicate resolution` flow, without silent startup rewrites or fuzzy auto-matching, with optional unambiguous surviving-peak prefills that still require confirmation.

Negative Requirements:
- Do not repair orphaned references silently at startup.
- Do not guess replacements from fuzzy name or coordinate similarity.

### L7

Status: current

Question: Which app-owned peak references must `Peak duplicate resolution` migrate in this first supported workflow?

Recommended Answer:
- Migrate all currently stored app-owned peak references.
- `PeakList` items keyed by `peakOsmId`
- `PeaksBagged.peakId`
- `GpxTrack.peaks` ObjectBox relations
- `Route.routeWaypoints[].peakOsmId` for peak-derived saved route waypoints
- Do not try to rewrite free-text historical labels beyond the linked peak fields in this iteration. Keep `peakName` or other display text as-is unless it is already derived from the linked surviving peak at render time.

Answer: agreed

Decision: The first supported duplicate-resolution workflow must migrate `PeakList`, `PeaksBagged`, `GpxTrack.peaks`, and saved route waypoint `peakOsmId` references, while leaving free-text historical labels unchanged in this iteration.

### L8

Status: current

Question: When `Peak duplicate resolution` encounters a collision because the surviving peak is already linked from the same parent record, how should that parent record be normalized?

Recommended Answer:
- Normalize by keeping one surviving reference per parent record, not two.
- `PeakList`: keep the first existing list position and first existing points value in list order.
- `PeaksBagged`: keep one row per `gpxId + surviving peakId`; if both rows exist, preserve the existing surviving row and delete the duplicate-resolved row.
- `GpxTrack.peaks`: keep one relation to the surviving peak per track.
- `Route.routeWaypoints[].peakOsmId`: if both waypoints already point at the surviving peak in the same route, preserve both waypoint rows only when they are distinct route waypoints; otherwise do not create a second identical waypoint just from migration.

Answer: agreed

Decision: Duplicate-resolution collisions must normalize to one surviving linked identity per parent record, with parent-type-specific deduplication rules for peak lists, ascents, track relations, and route waypoints.
