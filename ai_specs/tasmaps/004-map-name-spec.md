<goal>
Add a label to Tasmap polygons shown on the map screen so the user can identify the map without opening the admin view.

Only one Tasmap layer should be rendered at a time. The label must render as `name\nseries`, use the same color as the enclosing polygon, and remain readable with a small translucent backing or text shadow/outline. This matters because map browsing is visual-first, and the map name/series must remain readable while preserving the existing Tasmap selection and zoom flows.
</goal>

<background>
The app is a Flutter/Riverpod/ObjectBox project.
Relevant files:
- `./lib/screens/map_screen.dart`
- `./lib/widgets/tasmap_outline_layer.dart`
- `./lib/services/tasmap_repository.dart`
- `./lib/models/tasmap50k.dart`
- `./lib/providers/map_provider.dart`
- `./test/widget/tasmap_refactor_test.dart`
- `./test/robot/tasmap/tasmap_journey_test.dart`

`MapScreen` currently renders Tasmap geometry in two places:
- the selected-map outline via `TasmapOutlineLayer`
- the all-map overlay via `PolygonLayer`

This task should consolidate those into a single active Tasmap display mode so only one layer is visible at a time.

Tasmap rows already provide the label data needed for this feature: `Tasmap50k.name` and `Tasmap50k.series`.
</background>

<user_flows>
Primary flow:
1. The user opens the map screen.
2. One Tasmap display mode is active at a time: overlay, none, or selected-map outline.
3. Each visible polygon shows a lower-right label with the map name on the first line and the series on the second line.
4. The label matches the polygon color, uses the same font size as the MGRS display, and moves with the polygon as the map is panned or zoomed.
5. Tapping the Grid control cycles the Tasmap display mode from overlay -> none -> selected-map outline -> overlay.

Alternative flows:
- Overlay mode: every visible Tasmap polygon shows its label.
- Selected-map mode: only the selected polygon is visible and labeled.
- Returning user: labels should appear automatically whenever the map view is shown; no extra toggle or setup is required.

Error flows:
- Polygon geometry cannot produce a stable label position: render the polygon as usual and omit only the label.
- A Tasmap row has missing label text: render the non-empty part if present, otherwise omit the label.
</user_flows>

<requirements>
**Functional:**
1. Render a Tasmap label for each visible polygon on the map screen.
2. Format the label as `name\nseries`.
3. Render only one Tasmap layer at a time. The Grid control must cycle the visible mode in this order: `showMapOverlay` -> none -> `selectedMap` -> `showMapOverlay`.
4. Place the label at the lower-right corner of the polygon bounds, with a small inset so it reads as attached to the polygon rather than the screen.
5. Use the same foreground color as the polygon outline/border.
6. Render the label text with a small translucent backing or text shadow/outline for legibility, and use the same font size as the MGRS display.
7. Do not render labels when zoom is below 10.
8. Keep the label non-interactive so map gestures still work normally.
9. Preserve existing map behaviors: selection, Goto, zoom-to-map-extent, display-mode toggling, and polygon rendering must not regress.

**Error Handling:**
10. If label placement cannot be computed from the polygon geometry, skip only the label and keep the polygon visible.
11. If `name` or `series` is blank, render only the available line; if both are blank, omit the label.

**Edge Cases:**
12. Labels should remain attached to their polygon during pan/zoom and should not be anchored to the viewport.
13. Do not add collision-avoidance or label deduplication logic unless a later requirement explicitly needs it.

**Validation:**
14. Add a dedicated label widget/helper that takes polygon points and returns a renderable label anchor.
15. Add a small pure formatting helper or equivalent test seam for `name\nseries` rendering and blank-line handling.
16. Add widget tests for the Grid display-mode cycle, label rendering on the selected-map outline, label rendering on the all-map overlay, and label hiding below zoom 10.
17. Add a robot-driven map journey test that verifies a visible map label on the map screen without breaking the existing Goto/select flow.
</requirements>

<boundaries>
Edge cases:
- Maps with fewer than four valid polygon points still stay hidden as they do today; labels should not force them to render.
- Very small polygons may cause label overlap with the boundary; keep the label attached and readable rather than adding complex placement heuristics.
- Labels should not steal taps, drags, or scroll gestures from the map.
- Label rendering should stay off below zoom 10 even if the polygon itself is still visible.

Error scenarios:
- Missing geometry for label placement: omit the label only.
- Missing text fields: show the non-empty portion or omit the label if nothing is available.

Limits:
- This task only changes Tasmap rendering on the map screen.
- Do not change Tasmap import, ObjectBox schema, or map search behavior.
- Do not add a new data field to `Tasmap50k`; the label must be derived from existing `name` and `series` fields.
</boundaries>

<implementation>
Modify these files:
- `./lib/screens/map_screen.dart`
- `./lib/widgets/tasmap_outline_layer.dart` or a small new Tasmap label widget beside it
- `./lib/widgets/tasmap_polygon_label.dart` (or equivalent dedicated helper/widget)
- `./test/widget/tasmap_refactor_test.dart`
- `./test/robot/tasmap/tasmap_journey_test.dart`

Recommended approach:
- Keep outline rendering and label rendering in small reusable widgets so the map screen stays readable.
- Derive label placement from the same polygon points or bounds used for zooming, rather than hardcoding screen coordinates.
- Add stable app-owned `Key` selectors for the label layer so robot and widget tests can target the new behavior deterministically.

What to avoid:
- Do not store label text in provider state; it is a pure rendering concern.
- Do not couple the label to admin/import flows.
- Do not introduce new geometry calculations unless the existing bounds helpers are insufficient.
</implementation>

<stages>
Phase 1: Label seam
- Add the label formatting and placement seam.
- Verify with a focused widget test before touching the full map screen.

Phase 2: Map integration
- Render labels for the selected-map outline and all-map overlay.
- Verify the labels move with the polygon and inherit the expected color.

Phase 3: Journey coverage
- Extend the Tasmap robot journey to confirm a visible label appears after selecting a map.
- Verify the existing Goto and selection behavior still works.
</stages>

<illustrations>
Desired:
- A polygon for `Adamsons` shows a label with `Adamsons` on the first line and `TS07` on the second line.
- The label is blue if the polygon outline is blue.
- The label uses the same font size as the MGRS display and has a small translucent backing or text shadow.
- Panning the map keeps the label attached to the same polygon.
- Tapping Grid cycles overlay -> none -> selected-map outline.

Avoid:
- Putting the label in the top-left HUD instead of on the polygon.
- Recomputing map names from the CSV at render time.
- Making the label interactive or requiring a tap to reveal it.
</illustrations>

<validation>
Follow TDD vertically:
- Start with the pure label-formatting/placement seam.
- Add one widget test for the Grid display-mode cycle and zoom-threshold visibility.
- Add one widget test for selected-map label rendering.
- Add one widget test for overlay label rendering.
- Add the robot journey assertion last, once the label is stable in the widget layer.

Required automated coverage:
- Logic/business rules: label text formatting and blank-field handling.
- UI behavior: label renders on polygons, uses the right color, remains attached to the map polygon, and hides below zoom 10.
- UI behavior: Grid cycles the Tasmap display mode so only one Tasmap layer is rendered at a time.
- Robot journey: map screen shows the label during the standard map-selection flow.

Testability seams:
- A deterministic helper for formatting `name\nseries`.
- A reusable widget or layer for polygon labels and label anchors.
- Stable keys for the label layer and, if needed, per-label nodes.

Run `flutter analyze` and `flutter test` at the end, and keep the label tests deterministic with fake Tasmap data instead of live ObjectBox writes.
</validation>

<done_when>
The task is complete when:

- Every visible Tasmap polygon on the map screen shows a lower-right `name\nseries` label.
- The label uses the same color as the polygon outline.
- Existing map interactions still work.
- Widget and robot coverage prove the label renders in both the selected-map and overlay cases.
</done_when>
