# Route Rules

## Current Behavior Baseline

This artifact records the current interactive map `Route` drafting and editing behavior exactly as implemented today. The baseline below is reconciled against the current provider, widget, and robot seams in `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_route_draft_hover_test.dart`, `test/widget/map_screen_route_hover_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/robot/map/map_route_journey_test.dart`. Where older notes disagree, current code and those deterministic tests win.

### Entry And Edit Handoff

- `Create Route` starts from the map action rail `Create Route` action.
- Starting `Create Route` closes or dismisses the end drawer, peak info popup when a peak target is active, drive ETA popup, map info popup, Search popup, goto input, map tap action popup, favourites popup, and the track/route chooser.
- Starting `Create Route` clears the selected `Track` and selected `Route`, keeps the current selected location unchanged, focuses the map, and shows the left route graph overlay plus the right route controls overlay.
- `Edit Route` starts from the selected-`Route` shared info panel `Edit Route` button.
- Starting `Edit Route` immediately clears the selected `Route`, hides the shared info panel, and stores the saved `Route` id as `sourceRouteId` for later restore-on-cancel or restore-on-save behavior.
- `Edit Route` rehydrates the draft from the saved `Route`: route name, colour, committed `Route path`, saved point elevations, saved distance and elevation summary, and the editable saved `Route point` set.
- During `Edit Route`, visible editable `Route point`s are rebuilt from the saved start `Route point`, saved `Waypoint`s, and the saved end `Route point`. The full saved `Route path` still remains the committed geometry even when not every geometry vertex becomes a visible editable `Route point`.
- If the saved `Route` ends in a peak-derived `Waypoint`, edit mode starts in `Route to Peak`. Otherwise it starts in `Snap to Trail`.

### Draft State Model

- `inactive`: no active route draft exists and neither draft overlay is shown.
- `awaitingStart`: a fresh draft is open with no committed `Route path`. This is the initial `Create Route` state. The route name is empty, the inline validation text is `A Route name must be entered`, and the helper text is `Tap a point to start routing`.
- `awaitingNextPoint`: the draft has at least a start `Route point` and is ready for the next `Route point`. Existing saved routes with 2 or more committed points reopen here.
- `routingSegment`: asynchronous `Route segment` planning is in progress for the next added `Route point` or for a `Close Loop` return leg. The overlay shows `Routing...`, map taps that would add more `Route point`s are ignored, mode changes are blocked, and save is disabled.
- `segmentFailure`: the most recent `Route segment` attempt failed, or the user tried to route from a `Route point` to the same `Route point`. The current error text is shown inline. A `Retry` button is only shown for route-graph-load failures.

### Current State Transitions

- `inactive -> awaitingStart`: `Create Route` starts a new draft.
- `inactive -> awaitingStart` or `awaitingNextPoint`: `Edit Route` starts a draft from the saved `Route`. Saved routes with fewer than 2 committed points reopen in `awaitingStart`; otherwise they reopen in `awaitingNextPoint`.
- `awaitingStart -> awaitingNextPoint`: the user taps the first `Route point` in `Snap to Trail` or `Straight Line` mode.
- In `Straight Line`, the first committed `Route path` point is recorded immediately. In `Snap to Trail`, committed `Route path` geometry stays empty until a second `Route point` is added.
- `awaitingStart -> routingSegment`: the user taps the first `Route point` while the draft is in `Route to Peak`. The app creates a start `Route point` plus a peak-derived end `Route point` and begins planning that `Route segment`.
- `awaitingNextPoint -> routingSegment`: the user adds a new `Route point` in `Snap to Trail` or `Route to Peak`, or presses `Close Loop`.
- `awaitingNextPoint -> awaitingNextPoint`: the user adds a new `Route point` in `Straight Line`, or an `Out and Back` or successful `Close Loop` operation finishes appending geometry.
- `routingSegment -> awaitingNextPoint`: asynchronous planning returns a usable result. Current code treats routed results, current no-path fallback handling, and current off-track fallback handling as successful completion paths back to `awaitingNextPoint`.
- `routingSegment -> segmentFailure`: asynchronous planning or endpoint probing fails.
- `segmentFailure -> routingSegment` or `awaitingNextPoint`: the next `Route point` tap retries from the current end `Route point` using the same rules as `awaitingNextPoint`, and the `Retry` button triggers a rebuild flow for route-graph-load failures.
- `awaitingNextPoint` or `segmentFailure -> segmentFailure`: the user picks the same start and end `Route point`, and the draft shows `Start and end points must be different to calculate a route.`.
- Any active draft state -> `inactive`: `Cancel`, successful save, stale source-route reconciliation, or explicit draft end closes the draft.

### Visible Copy And Save Behavior

- Helper copy: `Tap a point to start routing`
- Segment loading copy: `Routing...`
- Elevation loading copy: `Sampling elevation...`
- Name validation copy: `A Route name must be entered`
- Stale edit snackbar copy: `Route is no longer available.`
- Save failure snackbar prefix: `Failed to save route:`
- The `Save` button is enabled only when the committed `Route path` has at least 2 points, the trimmed route name is non-empty, the draft is not in `routingSegment`, and a save is not already in progress.
- `Save` is not additionally blocked by `segmentFailure`. If the other conditions are satisfied, the current UI still enables save from that state.
- Pressing save with a blank trimmed route name or with fewer than 2 committed `Route path` points returns early and keeps or sets the inline route-name validation state instead of closing the draft.
- While save is running, the `Save` button switches from text to a spinner.
- When the draft already has distance but its elevation sample is still being recomputed, the route graph overlay shows `Sampling elevation...` beside the current distance.

### Exit, Restore, And Stale-Route Behavior

- Cancelling a new unsaved draft ends drafting, removes both draft overlays, and does not restore a route info panel.
- Saving a new `Route` persists the current `Route path`, sampled point elevations, derived elevation summary, and saved `Waypoint`s. It also forces routes visible, ends drafting, and does not automatically reselect the newly saved `Route`.
- Cancelling an edit closes the draft and reselects the original saved `Route` id, which reopens the shared route info panel for that `Route`.
- Saving an edit writes back to the same saved `Route` id, closes the draft, and reselects that same `Route` so the shared route info panel reopens with the saved values.
- If saving an edit throws, the draft stays open, `isSavingRoute` is cleared, and the pending snackbar message starts with `Failed to save route:`.
- If the source `Route` disappears during edit reconciliation or immediately before save, the app shows `Route is no longer available.`, closes the draft without restoring selection, and leaves the route info panel hidden.
- If a selected `Route` disappears while it is only selected, the selected `Route` is cleared and the shared route info panel hides.

### Route Point Classes And Current Meanings

- `Hover point`: a temporary desktop-only preview point shown over an editable committed `Route path` segment while the pointer is close enough to that segment and not too close to an existing visible draft marker. It is not yet part of the draft until the user clicks to insert it or drags far enough to commit it into the draft.
- `Numbered route point`: the current draft-only visible intermediate `Route point` class. Visible non-peak intermediate points are rendered as numbered markers labelled `01` through `99`. The number is rebuilt from the current visible order every time the draft control endpoints are rebuilt.
- `Plain route point`: the current unnamed `Route point` class whenever a point is not being shown as a numbered draft intermediate point and is not a saved named `Waypoint`. In current implementation this includes the start `Route point`, the current end `Route point`, and hidden projected-anchor control points that preserve routed geometry but do not render a visible marker.
- `Waypoint`: a saved named `Route point` persisted with a `Route`. During `Edit Route`, visible editable `Route point`s are rebuilt from the saved start `Route point`, saved `Waypoint`s, and the saved end `Route point` rather than from every geometry vertex in the saved `Route path`.
- The first visible draft `Route point` is always shown as the start-circle marker.
- Any visible peak-derived `Route point` is shown with the target marker even when it is not the final visible point.
- The final visible non-peak `Route point` in an open draft is also shown with the target marker.
- Any other visible non-peak intermediate `Route point` is shown as a numbered marker.
- Current save behavior still persists unnamed intermediate draft `Route point`s as generic saved `Waypoint`s labelled `Waypoint 1`, `Waypoint 2`, and so on.

### Current Route Point Add, Insert, Move, And Delete Behavior

- While route drafting is active, map taps stop performing normal selection behavior for peaks, tracks, and routes. If a `Hover point` preview is active, the tap inserts there first; otherwise the tap appends a new `Route point` at the tapped map location.
- Tapping directly on a peak while drafting adds a `Route point` instead of opening the peak info popup.
- The first tap in `Straight Line` or `Snap to Trail` creates the start `Route point` and moves the draft to `awaitingNextPoint`.
- In `Straight Line`, that first tap also writes the first committed `Route path` point immediately.
- In `Snap to Trail`, the committed `Route path` stays empty until a second `Route point` is added.
- In `Route to Peak`, the first tap creates the start `Route point`, creates or reuses a peak-derived end `Route point`, and immediately starts routing that `Route segment` to the captured peak target.
- After the draft already has a start point, `Straight Line` appends the next `Route segment` immediately as direct geometry.
- After the draft already has a start point, `Snap to Trail` and `Route to Peak` start asynchronous `Route segment` planning for the new point.
- Current duplicate handling is not a no-op. If the next tapped point exactly matches the current end `Route point`, the app still appends a duplicate end `Route point`, moves the draft to `segmentFailure`, and shows `Start and end points must be different to calculate a route.`.
- Current marker-limit handling counts only visible numbered intermediate `Route point`s, not the start marker, target marker, or hidden projected anchors. When the visible numbered count has already reached 99, the next add attempt leaves the draft points unchanged and shows `Peak Bagger only supports a maximum of 99 route points`.
- The `Hover point` insertion preview is computed against the committed `Route path`, not only against the straight line between currently visible markers. Inserting into a routed segment can therefore split committed routed geometry between visible points.
- Clicking an active `Hover point` inserts a new visible draft `Route point` at that preview location instead of appending a new endpoint at the end of the draft.
- In routed drafts, inserting a `Hover point` can add hidden projected-anchor plain `Route point`s before or after the inserted visible point so the committed routed geometry keeps its existing shape outside the rebuilt adjacent segments.
- Deleting a draft `Route point` removes the selected control endpoint, rebuilds the draft from the remaining control endpoints, and keeps the draft session open.
- Deleting the final remaining draft `Route point` does not end the draft. The draft stays open, returns to `awaitingStart`, and clears all markers and committed geometry.
- Moving a draft `Route point` rebuilds the route from control endpoints rather than editing the committed `Route path` vertices in place.
- Moving a straight-line `Route point` rewrites the adjacent direct geometry immediately.
- Moving a routed middle `Route point` reroutes only the adjacent `Route segment`s that touch that control point.
- Moving an inserted routed `Route point` reroutes both adjacent segments around the inserted point while preserving the committed geometry outside those rebuilt segments.
- Moving or deleting a peak-derived `Route point` can invalidate the captured peak target. Current behavior then clears the peak target, locks out fallback peak inference, and forces `Route to Peak` back to `Snap to Trail` if needed.
- Moving the first marker of a closed loop reopens the route into ordinary editable geometry instead of moving both the start and duplicated terminal return-to-start point together.
- Undo restores add, insert, move, and delete changes from full draft-history snapshots, including the case where deleting the last point emptied the draft.

### Route Point Class Rebuild Rules

- Marker class is derived from the current visible control-endpoint list every time the draft rebuilds after add, insert, move, delete, undo, redo, `Out and Back`, `Close Loop`, or edit-mode rehydration.
- The first visible `Route point` always rebuilds as the start-circle marker.
- Any visible peak-derived point always rebuilds as a target marker.
- The final visible non-peak `Route point` always rebuilds as a target marker.
- Every other visible non-peak intermediate point rebuilds as a `Numbered route point` and is renumbered from `01` upward in current visible order.
- Inserting a visible intermediate point into an open chain such as start -> numbered -> target rebuilds that chain into start -> numbered -> numbered -> target, with the later numbered points renumbered.
- Rehydrating a saved route for edit hides non-waypoint geometry vertices again and rebuilds visible editable markers only from the saved start `Route point`, saved `Waypoint`s, and saved end `Route point`.

### Desktop Hover, Click, Drag, Undo, Redo, And Escape Behavior

- During route drafting on desktop, normal route hover is suppressed and hover is repurposed for draft-marker interaction and `Hover point` insertion preview.
- The current `Hover point` preview appears only when the pointer is within 12 logical pixels of a committed editable `Route segment` and outside the marker exclusion radius around existing visible draft markers.
- When a `Hover point` preview is active, the cursor changes to a click cursor.
- Pointer-down on a draft marker or on the `Hover point` preview arms a potential drag, but current code does not treat it as a drag until pointer movement exceeds 5 logical pixels.
- If pointer movement stays at or below that threshold on a draft marker, the interaction is treated as a click instead of a drag.
- Clicking a draft marker opens a popup titled `Edit Point` with a single destructive action labelled `Delete Point`.
- Dragging a marker after crossing the threshold updates the visible marker location live while the provider rebuilds the draft geometry underneath it.
- A full drag gesture creates one undo history step for the whole drag rather than one undo step per intermediate drag update.
- While drafting, `Cmd+Z` or `Ctrl+Z` triggers undo and `Cmd+Shift+Z` or `Ctrl+Shift+Z` triggers redo when the draft is not routing a segment, a save is not running, and the corresponding history action is available.
- The visible undo and redo affordances are compact icon buttons with the exact tooltips `Undo (⌘ Z)` and `Redo (⌘ ⇧ Z)`.
- If editable text currently has focus, undo and redo shortcuts are ignored. `Escape` still bypasses that text-focus guard.
- `Escape` does not cancel route drafting directly. It dismisses the highest-priority open surrounding surface first.
- Current dismiss priority is: end drawer, route-point delete popup, track/route chooser, map tap action popup, favourites popup, drive ETA popup, peak info popup, map info popup, map metadata filter popup, Search popup, then the selected track or route info panel.
- During drafting, `Escape` therefore closes the route-point delete popup if it is open, or closes other higher-priority surrounding surfaces such as the end drawer, while leaving the draft itself active.

### Current Route Mode And Transform Behavior

- `Straight Line`, `Route to Peak`, and `Snap to Trail` are visible text `FilledButton` mode controls.
- `Out and Back`, `Close Loop`, `Undo`, and `Redo` are visible compact icon buttons with tooltips and semantics labels rather than text labels inside the buttons.
- The selected route mode button is green, an available but unselected mode button is purple, and an unavailable mode button uses the inactive surface styling.

#### Straight Line

- `Straight Line` is selectable whenever the draft is not currently in `routingSegment`.
- In `Straight Line`, each new `Route point` extends the committed `Route path` immediately as direct geometry without waiting for the route planner.
- Rebuild paths for moved or deleted points also keep direct geometry for `Straight Line` drafts.

#### Snap To Trail

- `Snap to Trail` is the default mode for a new draft unless edit-mode hydration starts in `Route to Peak` from a saved peak-derived terminal `Waypoint`.
- `Snap to Trail` is selectable whenever the draft is not currently in `routingSegment`.
- Successful planner output uses the routed geometry and current endpoint anchors returned by the route planner.
- For ordinary `Snap to Trail` segment creation, current off-track and no-path results are treated as usable completion paths. The draft keeps going in `awaitingNextPoint` with fallback geometry instead of surfacing an inline route error.

#### Route To Peak

- `Route to Peak` is only available when the draft currently has a captured peak target, at least one already placed draft `Route point`, the draft is not a closed loop, and the draft is not currently routing a segment.
- The current captured peak target can come from the locked-in draft peak, the active peak info popup target, or a selected map location that sits on a peak marker.
- Current edit behavior can invalidate that captured peak target if the relevant peak-derived point is moved or deleted. When that happens, `Route to Peak` disables and the draft locks out implicit peak-target fallback.
- If the user switches to `Route to Peak` after already placing a start point, the next route calculation immediately uses the existing start point and the captured peak target.
- After a `Route to Peak` segment finishes, current behavior always drops the mode back to `Snap to Trail` and clears the captured peak target.
- On routed success, the committed `Route path` uses the routed geometry and ensures the peak point remains the terminal route point.
- On off-track fallback, current behavior preserves the partial routed geometry returned by the planner and appends the peak point as the final leg.
- On no-path or route-graph-load failure, current behavior falls back to a straight segment from the start point to the peak point without showing an inline route error.

#### Out And Back

- `Out and Back` is enabled only when the committed `Route path` has at least 2 points, the route is currently open, no save is running, the draft is not in `routingSegment`, and the draft is not in `segmentFailure`.
- Pressing `Out and Back` does not call the route planner. It appends the reverse of the committed `Route path` and adds a return control endpoint so the route doubles back over its existing geometry.

#### Close Loop

- `Close Loop` is enabled only when the committed `Route path` has at least 2 points, the route is not already closed, no save is running, the draft is not in `routingSegment`, and the draft is not in `segmentFailure`.
- On routed success, `Close Loop` plans a return leg from the current end point back to the start point.
- On no-path fallback, current `Close Loop` behavior falls back to reversing the committed `Route path` as an out-and-back-style return.
- On off-track fallback, current `Close Loop` behavior falls back to a direct straight closing segment from the current end point back to the start point.
- On planner failure without a usable fallback, `Close Loop` enters `segmentFailure` and leaves the inline error visible.
- The `Retry` button is only shown for route-graph-load failures. Other current failures do not show a retry affordance.

## Implementation Inconsistencies

- When the app saves unnamed intermediate draft `Route point`s, it persists them as generic saved `Waypoint`s labelled `Waypoint 1`, `Waypoint 2`, and so on. That conflicts with the glossary distinction where a `Numbered route point` is draft-only and a `Waypoint` is meant for a meaningful saved named stop.

## Proposed Rule Changes

Reserved for later work.
