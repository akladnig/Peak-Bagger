# Route Hover
## Goal
Adds hover capability to route creation

- When a user moves the mouse over a draft route marker, the marker should highlight visually without changing route geometry, numbering, save behavior, or export behavior.
- On hovering over a draft route segment, display a movable circle-style placement marker at markerNumberedSize.
- Change the cursor to a pointing finger while hovering the segment.
- Keep the placement marker tracking the cursor until click.
- On map pointer-up while preview is active, insert the preview point into the ordered draft segment, recompute numbering, and change it to a target marker; the preview marker itself does not commit.
- After an insert, the next click continues from the last committed endpoint.
