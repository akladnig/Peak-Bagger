# Route Hover
## Goal
Adds hover capability to route creation

- When a user moves the mouse over a draft route marker, the marker should highlight visually without changing route geometry, numbering, save behavior, or export behavior.
- On hovering over a draft route segment, display a movable circle-style placement marker at markerNumberedSize.
- Keep the placement marker centered on the visible committed route path, including route geometry between control markers.
- Change the cursor to a pointing finger while hovering the segment.
- Keep the placement marker tracking the nearest point on the visible route path until click.
- On map pointer-up while preview is active, insert the preview point into the ordered draft segment and the specific hovered committed polyline segment, recompute numbering, and change it to a numbered marker; the preview marker itself does not commit.
- If no numbered markers exist yet, assign the inserted marker number `1`.
- Otherwise assign the inserted marker the next number from the start of the hovered segment and renumber subsequent numbered markers.
- After an insert, the next click continues from the last committed endpoint.
