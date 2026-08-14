---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which UI surfaces should receive route and track icons and destructive-icon updates?

Answer: Only the track/route info popup in the map screen.

Decision: Restrict the visual updates to `MapTrackInfoPanel`; leave search, ObjectBox Admin, peak-ascent rows, dialogs, and every other UI surface unchanged.

Answer History:
- Initial recommendation included the map track/route selection popup and info panel.
- Final answer narrows the change to the map screen's track/route info popup only.

### L2

Status: current

Question: What icon should precede the displayed name in the map track/route info popup?

Answer: Use `Icons.hiking` for a track and `Icons.route` for a route.

Decision: The `MapTrackInfoPanel` header must show the type-specific icon immediately before the displayed track or route name.

### L3

Status: current

Question: Which existing trash action in scope should change, given that the route popup has no trash action?

Recommended Answer:
- Replace the track-info popup's peak-correlation removal `Icons.delete_outline` with red `Icons.delete_forever`.
- Do not add a route delete action or modify the peak-info popup's equivalent removal control.

Answer: agreed

Decision: Update only the map track-info popup's peak-correlation removal icon to red `Icons.delete_forever`, retaining its existing action, semantics, tooltip, confirmation, busy, and error behavior.
