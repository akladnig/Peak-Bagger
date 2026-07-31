---
type: Work Item
title: Route Persistence Rehydration Metadata And Inconsistency Capture
parent: ../spec.md
---

## What to build

Complete `ai_specs/routes/route-rules.md` by documenting the exact current save-time persistence, rehydration, metadata, and inconsistency behavior for interactive map `Route` creation and editing. Capture what is persisted on save, what is not persisted, how saved routes are rehydrated into edit mode, how saved route points and waypoints become draft structures again, how imported or externally created routes affect later editing once they already exist in the app, and how stale selected-route and stale source-route reconciliation behaves when a route disappears. Document the current derived metadata behavior for draft distance, elevation-summary loading and error states, sampled point elevations, save-time recalculation and fallback behavior, and timing-profile preservation or extension when editing existing routes. Populate `Implementation Inconsistencies` with at least the current mismatch where non-final intermediate points can be saved as generic named `Waypoint N` entries even though `Numbered route point` is the preferred draft-only concept, plus disagreements between current code or tests and the bounded legacy route-doc set named by the Spec.

## Required context

- `lib/providers/map_provider.dart` is the primary source of truth for route save payload construction, point and waypoint rehydration into draft state, source-route reconciliation, sampled elevations, distance and elevation summary state, and timing-profile carry-forward or extension.
- `lib/models/route.dart`, `lib/models/route_waypoint.dart`, `lib/services/route_repository.dart`, `lib/services/route_elevation_sampler.dart`, and `lib/services/route_timing_service.dart` define the persisted route data shape and the current metadata recalculation and fallback behavior the baseline must describe exactly.
- `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, and `test/robot/map/route_info_journey_test.dart` provide the strongest current evidence for save behavior, re-edit rehydration, stale selected-route and source-route handling, and timing carry-forward.
- Review these bounded legacy docs only as conflicting context and record disagreements under `Implementation Inconsistencies`: `ai_specs/routes/route_bottom-sheet-spec.md`, `ai_specs/routes/route-hover-spec.md`, `ai_specs/routes/route-edit-spec.md`, `ai_specs/routes/route-out-and-back-spec.md`, `ai_specs/route-to-peak-track-then-straight-spec.md`, and `ai_specs/routes/route-loop-spec.md`.

## Acceptance criteria

- [ ] The baseline documents the current saved-data contract for interactive route creation and editing, including what route-point or waypoint data is persisted, what draft-only state is not persisted, and how saved routes re-enter edit mode.
- [ ] The baseline documents how saved or externally created route data is interpreted when editing starts, including how saved route points and waypoints become current draft structures again.
- [ ] The baseline captures current derived metadata behavior for draft distance, elevation sampling, elevation loading and error states, sampled point elevations, save-time recalculation and fallback behavior, and timing-profile preservation or extension when editing an existing route.
- [ ] `Implementation Inconsistencies` explicitly records the persisted generic `Waypoint N` mismatch against the preferred `Numbered route point` terminology instead of normalizing it away.
- [ ] `Implementation Inconsistencies` also records disagreements, if any, between current code or regression tests and the bounded legacy route-doc review set named by the Spec.
- [ ] This slice preserves exact implemented contracts and quoted text where needed and keeps `Proposed Rule Changes` empty for later refinement work.

## Covers

- User Stories: 1-3
- Requirements: 1-5, 8-9, 14-16
- Technical Decisions: 1-5
- Testing Strategy: 1-4
- Interview Ledger: L1-L3, L5-L6, L8-L10

## Blocked by

- `01-route-rules-artifact-skeleton-and-draft-lifecycle-baseline.md`
