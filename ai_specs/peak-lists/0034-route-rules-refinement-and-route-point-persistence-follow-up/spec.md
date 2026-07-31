---
type: Spec
title: Route Rules Refinement And Route Point Persistence Follow-Up
---

## Problem

`0033-current-route-creation-and-editing-ruleset` established a current-behavior baseline in `ai_specs/routes/route-rules.md`, and the baseline now exposes several places where the implemented route drafting and editing model does not match the intended route rules. The largest mismatches are in edit-save persistence, unnamed intermediate point handling, saved-route rehydration, duplicate-point behavior, marker-limit behavior, and the split between draft-only route points and meaningful saved waypoints. The maintainer has also identified additional future-facing route-editor expectations around `Save As`, named waypoint creation, DEM-aware elevation sampling, macOS-only shortcuts, route-point drag rerouting, and `Close Loop` behavior. Without a dedicated follow-up Spec, future implementation work would mix descriptive baseline maintenance with intended product changes and would risk implementing several loosely related route-rule changes without one consolidated source of truth. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10] [L11]

## Proposed Outcome

Create a follow-up route-rules refinement Spec that keeps `ai_specs/routes/route-rules.md` as the descriptive current-behavior artifact while defining the intended future contract for interactive route creation and editing changes. The resulting route editor keeps ordinary `Save` as update-in-place during edit sessions, adds a distinct `Save As` path with duplicate-name checking, preserves selected saved route metadata that should survive edits, stops persisting generic draft-only waypoints, keeps `Out and Back` and `Close Loop` as geometry transforms rather than implicit semantic-waypoint creation paths, makes saved route geometry fully actionable on re-entry even when not all points are rendered as visible markers, tightens duplicate-point and marker-limit behavior, avoids avoidable elevation sampling when no DEM exists for the relevant region, rounds saved route coordinates to six decimal places, adds explicit named-waypoint creation affordances, removes Windows-style undo shortcuts from the macOS app, improves `Close Loop` routing fallback behavior, and supports rerouting when a trail-backed route point is dragged onto a different trail. Open questions that remain unresolved stay explicit so later decomposition can block on them instead of guessing. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10] [L11]

## User Stories

1. As a route editor updating an existing saved route, I need ordinary `Save` to keep editing the same saved route while preserving the saved metadata that should survive an edit, instead of silently dropping fields such as `desc` or `walkingSpeedKmh`. [L1] [L2]
2. As a route editor who wants a new saved copy, I need an edit-session-only `Save As` flow with duplicate-name checking rather than overloading ordinary `Save`. [L1]
3. As a user refining route geometry, I need draft-only unnamed intermediate route points to stay draft-only and not come back later as generic saved `Waypoint N` records. [L3] [L4]
4. As a user reopening a saved route for editing, I need every saved route point to remain actionable for move, delete, and the current point actions even if the UI does not render every saved point as a visible marker at once. [L4]
5. As a user creating meaningful stops, I need an explicit `Create Waypoint` action and a distinct waypoint marker treatment for named saved waypoints. [L5]
6. As a user drafting in regions without local DEM coverage, I need the route editor to avoid unnecessary elevation sampling requests and related error noise when elevation data is not available for the route region. [L6]
7. As a user editing dense routes, I need accidental duplicate taps to be ignored and marker numbering to remain usable beyond ninety-nine visible numbered points without blocking route editing. [L7]
8. As a macOS desktop user, I need route-drafting keyboard and hover behavior to match the platform and the rest of the route UI, including macOS-only undo shortcuts and hover affordances that stay synchronized with the route profile. [L8]
9. As a route editor closing loops or dragging trail-backed points, I need the route planner to preserve useful trail-following behavior where possible rather than immediately falling back to a straight segment. [L9] [L11]
10. As a reviewer and implementer, I need this future-rules Spec to stay separate from the current-behavior baseline and to call out unresolved decisions instead of hiding them in implementation work. [L10]

## Requirements

1. Keep `ai_specs/routes/route-rules.md` as the descriptive current-behavior baseline. This follow-up Spec defines intended future behavior changes only; it does not replace the baseline's record of what the app currently does. [L10]
2. Scope this follow-up to interactive map `Route` drafting and editing changes only. It may change route save behavior, rehydration, point editing, elevation sampling triggers, route control affordances, and route-planning outcomes where those affect the draft editor. Keep unrelated route export UX, admin route editing, unrelated navigation, and route-info-panel timing controls out of scope unless they are directly required by one of the rules below. [L1] [L2] [L5] [L6] [L8] [L9] [L11]
3. Ordinary `Save` during an edit session must continue to update the current `sourceRouteId` rather than creating a new route. A distinct edit-session-only `Save As` path must create a new saved route instead of overwriting the current source route. [L1]
4. During an edit session, the route sheet must show `Save As` beside `Save`. `Save As` must open a route-name prompt seeded from the current draft name, trim the submitted name before validation and persistence, reject blank trimmed names with the existing route-name validation copy `A Route name must be entered`, reject names that case-insensitively match an existing saved route name after trimming, keep the prompt open on validation failure, show the exact inline duplicate error copy `A route with this name already exists`, and let cancel close the prompt without changing the active edit session. On success, `Save As` must leave the original source route unchanged, close the draft, and select the newly saved route copy. [L1]
5. Interactive edit save must preserve `desc` and `walkingSpeedKmh` from the source `Route` unless the current edit workflow explicitly changes those fields. This slice does not require exposing new editor controls for either field. [L2]
6. Interactive save must stop persisting generic unnamed intermediate draft points as saved `RouteWaypoint` records. Generic draft-only intermediate points must instead persist only as plain route geometry points in `gpxRoute` and any other geometry caches derived from it. [L3]
7. Peak-derived or explicitly named waypoints remain persistable semantic waypoints. The saved-route model must continue to support named or peak-derived waypoint records, but generic draft-only unnamed intermediates must not be upgraded into saved semantic waypoints. Existing saved routes that already contain legacy generic `Waypoint N` records must reopen with those legacy entries treated as plain route points in the editor, and the next interactive save must stop re-persisting those legacy generic entries as semantic waypoints unless the user explicitly converts a point through `Create Waypoint`. [L3] [L5]
8. When a saved route re-enters edit mode, the full committed `Route path`, not only the saved waypoint list, must become an interactive edit surface. Existing saved geometry points must be selectable from both the map path and the elevation profile, and selecting an existing geometry point must immediately open the current point actions for that exact point. [L4]
9. Rehydration and editing behavior must treat the saved route geometry as the authoritative editable point set. Clicking or hovering a segment position between existing points on the map path or elevation profile must support inserting a new editable route point exactly at that committed-path position, and the interaction model must visually distinguish existing-point targeting from segment-insertion targeting. [L4]
10. Saving route geometry and saved waypoint coordinates from the interactive route editor must round latitude and longitude to six decimal places. Apply this to saved route geometry and any saved semantic waypoint coordinates created by the editor. [L6]
11. The route editor must add explicit named-waypoint creation. Clicking a route point must continue to open the point popup menu, and that menu must add `Create Waypoint` above `Delete`. Named waypoints must render with `Icons.location_pin`. [L5]
12. Creating a named waypoint must produce a semantic saved waypoint distinct from a draft-only numbered route point. `Create Waypoint` must open a naming prompt immediately, trim the submitted name before save, reject blank trimmed names, leave the point as a plain route point if the prompt is cancelled, and allow duplicate waypoint names within the same route. The final saved data model must keep named waypoints and generic plain route points distinct. [L3] [L5]
13. Duplicate point-add handling must change from the current error-producing behavior to a no-op. If the user taps the same effective next point as the current end point, the draft must remain unchanged and must not enter `segmentFailure`. [L7]
14. Marker-limit handling must stop surfacing the current hard error when visible numbered intermediate points exceed ninety-nine. Visible numbered marker labels must display `number mod 100`, while internal point ordering and numbering continue increasing without truncating the underlying route definition. [L7]
15. The route editor must only issue route-draft elevation sampling requests when the drafted route is fully inside the current DEM-supported region model, which is currently Tasmania. If the drafted route is outside DEM-supported coverage, the editor must avoid the request, must not surface an elevation error for that case, and must keep the existing distance-only draft behavior unless a later refinement explicitly changes the DEM-unavailable UX. [L6]
16. During route drafting, hover behavior must remain synchronized with the elevation profile in the same broad way that the track or route info popup currently coordinates hover state with the profile. Map-path hover and elevation-profile hover must stay aligned with the same underlying route position and must distinguish existing-point targeting from segment-insertion targeting. [L8]
17. The route editor must remove `Ctrl+Z` and `Ctrl+Shift+Z` route-drafting shortcuts. Keep the macOS `Cmd+Z` and `Cmd+Shift+Z` shortcuts. [L8]
18. `Close Loop` must first attempt the current normal end-to-start routed close. If that does not produce a usable tracked close, it must then attempt to find the closest usable track connection and route along track geometry back to the start point. If that also fails, it must fall back to a direct straight closing segment. This replaces the current off-track and no-path fallback contract for loop closure. [L9]
19. When the user clicks and drags any route point that is currently on a trail to a new trail, the route editor must reroute through the new route point using the new trail context rather than preserving the old trail segment unchanged. [L11]
20. The implementation must keep route-rules terminology aligned with `GLOSSARY.md`, including preserving the distinction between draft-only numbered route points, plain route points, and semantic saved waypoints. [L3] [L10]
21. Before decomposing this Spec into work items, manually recheck the baseline uncertainty recorded against `route-rules.md` line 125 so later work items do not rely on an incorrect assumption about whether deleting the final point truly clears all markers and geometry. [L10]
22. `Out and Back` and `Close Loop` must not automatically promote a plain route point into a semantic saved waypoint. Non-peak turnaround or loop points remain plain saved route geometry unless the user explicitly converts a point through `Create Waypoint`. Peak-derived points remain persistable semantic waypoints under the existing peak-derived rules, and legacy generic `Waypoint N` turnaround or loop entries must reopen and resave under the same plain-route-point conversion rules defined above. [L3] [L5] [L10]

## Technical Decisions

1. Treat `ai_specs/routes/route-rules.md` as the baseline reference and this Spec as the intended-change follow-up. Do not rewrite the baseline to hide the current implementation once this follow-up exists. [L10]
2. Keep the current route-draft implementation seams centered in `lib/providers/map_provider.dart`, `lib/models/route.dart`, `lib/models/route_waypoint.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/screens/map_screen.dart`, and the existing route widget or robot test seams. [L2] [L4] [L5] [L6] [L8] [L9] [L11]
3. Prefer the smallest model change that cleanly separates semantic saved waypoints from plain saved route geometry. Avoid preserving the current generic `Waypoint N` persistence behavior behind compatibility indirection unless existing persisted data truly requires migration handling. [L3] [L5]
4. Preserve ordinary `Save` as update-in-place semantics during edit sessions and add explicit new-route creation semantics only through edit-session `Save As`. [L1]
5. Prefer DEM-availability gating before elevation sampling requests over request-then-error behavior when the drafted route is outside the currently supported Tasmania DEM coverage model. [L6]
6. Preserve macOS-first desktop interaction conventions in route drafting, including shortcut definitions and hover behavior, unless a later refinement explicitly broadens platform scope. [L8]
7. Extend the route-planner seam as needed to support `Close Loop` closest-usable-track reconnection explicitly, rather than leaving that new behavior to provider-side guessing against the current planner contract. [L9]
8. Resolve the earlier line-210 `discuss` item in favor of this follow-up Spec: `Out and Back` and `Close Loop` remain geometry transforms and must not implicitly create semantic saved waypoints. Semantic saved waypoints created during those flows must still come only from peak-derived points or an explicit `Create Waypoint` action. [L3] [L5] [L10]

## Testing Strategy

1. Use behavior-first TDD for each implementation slice created from this Spec. Start with the smallest failing provider, service, widget, or robot test that captures one rule change, then implement the minimum change to pass before moving to the next slice.
2. Add provider or service-level regression coverage for `Save` versus `Save As`, duplicate-name validation, preserved edit-save metadata, six-decimal coordinate persistence, DEM-aware elevation request gating, duplicate-point no-op behavior, route-point rerouting after drag-to-new-trail, and legacy generic `Waypoint N` conversion on reopen and next save. [L1] [L2] [L3] [L6] [L7] [L11]
3. Add provider or widget-level regression coverage for the revised saved-route rehydration contract, especially proving that reopened routes expose the full saved geometry as actionable edit points through both map-path and elevation-profile interaction, even when not all points are visible markers at once. [L4]
4. Add widget-level regression coverage for the route-point popup and waypoint-prompt contract, including `Create Waypoint` ordering above `Delete`, named-waypoint marker rendering with `Icons.location_pin`, trim-and-blank validation, cancel behavior, and macOS-only shortcut behavior. [L5] [L8]
5. Add widget or robot journey coverage for the user-visible route-editor flows that materially change: edit-save metadata preservation, `Save As`, named waypoint creation, marker-limit behavior beyond ninety-nine visible intermediates, and loop-closing fallback behavior. Use stable app-owned selectors and deterministic planner or elevation fakes. [L1] [L5] [L7] [L8] [L9]
6. Reuse existing deterministic seams for route planning, route elevation sampling, in-memory route storage, and route robot journeys rather than introducing live external dependencies.
7. Save-preservation, waypoint-persistence, and edit-rehydration regression coverage must exercise production `MapNotifier` behavior with repository-backed seams rather than relying only on the simplified `TestMapNotifier.saveRouteDraft` harness path.
8. Before implementation begins, manually recheck the unresolved baseline note about the final-point deletion path and confirm whether an additional baseline correction is needed.

## Open Questions

None.

## Out of Scope

1. Replacing the descriptive baseline in `ai_specs/routes/route-rules.md` with intended future behavior.
2. Redesigning unrelated route export UX, route admin tooling, or route-info-panel walking-speed controls.
3. Redesigning unrelated route save, export, or route-management UX beyond the specific `Save As`, duplicate-name, and waypoint-prompt contracts defined here.
4. Broad cross-platform shortcut redesign beyond removing the Windows-style route-drafting undo shortcuts identified here.
5. Unrelated route-planner architecture changes outside the loop-closing and drag-reroute contracts captured in this follow-up.

## Follow-Ups

1. Update any bounded legacy route docs that still imply automatic generic turnaround or loop waypoint persistence so they align with this follow-up Spec's explicit plain-route-point versus semantic-waypoint contract.

## Notes

1. This Spec is a follow-up to `ai_specs/peak-lists/0033-current-route-creation-and-editing-ruleset/spec.md` and the maintained baseline artifact `ai_specs/routes/route-rules.md`.
2. The proposed change source is the populated `## Proposed Rule Changes` section in `ai_specs/routes/route-rules.md`, including the new functionality note about rerouting after dragging a trail-backed route point to a new trail.
3. Relevant implementation and regression surfaces are expected to include `lib/providers/map_provider.dart`, `lib/models/route.dart`, `lib/models/route_waypoint.dart`, `lib/services/route_elevation_sampler.dart`, `lib/services/route_repository.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/screens/map_screen.dart`, `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, and the route robot journeys.
4. Before decomposition, the baseline uncertainty recorded against `ai_specs/routes/route-rules.md` line 125 was manually rechecked against current implementation and regression coverage and was confirmed accurate at that time.
