---
type: Spec
title: Current Route Creation And Editing Ruleset Baseline
---

## Problem

`Peak Bagger` has a substantial interactive map `Route` drafting and editing system spread across `MapScreen`, `mapProvider`, route overlays, saved-route rehydration, and a broad regression suite, but it does not yet have one complete current-behavior ruleset that describes what is implemented today. Existing route language is easy to overload, older docs can lag behind the code, and at least one persistence behavior already conflicts with the preferred terminology around `Numbered route point` versus `Waypoint`. Without a durable baseline of current behavior, later route-rule refinement risks redesigning or correcting behavior without first recording what the app actually does. [L1] [L2] [L3] [L4] [L5] [L10]

## Proposed Outcome

Create and maintain a first-pass baseline ruleset for interactive map `Route` creation and editing that documents the app's currently implemented behavior exactly as it exists today. This Spec remains the planning artifact, while the maintained route-rules artifact lives at `ai_specs/routes/route-rules.md`. The baseline uses the agreed canonical terminology, scopes itself to the interactive map drafting and editing flow, includes both visible interaction rules and saved-data and re-edit rules, captures current input-specific behavior and derived metadata behavior, and flags implementation inconsistencies separately rather than normalizing them. Current code and regression tests remain the authoritative source when older docs disagree. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10]

## User Stories

1. As the maintainer refining route behavior, I need a complete baseline of current interactive map `Route` creation and editing behavior before changing or enriching the ruleset. [L1] [L2] [L3]
2. As a reviewer of future route changes, I need durable canonical terms such as `Route point`, `Numbered route point`, `Hover point`, `Plain route point`, `Waypoint`, `Route path`, and `Route segment` so future specs and code reviews describe the same concepts consistently. [L4] [L5]
3. As an implementer or tester, I need the baseline to cover both draft-time behavior and what is persisted and rehydrated later, so save and edit behavior can be refined without losing current contracts. [L5] [L6] [L8] [L9]
4. As a desktop route-editing user, I need subtle current interactions such as hover insertion, drag editing, keyboard actions, and route-state fallbacks to be represented in the baseline rather than omitted as hidden implementation detail. [L7] [L10]

## Requirements

1. Scope the baseline to the interactive map `Route` drafting and editing flow only. Include `Create Route`, edit-from-selected-route entry, drafting modes, route-point editing, undo and redo, save and cancel, loading and error and elevation states, and `Route to Peak`, `Out and Back`, and `Close Loop` behavior. Exclude GPX import-as-route, route-info-panel walking-speed and timing edits, route visibility and export flows, admin route editing and deletion, and unrelated app navigation work. [L1]
2. Treat this first pass as a strictly descriptive current-behavior baseline. Document what the app currently does, not what the app should do after refinement. Record contradictions and terminology mismatches as implementation inconsistencies rather than silently correcting them. [L2]
3. Keep this Spec as the planning artifact. The implementation deliverable for this slice is the maintained route-rules document at `ai_specs/routes/route-rules.md`, which future route-rule refinement and app-enhancement work will update. Structure that document with separate `Current Behavior Baseline`, `Implementation Inconsistencies`, and `Proposed Rule Changes` sections. For this slice, populate only the baseline and inconsistency sections; reserve `Proposed Rule Changes` for later add, modify, and delete rule work.
4. Use current implementation and regression tests as the authoritative source for the baseline. When older specs or docs disagree, preserve the implemented behavior first and record the older statement only as conflicting context. [L3]
5. When building the baseline, review the following older route docs as conflicting context: `ai_specs/routes/route_bottom-sheet-spec.md`, `ai_specs/routes/route-hover-spec.md`, `ai_specs/routes/route-edit-spec.md`, `ai_specs/routes/route-out-and-back-spec.md`, `ai_specs/route-to-peak-track-then-straight-spec.md`, and `ai_specs/routes/route-loop-spec.md`. Record disagreements with current code and tests in `ai_specs/routes/route-rules.md` under `Implementation Inconsistencies` rather than normalizing them. [L3]
6. Use the canonical route terminology captured in `GLOSSARY.md`. At minimum, the baseline must use `Route`, `Route point`, `Start route point`, `End route point`, `Plain route point`, `Numbered route point`, `Hover point`, `Waypoint`, `Route path`, and `Route segment` with the agreed meanings. [L4]
7. The baseline must distinguish route-point classes clearly:
   - `Hover point` is temporary hover-only state and can become a `Numbered route point` when committed.
   - `Numbered route point` is a draft-only intermediate route point shown with a number during manual editing.
   - `Plain route point` is an unnamed saved or imported route-defining point without saved semantic naming.
   - `Waypoint` is a saved named route point with semantic meaning, such as a peak-derived point. [L4]
8. The baseline must explicitly document the current persistence mismatch where non-final intermediate points can currently be saved as generic named `Waypoint N` entries even though `Numbered route point` is the preferred draft-only concept. Treat this as an implementation inconsistency for later refinement rather than a normalized rule. [L5]
9. Capture current route-drafting entry and exit behavior, including:
   - `Create Route` entry from the map action rail,
   - edit entry from the selected-route info panel,
   - current cancel and save exit behavior,
   - current route-panel restoration behavior after route-edit cancel or save,
   - current stale-selection or stale-source-route handling when a route disappears during editing. [L1] [L6] [L10]
10. Capture the current draft state model and transitions, including inactive, awaiting start, awaiting next point, routing-segment in progress, and segment-failure states; current save enablement rules; current route-name validation; and currently visible helper, loading, and error copy such as `Tap a point to start routing`, `Routing...`, `Sampling elevation...`, and `A Route name must be entered`. Preserve exact implemented labels where the baseline quotes user-visible text. [L2] [L6] [L9] [L10]
11. Capture current route-point and route-segment interactions, including tap-to-add behavior, duplicate-point failure behavior, marker limit behavior, segment insertion from hover preview, drag-to-move behavior, delete behavior, and the current rules for how route-point classes change when route points are moved, inserted, or rebuilt. Include the current limit error `Peak Bagger only supports a maximum of 99 route points` if the baseline records the visible limit contract. [L6] [L7] [L10]
12. Capture current mode and transform behavior, including `Straight Line`, `Snap to Trail`, `Route to Peak`, `Out and Back`, and `Close Loop`; the current enable and disable conditions for those controls; and current fallback behavior for off-track, no-path, and route-graph-load outcomes. Preserve current distinctions between visible mode affordances and underlying route-state changes. [L1] [L6] [L7] [L10]
13. Capture current input-specific desktop interaction behavior, including hover-based `Hover point` preview, click-to-insert, drag-to-move, marker drag thresholds, keyboard undo and redo behavior, and dismiss-priority `Escape` behavior where it affects route-drafting state or surrounding UI. Document `Escape` according to the current map-shell surface dismissal order, including cases where it dismisses a higher-priority surface while leaving route drafting active. Include touch or non-hover differences only where current implementation or tests establish an observable difference. [L7] [L10]
14. Include saved-data and re-edit behavior in the baseline, including what is persisted on save, what is not persisted, how saved routes are rehydrated into edit mode, how saved route points and waypoints become draft structures again, and how imported or externally created routes affect later editing once they already exist in the app. Document the current stale selected-route and stale source-route reconciliation behavior when a route disappears during selection or edit mode. Do not expand this into import workflow or file-format rules. [L6] [L8]
15. Include derived route metadata behavior that current interactive creation and editing recalculate or preserve, including displayed draft distance, elevation-summary loading and error states, sampled point elevations, save-time recalculation and fallback behavior, and timing-profile preservation or extension behavior when editing existing routes. Keep separate route-info-panel walking-speed adjustments out of scope. [L1] [L9]
16. Include subtle current behavior that is only fully clear when code and tests are read together, provided it affects user-visible outcomes, persisted data, or later editing behavior. Do not omit these behaviors just because they are not obvious from casual UI exploration. [L10]

## Technical Decisions

1. Treat `lib/providers/map_provider.dart` as the primary current source of truth for route-drafting state, state transitions, persistence decisions, route-point rehydration, and route-metadata carry-forward; use `lib/screens/map_screen.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/screens/map_screen_panels.dart`, and route-related tests as the supporting UI and behavior authority around that state model. [L3] [L6] [L7] [L9] [L10]
2. Keep the glossary terminology updates as the canonical language layer for this baseline and future route-rule refinement. The baseline should translate internal names such as `control endpoint` or `segment preview` into the agreed durable project terminology where that translation is lossless. [L4]
3. Treat `ai_specs/routes/route-rules.md` as the maintained long-lived route-rules artifact. Keep `Current Behavior Baseline`, `Implementation Inconsistencies`, and `Proposed Rule Changes` separate so current descriptive behavior does not get mixed with later add, modify, or delete proposals.
4. Record implementation inconsistencies explicitly rather than hiding them inside normalized prose. At minimum, call out the current mismatch between draft-only `Numbered route point` terminology and the current persistence of generic saved `Waypoint N` entries, plus any disagreements between current code/tests and the bounded legacy-doc review set. [L2] [L5]
5. Prefer existing test seams and observability when verifying the baseline against the app, especially `mapProvider` state tests, selected-route reconciliation tests, map widget route-sheet tests, keyboard dismissal tests, route-hover tests, and robot or journey tests that already exercise route edit save and cancel flows. [L3] [L7] [L9] [L10]

## Testing Strategy

1. No new product-behavior implementation is required merely to create the first-pass baseline document; therefore, no new unit, widget, or robot coverage is required if this slice is documentation-only.
2. Verify the baseline against existing deterministic Flutter seams and current regression coverage, including provider-level route-draft state tests, provider-level selected-route reconciliation tests, widget-level route-sheet, route-hover, and keyboard dismissal tests, and journey-level route edit save and cancel coverage. [L3] [L7] [L9] [L10]
3. Treat the current route-editing test corpus as evidence for subtle behavior that the baseline must preserve, especially around hover insertion, drag editing, stale async result supersession, dismiss-priority `Escape` behavior, stale route disappearance handling, save rehydration, error paths, and metadata carry-forward. [L3] [L10]
4. If implementation of this Spec adds helper code or repository docs tooling rather than only writing prose, use behavior-first TDD for that helper logic and keep automated verification deterministic, fake-backed, and independent of real external services.

## Out of Scope

1. Redesigning route creation or editing behavior in this first pass.
2. Resolving the current `Numbered route point` versus persisted `Waypoint N` inconsistency instead of documenting it.
3. GPX import-as-route workflows, route file parsing, and source-specific import rules.
4. Route-info-panel walking-speed or timing recalculation controls outside the interactive map drafting and editing flow.
5. Route visibility toggles, export behavior, admin route maintenance, and unrelated app-router navigation behavior.

## Follow-Ups

1. Decide the desired future persistence model for unnamed intermediate saved route points once the current baseline is complete.
2. Decide the first `Proposed Rule Changes` entries to add under `ai_specs/routes/route-rules.md` once the current baseline and inconsistency capture are complete.

## Notes

1. Relevant current implementation surfaces include `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/screens/map_screen_panels.dart`, `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_route_draft_hover_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_route_hover_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/robot/map/route_info_journey_test.dart`.
2. Relevant older route docs to compare as conflicting context are `ai_specs/routes/route_bottom-sheet-spec.md`, `ai_specs/routes/route-hover-spec.md`, `ai_specs/routes/route-edit-spec.md`, `ai_specs/routes/route-out-and-back-spec.md`, `ai_specs/route-to-peak-track-then-straight-spec.md`, and `ai_specs/routes/route-loop-spec.md`.
3. `GLOSSARY.md` was updated during interview to record the canonical terminology that this baseline should use for future route-rule refinement.
