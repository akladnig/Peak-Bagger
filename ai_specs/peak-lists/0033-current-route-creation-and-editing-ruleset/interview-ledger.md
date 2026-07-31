---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which route-related surfaces should this first pass cover?

Recommended Answer:
- Scope this effort to the interactive map `Route` drafting and editing flow only.
- Include `Create Route` entry, edit-from-selected-route entry, draft modes, marker and waypoint behavior, undo and redo, save and cancel, loading and error and elevation states, and `Route to Peak`, `Out and Back`, and `Close Loop` behavior.
- Exclude GPX import-as-route, route-info-panel walking-speed and timing edits, visibility and export, admin route editing and deletion, and unrelated app navigation.

Answer: agreed

Decision: The first-pass baseline covers only the interactive map `Route` drafting and editing flow and excludes other route-related mutation surfaces.

Reason: The user wants a complete current-behavior baseline for refining interactive route creation and editing before expanding to adjacent route workflows.

### L2

Status: current

Question: Should the first pass be strictly descriptive of current implemented behavior, or also normalize contradictions and propose desired behavior?

Recommended Answer:
- Make the first pass strictly descriptive of current implemented behavior.
- Include entry points, states, transitions, validations, save and edit persistence rules, visible labels and errors, and important edge cases and fallback behavior.
- Flag contradictions separately as implementation inconsistencies, but do not resolve them yet.

Answer: agreed

Decision: The first pass must document current implemented interactive route drafting and editing behavior exactly as it exists today and must flag, not resolve, inconsistencies.

### L3

Status: current

Question: When current code, tests, and older specs or docs disagree, which source should the baseline ruleset treat as authoritative?

Recommended Answer:
- Use current code and regression tests as the source of truth for the first-pass ruleset.
- Use older specs and docs only as supporting context.
- When they differ, record the implemented behavior, the conflicting older statement, and why it is an implementation inconsistency candidate.

Answer: agreed

Decision: Current code and regression tests are authoritative for the first-pass baseline; older specs and docs are supporting context only.

Reason: The user wants to enrich and fix the ruleset after first establishing what the app actually does today.

### L4

Status: current

Question: What canonical terminology should the baseline use for interactive route drafting and editing?

Recommended Answer:
- Use `Route point` as the umbrella term for points that define a route.
- Use `Start route point` and `End route point` for the first and last defining points of an open route.
- Use `Numbered route point` for a draft-only intermediate route point shown with a number during manual editing.
- Use `Hover point` for a temporary point shown while hovering over an editable route segment that can be committed into the draft as a numbered route point.
- Use `Plain route point` for an unnamed route-defining point that is not a waypoint, including imported or auto-routed points without saved semantic meaning.
- Use `Waypoint` for a saved named route point with semantic meaning, such as a peak-derived point.
- Use `Route path` for the full drawn line of the route and `Route segment` for the drawn line between two adjacent route points.

Answer: agreed

Decision: The baseline must use the agreed canonical route terminology recorded in `GLOSSARY.md`, including `Route point`, `Start route point`, `End route point`, `Numbered route point`, `Hover point`, `Plain route point`, `Waypoint`, `Route path`, and `Route segment`.

### L5

Status: current

Question: The current code saves non-peak intermediate route points as generic named `Waypoint N` entries even though numbered route points are intended to be draft-only. How should the baseline treat that mismatch?

Recommended Answer:
- Document current behavior exactly as implemented for the first pass.
- State that numbered route points are draft UI points during editing.
- State that on save, non-final persisted intermediate route points are currently written as generic named waypoints like `Waypoint 1`.
- Flag this as an implementation inconsistency rather than normalizing it.

Answer: agreed. the reason for the rule is so that I can enrich/fix the ruleset

Decision: The baseline must document the current persistence of generic `Waypoint N` entries for non-final intermediate points and explicitly flag that behavior as an implementation inconsistency against the preferred terminology.

### L6

Status: current

Question: Should the baseline include only user-visible interaction rules, or also saved-data and re-edit rules?

Recommended Answer:
- Include both user-visible interaction rules and saved-data and re-edit rules.
- Include what appears during drafting, what is persisted on save, what is not persisted, how saved routes are rehydrated into edit mode, and where current persisted behavior conflicts with preferred terminology.
- Exclude purely internal details that never affect visible behavior, saved data, or later editing.

Answer: agreed

Decision: The baseline must include both user-visible interaction behavior and saved-data and re-edit behavior, while excluding purely internal implementation details with no observable effect.

### L7

Status: current

Question: Should the baseline include input-method-specific behavior such as hover, click-to-insert, drag-to-move, keyboard undo and redo, and escape behavior?

Recommended Answer:
- Yes, include currently implemented input-specific behavior.
- Include mouse hover behavior for `Hover point`, click and drag behavior for inserting and moving route points, keyboard undo and redo and escape behavior, and notable differences between hover-capable desktop behavior and non-hover touch behavior.
- Do not generalize beyond what the app currently implements.

Answer: agreed

Decision: The baseline must capture currently implemented input-specific interactive behavior, including hover, click, drag, and keyboard route-drafting controls.

### L8

Status: current

Question: How should imported or externally created saved routes be handled in this scope?

Recommended Answer:
- Include imported or externally created routes only where they affect interactive editing after the route is already present in the app.
- Include how saved route data is interpreted when edit mode starts, how plain route points, waypoints, and route path are rehydrated into the draft, and any mismatches between imported saved data and manual draft terminology.
- Exclude import workflow rules, file-format parsing rules, and source-specific import decisions.

Answer: agreed

Decision: Imported or externally created routes are in scope only insofar as their saved data affects later interactive editing and rehydration behavior.

### L9

Status: current

Question: Should the baseline include derived saved-route metadata that creation and editing currently recalculate or preserve?

Recommended Answer:
- Yes, include draft distance and elevation display behavior, elevation loading and error states, what gets recalculated on save, what defaults to zero or null when sampling data is unavailable, and edit-save timing preservation or extension behavior when a saved route is modified.
- Exclude separate route-info-panel walking-speed adjustment flows.

Answer: agreed

Decision: The baseline must cover derived route metadata behavior that interactive creation and editing recalculates, samples, preserves, or falls back for, including distance, elevation, sampled point elevations, and edit-save timing carry-forward.

### L10

Status: current

Question: Should the baseline include all route-creation and editing behaviors proven by current code and tests, even when some are subtle or not obvious from casual UI use?

Recommended Answer:
- Yes.
- Include directly visible UI behavior, subtle hover and insert and drag and edit behavior, save rehydration behavior, fallback and failure behavior, and behaviors primarily evidenced by regression tests when they affect user-visible results or persisted data.
- Exclude dead code and purely internal implementation structure with no observable outcome.

Answer: agreed

Decision: The baseline must include all observable current route-creation and editing behavior established by the implementation and regression tests, not just behavior obvious from casual UI inspection.
