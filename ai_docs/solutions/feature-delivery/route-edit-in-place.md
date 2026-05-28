---
title: Route Draft In-Place Editing
date: 2026-05-28
work_type: feature
tags: [flutter, riverpod, map-interactions, testing]
confidence: high
references: [ai_specs/route-edit-spec.md, ai_specs/route-edit-plan.md, lib/providers/map_provider.dart, lib/screens/map_screen.dart, lib/screens/map_screen_layers.dart, lib/screens/map_screen_panels.dart, lib/widgets/map_route_bottom_sheet.dart, test/providers/route_draft_state_test.dart, test/widget/map_screen_route_sheet_test.dart, test/widget/map_screen_route_hover_test.dart, test/widget/map_screen_keyboard_test.dart, test/robot/map/map_route_journey_test.dart]
---

## Summary

Delivered in-place editing for route drafts: markers can be dragged, deleted through a transient popup, and restored with undo/redo without restarting the draft.

The key implementation choice was to keep editing inside the existing `MapNotifier` route draft state machine. History snapshots, monotonic request/version counters, and rebuild-from-control-endpoints let live drag, delete, `Out and Back`, and `Close Loop` share one source of truth.

## Reusable Insights

- Prefer provider-led snapshots over a separate editor model when edits must interact with async routing and existing draft modes. Undo/redo was simplest when it restored full route-draft snapshots instead of replaying individual operations.
- Keep request/version counters monotonic across history navigation. That made stale routing and elevation responses stay stale after undo/redo.
- For marker editing, split gesture intent early: pointer-down starts drag state, click opens the delete popup, and a drag threshold prevents accidental deletion.
- Consume marker clicks before they reach the map tap path. That avoids adding a new point when the user meant to open the delete popup.
- Lock route-to-peak fallback once the edited peak target is invalidated. Clearing the target and disabling `Route to Peak` is safer than falling back to `peakInfoPeak` or `selectedLocation` implicitly.
- Restore closed-loop and out-and-back edits by reopening the draft into ordinary editable geometry, then let undo bring back the previous topology.
- Robot coverage is much easier with stable key-first selectors on route markers, undo/redo buttons, popup actions, and marker hitboxes.

## Validation

- Provider tests covered move/delete history, terminal marker recovery, closed-loop reopening, peak-target invalidation, and stale drag handling.
- Widget tests covered popup behavior, route sheet controls, keyboard shortcuts, and the `Route to Peak` enablement rules.
- Robot coverage validated the end-to-end edit-and-save flow.

Confidence is high because the behavior is covered at provider, widget, and robot layers and the plan file was reconciled with the landed implementation.
