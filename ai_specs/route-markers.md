<goal>
Define a single reusable route marker widget for the map UI that can render three visual variants: a simple circle marker, a target marker, and a filled numbered marker.
This matters because route markers should be visually distinct while staying simple, consistent, and easy to maintain in one code path.
</goal>

<background>
Route draft markers are currently rendered in `./lib/screens/map_screen_layers.dart` using a circular container shape.
The app already uses one-off marker widgets and SVG assets elsewhere, but this change should not introduce three separate marker implementations for route markers.
Shared marker sizing, font sizing, and stroke constants should live in `./lib/core/constants.dart` inside `RouteUI` so the map layer and marker widget use one source of truth.
RouteUI should define `markerSize = 20.0`, `markerMinSize = 14.0`, `markerFontSize = 6.0`, `markerNumberedSize = 16.0`, `strokeWidth = 3.0`, and `strokeDarkenAlpha`.

Route marker variants are derived from the current ordered route draft state on each `MapState` update:
- the first point renders as `circle`
- the last point renders as `target`
- middle points render as `numbered`, with numbers assigned sequentially while skipping peak markers
- if a peak marker exists in the draft, it remains unchanged and the numbered sequence skips over it
- if a target overlays the start point in an out-and-back draft, the target is painted above the circle

Relevant files to examine and align with:
@./lib/screens/map_screen_layers.dart
@./lib/providers/map_provider.dart
@./lib/screens/map_screen.dart
@./test/widget/map_screen_route_sheet_test.dart

Keep the route marker rendering local to the map layer path and avoid introducing a parallel marker framework.
</background>

<discovery>
Confirm the current route marker call sites and decide how each marker variant is selected.
Verify that the route marker numbering is derived from route draft ordering rather than passed in explicitly.
Use one widget class plus one enum for the visual variants.
</discovery>

<user_flows>
Primary flow:
1. The app creates a route marker for the map layer.
2. The marker kind is derived from the current ordered draft state.
3. A single-point draft renders as a circle only.
4. A two-point draft renders as circle + target.
5. A three-or-more-point draft renders as circle + numbered middle points + target.
6. Peak-derived markers remain unchanged and the numbering skips over them.
7. Out-and-back drafts render the target above the start circle when both share the same location.
8. Route to Peak remains disabled until the first draft point has been placed.
9. Once a draft has returned to its start point, both Route to Peak and Out and Back are disabled to prevent duplicate loops.
10. The marker renders with consistent sizing and stroke behavior.
11. The numbered variant shows a label from 1 to 99.
12. The marker remains readable and stable at normal map marker sizes.
</user_flows>

<requirements>
**Functional:**
1. Add a single widget class named `RouteMarker` for route marker rendering.
2. Add a single enum named `RouteMarkerKind` with exactly these variants: `circle`, `target`, and `numbered`.
3. The `RouteMarker` API must support at least `kind`, `color`, `number`, `size`, and `strokeWidth`, with the default size, font size, minimum size, stroke width, and stroke darken/alpha value coming from `RouteUI` in `./lib/core/constants.dart`.
4. The circle variant must render a white-filled circle with a colored stroke.
5. The target variant must render a target-style marker using a single consistent rendering path, with an outer ring and a centered inner dot on a white background.
6. The numbered variant must render a filled circle with a darker same-hue stroke and a centered white number from 1 to 99.
7. The numbered variant must clamp out-of-range values into the visible range `1..99`.
8. The numbered marker stroke must use a fixed darken/alpha transform value defined in `RouteUI`.
9. The number text must stay centered and legible at the default marker size.
10. `RouteUI` must define a minimum supported marker size of `14.0` and a font size of `6.0`.
11. `RouteUI` must also define a numbered-marker size of `16.0` for the numbered variant.
12. The route marker implementation must use one internal approach for all variants instead of three separate widget classes.
13. The filled numbered marker stroke must be the same hue as the fill color but visibly darker.

**Error Handling:**
14. Missing or invalid `number` input for the numbered variant must fail safe by clamping or defaulting to a valid visible value.
15. Invalid variant/state combinations must not crash the map; prefer a visible fallback over a silent failure.
16. When the 100th route point would be added, the draft must be rejected before it is added and the existing inline route error message must show: `Peak Bagger only supports a maximum of 99 route points`.

**Edge Cases:**
17. Small marker sizes must not clip the number label or ring stroke.
18. Large marker sizes must preserve centered alignment and proportional stroke widths.
19. If the marker is used on high-density displays, the text and strokes must remain crisp enough for map use.
20. The shared marker size, numbered-marker size, minimum size, font size, and stroke width values in `RouteUI` must be reused consistently by every route marker variant.

**Validation:**
21. Add widget coverage for all three marker kinds.
22. Add widget coverage for numbered marker clamping and label centering.
23. Add a map-layer-level test proving the route draft layer now renders `RouteMarker` instead of the old container implementation.
24. Keep the route marker tests focused on the widget output and not on unrelated map behavior.
</requirements>

<boundaries>
Edge cases:
- Do not introduce separate circle/target/numbered widget classes.
- Do not duplicate marker visuals in SVG assets unless there is a later product need.
- Do not change peak marker rendering or unrelated map overlays.

Limits:
- This is a UI-only marker design change.
- Do not alter route planning, route persistence, or marker hit testing behavior.
- Prefer the smallest maintainable widget composition that satisfies the three visual kinds.
</boundaries>

<implementation>
Modify or create the following files:
- `./lib/widgets/route_marker.dart` create the shared marker widget and `RouteMarkerKind` enum.
- `./lib/screens/map_screen_layers.dart` switch route marker rendering to the new widget.
- `./test/widget/map_screen_route_sheet_test.dart` or a focused widget test file to validate the three visual kinds.

Use a single composition path inside `RouteMarker`. A `SizedBox` with `Stack`/`Container`/`Text` is the recommended starting point for readability and consistency.
If profiling later shows the widget path is a bottleneck, a `CustomPainter` can replace the internal drawing logic, but that is not the default requirement for this slice.

Keep the public API minimal and explicit so callers only choose the marker kind and, when needed, the marker number.
</implementation>

<stages>
Phase 1: Define the widget API.
- Add `RouteMarkerKind` and `RouteMarker` with the three supported variants.
- Confirm the widget can render the circle, target, and numbered appearances from one API.

Phase 2: Wire the map layer.
- Replace the current route marker container usage with `RouteMarker`.
- Keep the existing map layer keys and hitbox behavior intact.

Phase 3: Add coverage.
- Add widget tests for each variant.
- Add a numbered-marker clamp test and a basic layout sanity check.
</stages>

<validation>
Required automated coverage outcomes:
- Logic/business rules: numbered markers clamp to the range `1..99`.
- UI behavior: each marker variant renders the correct visual structure.
- UI behavior: the target marker and circle marker remain centered and proportional.

Test expectations:
1. Add one test for each variant instead of splitting the widget into multiple classes.
2. Verify the numbered variant renders the correct label for at least one low and one high value.
3. Verify the circle variant has the white fill and colored stroke.
4. Verify the target variant has the ring-plus-center-dot structure.
5. Verify Route to Peak remains disabled until the first draft point exists, and both Route to Peak and Out and Back disable after a closed loop.
6. Keep the tests deterministic and focused on the widget API, not on map gestures.
</validation>

<done_when>
The work is complete when route markers are rendered through a single `RouteMarker` widget and `RouteMarkerKind` enum, the circle/target/numbered variants are visually distinct, numbered markers clamp to `1..99`, and the behavior is covered by widget tests without adding multiple parallel marker implementations.
</done_when>
