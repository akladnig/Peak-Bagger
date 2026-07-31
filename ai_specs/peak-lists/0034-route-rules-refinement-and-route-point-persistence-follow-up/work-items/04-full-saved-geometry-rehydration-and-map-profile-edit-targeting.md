---
type: Work Item
title: Full Saved Geometry Rehydration And Map Profile Edit Targeting
parent: ../spec.md
---

## What to build

Make the full committed saved `Route path` the authoritative editable point set when a saved route re-enters edit mode, not only the saved waypoint list. Implement this as a vertical Flutter slice through provider state, map interaction, elevation-profile interaction, and regression coverage so existing saved geometry points are actionable from both the map path and elevation profile, and segment insertion targets remain distinct from existing-point targets while hover state stays synchronized across both surfaces.

## Required context

- `lib/providers/map_provider.dart` owns edit-mode rehydration, point selection, current point actions, hover synchronization state, and segment-insertion behavior.
- `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, and the route profile widgets own map-path hit testing, hover plumbing, and elevation-profile interaction.
- `ai_docs/solutions/feature-delivery/route-edit-in-place.md` documents the shipped provider-led edit model, drag intent split, and stable-selector expectations that this slice should preserve where still valid.
- `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_route_draft_hover_test.dart`, `test/widget/map_screen_route_hover_test.dart`, `test/widget/map_route_info_panel_test.dart`, and `test/widget/map_screen_route_sheet_test.dart` are the main deterministic seams for rehydration, hover, insertion, and route-point action coverage.
- `test/robot/map/map_route_journey_test.dart` is the visible journey seam when an end-to-end re-edit flow needs robot coverage with stable selectors.

## Acceptance criteria

- [ ] Behavior-first TDD starts with failing provider or widget coverage against production `MapNotifier` behavior for saved-route rehydration, exact-point selection, and segment insertion before implementation changes are made.
- [ ] Reopening a saved route makes the full committed saved `Route path`, not only the saved waypoint list, the authoritative editable point set even when not all saved points are rendered as visible markers at once.
- [ ] Existing saved geometry points are selectable from both the map path and the elevation profile, and selecting an existing geometry point immediately opens the current point actions for that exact point.
- [ ] Clicking or hovering a segment position between existing points on the map path or elevation profile inserts a new editable route point at that committed-path position rather than targeting a different point, and the interaction model visibly distinguishes existing-point targeting from segment-insertion targeting.
- [ ] During route drafting and edit mode, hover behavior remains synchronized between the map path and elevation profile over the same underlying route position.
- [ ] Regression coverage for the changed map and profile interactions uses stable selectors and deterministic planner and elevation seams where needed.

## Covers

- User Stories: 4, 8
- Requirements: 8-9, 16
- Technical Decisions: 2-3, 6
- Testing Strategy: 1, 3, 5, 7
- Interview Ledger: L4, L8

## Blocked by

- `03-plain-route-geometry-persistence-and-named-waypoint-creation.md`
