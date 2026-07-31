---
type: Work Item
title: Route Rules Artifact Skeleton And Draft Lifecycle Baseline
parent: ../spec.md
---

## What to build

Create the maintained route-rules artifact at `ai_specs/routes/route-rules.md` with separate `Current Behavior Baseline`, `Implementation Inconsistencies`, and `Proposed Rule Changes` sections. In this slice, populate the baseline with the current interactive map `Route` drafting and edit-entry lifecycle exactly as implemented today: `Create Route` entry from the map action rail, edit entry from the selected-route info panel, draft state transitions across inactive, awaiting start, awaiting next point, routing-segment in progress, and segment-failure states, exact visible helper and loading and validation copy such as `Tap a point to start routing`, `Routing...`, `Sampling elevation...`, and `A Route name must be entered`, current save enablement, current cancel and save exit behavior, current route-panel restoration, and current stale selected-route or stale source-route handling when a route disappears during selection or editing. Use the canonical terminology from `GLOSSARY.md`, keep this slice strictly descriptive of current behavior, and leave `Proposed Rule Changes` reserved for later work.

## Required context

- `GLOSSARY.md` defines the canonical `Route`, `Route point`, `Numbered route point`, `Hover point`, `Waypoint`, `Route path`, and `Route segment` language that this baseline must use.
- `lib/providers/map_provider.dart` is the primary source of truth for draft lifecycle state, save enablement, cancel and save restoration, and stale selected-route or source-route reconciliation.
- `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, and `lib/widgets/map_route_bottom_sheet.dart` define the current route-drafting entry points, panel handoff, overlay visibility, and exact user-visible copy.
- `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/robot/map/route_info_journey_test.dart` are especially authoritative for the implemented lifecycle, panel restoration, exact copy, and stale-route disappearance behavior.

## Acceptance criteria

- [x] `ai_specs/routes/route-rules.md` exists and includes separate `Current Behavior Baseline`, `Implementation Inconsistencies`, and `Proposed Rule Changes` sections.
- [x] This slice populates the baseline only with current lifecycle behavior for the interactive map `Route` drafting and editing flow and does not broaden scope into GPX import-as-route, route-info-panel walking-speed or timing edits, route visibility or export flows, admin route editing or deletion, or unrelated app navigation.
- [x] The baseline documents the current `Create Route` entry path, selected-route edit entry path, and the current cancel and save exits exactly as implemented, including route-panel restoration and route disappearance handling during selection or edit mode.
- [x] The baseline names the current draft-state model and transitions using the implemented lifecycle, and preserves exact quoted user-visible labels where the document cites helper, loading, or validation copy.
- [x] The baseline uses the canonical route terminology from `GLOSSARY.md` consistently and treats current code and regression tests as authoritative when older docs disagree.
- [x] `Proposed Rule Changes` remains reserved for later work in this slice.

## Covers

- User Stories: 1-2
- Requirements: 1-4, 6, 9-10
- Technical Decisions: 1-3, 5
- Testing Strategy: 1-3
- Interview Ledger: L1-L4, L6, L10

## Blocked by

None - ready to start
