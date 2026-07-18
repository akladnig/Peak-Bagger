---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this work be framed as a focused user-visible performance fix or as a broader peak-list storage migration?

Recommended Answer:
- Frame it as a focused performance fix whose implementation uses the relational `PeakList` plus persisted `PeakListItem` model.
- Keep current UI behavior, labels, confirmations, and CSV column set unchanged unless a behavior must change to preserve correctness.
- Allow exported peak-list files to be processed alphabetically by peak-list name, and rows within each exported CSV to be sorted alphabetically by peak name with a deterministic secondary key.
- Migrate legacy `PeakList.peakList` JSON data into persisted membership rows and stop using JSON-backed membership as the source of truth after migration.
- Keep broad `Background job` architecture changes out of scope unless they are still required after the peak-list performance work.

Answer: agreed

Decision: This slice is a focused peak-list performance fix implemented through relational `PeakList` and persisted `PeakListItem` membership storage, while preserving current peak-list UI behavior and CSV column set unless correctness requires a change and allowing the agreed alphabetical export sorting behavior.

Negative Requirements:
- Do not redesign the peak-list UI for this slice.
- Do not change export CSV shape beyond the agreed alphabetical export sorting behavior.
- Do not keep JSON-backed membership as an ongoing source of truth after migration.

### L2

Status: current

Question: What exact user-visible performance contract should this slice meet for peak-list edits and export handoff?

Recommended Answer:
- Single-peak add, delete, or points edit in a normal existing peak list should complete in about 1 second or less on local data.
- Multi-add from the picker should save as one list update, not one full save per selected peak.
- Starting `Export Peak Lists` should return control to the app immediately.
- The started snackbar and jobs entry should appear within about 250 ms.
- `Settings` should stay responsive and the user should be able to navigate to other shell screens while export continues in-app.
- Keep the existing Phase 1 `Background job` limits: no OS-background execution promise and no user cancellation in this slice.

Answer: agreed

Decision: Peak-list edits must become near-instant for common local mutations, multi-add must avoid per-peak full-save behavior, and `Export Peak Lists` must hand off immediately to the existing in-app `Background job` flow without freezing `Settings` or shell navigation.

Reason: The current problem is both data-path cost and app responsiveness, not just raw export duration.

### L3

Status: current

Question: After a peak is added to or removed from a peak list, which views must update immediately versus lazily?

Recommended Answer:
- Update the initiating peak-list surface immediately, including selected list details, member count and order, points values, and current add/delete affordances.
- Keep selection state consistent immediately if the edited list is currently selected.
- If `Map` is currently visible, refresh its peak-list-dependent rendering right away.
- If `Map` is not currently visible, do not block the save waiting for a full map marker reload; refresh map-dependent rendering when the user next opens `Map` or when that screen resumes.
- Export does not require any map refresh.

Answer: agreed

Decision: Peak-list edit flows must refresh the initiating surface and current selection immediately, refresh `Map` immediately only when it is visible, and avoid blocking off-screen peak-list mutations on a full map marker reload.

### L4

Status: current

Question: For existing users with JSON-backed peak lists, what should the app do on first launch after this change if migration cannot convert one or more lists?

Recommended Answer:
- Run a one-time automatic migration before peak-list edit/export code uses relational memberships.
- If a list migrates successfully, relational `PeakListItem` rows become the only source of truth for that list.
- If a legacy payload is malformed or unreadable, keep the peak-list row visible by name and deletable, block add/remove/edit/export for that affected list, show the existing unsupported-state guidance telling the user to delete and re-import the list, and surface a one-time non-blocking warning that some peak lists could not be migrated.
- Do not silently drop members, guess missing rows, or create partial migrated lists from bad payloads.

Answer: agreed

Decision: Use a one-time automatic migration to relational memberships, but treat unreadable legacy payloads as unsupported legacy lists rather than silently repairing or partially migrating them.

Negative Requirements:
- Do not silently drop membership rows.
- Do not guess or synthesize missing legacy data.
- Do not partially migrate malformed list payloads.
