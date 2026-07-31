---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: How should ordinary `Save` and the new `Save As` differ for existing saved routes?

Answer: Add `Save As` functionality which requires duplicate name checking, while ordinary edit `Save` remains update-in-place for the existing route rather than acting like `Save As`.

Decision: Keep ordinary edit `Save` as same-route persistence and introduce a distinct duplicate-checked `Save As` path for new-copy persistence.

### L2

Status: current

Question: Which source-route metadata must stop being dropped on interactive edit save?

Answer: `desc` and `walkingSpeedKmh` from the source `Route` are to be preserved.

Decision: Future edit-save behavior must preserve `desc` and `walkingSpeedKmh` unless the edit flow explicitly changes them.

### L3

Status: current

Question: Should unnamed generic intermediate draft waypoints persist as saved semantic waypoints?

Answer: No. Generic waypoints are for route draft and should be saved as a plain route point. Generic waypoints are not to persist as saved waypoints.

Decision: Draft-only generic unnamed intermediates remain plain saved route geometry and must not persist as semantic saved `RouteWaypoint` records.

### L4

Status: current

Question: What should happen to saved route points when an existing route re-enters edit mode?

Answer: All waypoints are to become editable, but they do not need specific markers and do not need to become visible editable control points. However, it should be possible to select any point and apply the current actions such as delete and move.

Decision: Rehydrated saved routes must expose the full saved point set as actionable edit targets even if only a subset is rendered as visible markers.

### L5

Status: current

Question: What explicit waypoint-creation affordance should the route editor add?

Answer: Add an icon for a named waypoint `Icons.location_pin`. Clicking on a point brings up the popup menu, with a new option `Create Waypoint` to sit above `Delete`.

Decision: The future route editor must support explicit named-waypoint creation through the point popup and must render named waypoints with `Icons.location_pin`.

### L6

Status: current

Question: How should elevation sampling and coordinate precision change?

Answer: Elevation requests should only be made if DEM is available for the region in question. On route save, latitude and longitude are to be saved to six decimal places only.

Decision: Gate route-draft elevation sampling on DEM availability and round saved route coordinates to six decimal places.

### L7

Status: current

Question: How should duplicate-point and marker-limit behavior change?

Answer: Duplicate handling is to be changed to be a no-op. Instead of a marker-limit error, the display marker should be `number mod 100`, while the internal numbers keep incrementing.

Decision: Replace duplicate-point failure with a no-op and replace the current visible ninety-nine-point hard error with wrapped marker labels over an unbounded internal sequence.

### L8

Status: current

Question: Which desktop-interaction changes are desired for hover and shortcuts?

Answer: During route drafting the hover marker should move along the elevation profile as per the current behaviour in the track or route info popup. Remove `Ctrl+Z` and `Ctrl+Shift+Z` shortcuts because they are Windows specific and this app is macOS only.

Decision: Keep route-drafting hover synchronized with the elevation profile and remove Windows-style route-drafting undo shortcuts, preserving macOS command-key shortcuts only.

### L9

Status: current

Question: How should `Close Loop` behave when trying to return to the start?

Answer: Change it so that it first attempts to find the closest track and route along the track back to the start and falls back to a direct straight line closing segment.

Decision: Replace the current loop-closing fallback contract with track-first closure and straight-line fallback.

### L10

Status: current

Question: What should happen to the baseline artifact and related route-edit follow-up when the current implementation disagrees with the intended rules?

Answer: Update the spec to reflect the current state where needed, but the route-edit spec is correct and the implementation is to be updated to match it. One baseline point also needs manual confirmation, and one listed disagreement remains `discuss`.

Decision: Keep the baseline descriptive, treat the route-edit intent as the future-state target, and carry forward the unresolved baseline confirmation and `discuss` item as explicit open questions instead of silently resolving them.

### L11

Status: current

Question: What new route-point drag behavior is desired beyond the current baseline?

Answer: When clicking and dragging any route point that is currently on a trail to a new trail, the autorouting should reroute via the new route point.

Decision: Trail-backed drag edits must reroute through the moved point using the new trail context instead of preserving the previous trail path unchanged.
