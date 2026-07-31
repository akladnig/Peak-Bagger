# Route Rules

## Current Behavior Baseline

This artifact records the current interactive map `Route` drafting and editing behavior exactly as implemented today. The baseline below is reconciled against the current provider, widget, and robot seams in `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_route_draft_hover_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_hover_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_keyboard_test.dart`, `test/robot/map/map_route_journey_test.dart`, and `test/robot/map/route_info_journey_test.dart`. Where older notes disagree, current code and those deterministic tests win.

### Entry And Edit Handoff

- `Create Route` starts from the map action rail `Create Route` action.
- Starting `Create Route` closes or dismisses the end drawer, peak info popup when a peak target is active, drive ETA popup, map info popup, Search popup, goto input, map tap action popup, favourites popup, and the track/route chooser.
- Starting `Create Route` clears the selected `Track` and selected `Route`, keeps the current selected location unchanged, focuses the map, and shows the left route graph overlay plus the right route controls overlay.
- `Edit Route` starts from the selected-`Route` shared info panel `Edit Route` button.
- Starting `Edit Route` immediately clears the selected `Route`, hides the shared info panel, and stores the saved `Route` id as `sourceRouteId` for later restore-on-cancel or restore-on-save behavior.
- `Edit Route` rehydrates the draft from the saved `Route`: route name, colour, committed `Route path`, saved point elevations, saved distance and elevation summary, and the editable saved `Route point` set.
- During `Edit Route`, visible editable `Route point`s are rebuilt from the saved start `Route point`, saved `Waypoint`s sorted by `sequence`, and the saved end `Route point` when the final saved `Waypoint` is not already at that same final coordinate. The full saved `Route path` still remains the committed geometry even when not every geometry vertex becomes a visible editable `Route point`.
- Any saved, imported, or externally created `Route` with no persisted `Waypoint`s reopens with only start and end visible editable `Route point`s even if its saved `Route path` contains many interior geometry vertices.
- Any saved `Route` with at least one peak-derived `Waypoint` seeds `routeDraftPeak` and edit mode starts in `Route to Peak`, even if that peak-derived `Waypoint` is not the final visible editable point. Otherwise edit mode starts in `Snap to Trail`.

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

### Saved Route Persistence, Import, And Rehydration Contract

- Interactive route save writes a fresh `Route` object from the current draft state. It does not merge unchanged fields from the previous saved `Route`.
- Current interactive save persists these fields from the draft or current save helpers: `id` (`sourceRouteId` when editing, otherwise a new id), trimmed `name`, `gpxRoute` from current committed points, `gpxRouteElevations` from fresh save-time point sampling, `routeWaypoints` from current visible draft control endpoints, `displayRoutePointsByZoom` rebuilt from the current committed polyline, `colour`, `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, `highestElevation`, `estimatedTime`, `routeTimingSource`, `routeTimingProfileJson`, and `routeTimingSegmentKindsJson`.
- Current interactive save does not preserve `desc` from the source `Route`. It falls back to the `Route` constructor default empty string.
- Current interactive save does not preserve `walkingSpeedKmh` from the source `Route`, even when timing profile preservation or extension succeeds.
- Current interactive edit save also resets `visible` to the `Route` constructor default `true`, so saving edits to a hidden route makes that route saved as visible again.
- Save-time `routeWaypoints` are rebuilt only from visible draft control endpoints after the first visible point. Hidden projected-anchor points are skipped, and a duplicated final return-to-start endpoint is skipped for closed loops.
- Save-time peak-derived `Waypoint`s persist the current peak target label plus `peakOsmId` and `peakName`.
- Save-time non-peak visible control endpoints persist as generic `Waypoint 1`, `Waypoint 2`, and so on, with 1-based `sequence` ordering assigned from the current visible save order.
- Draft-only state is not persisted. That includes current draft stage and mode, provisional geometry, hover preview state, visible marker numbering, undo and redo history, save and routing flags, validation and error state, selected and source route ids, and peak-target lock state.
- GPX route import enriches routes before their first save into app storage: `distance2d` is recomputed from geometry, sampled point elevations override file elevations where available, 3D summary tries DEM sampling first and falls back to file-elevation-derived summary second, and timing is preserved from imported timestamps when present or otherwise recalculated from geometry using `Naismith`.
- Once an imported or externally created route already exists in app storage, later `Edit Route` uses the same rehydration rules as any other saved route: `gpxRoute` remains the committed geometry, only saved `RouteWaypoint`s plus start and end become visible editable control points again, and any later interactive save rebuilds route waypoints and timing metadata from the current draft instead of preserving every original saved field unchanged.

### Derived Metadata, Elevation, And Timing Contract

- Any committed-geometry change with at least 2 committed points starts a new elevation request, clears the previous elevation summary, increments `routeDraftElevationRequestId` and `routeDraftGeometryVersion`, sets `routeDraftElevationLoading = true`, clears any previous elevation error, and clears the current draft point-elevation list.
- Draft elevation recomputation samples per-point elevations first and updates `routeDraftPointElevations` when that request is still current, then requests the full `RouteElevationSummary`.
- Stale point-elevation or summary results whose `requestId` or `geometryVersion` no longer match the active draft are ignored.
- If summary sampling succeeds, the draft stores that `RouteElevationSummary` and clears the loading and error state.
- If summary sampling throws `RouteElevationSamplingException`, the draft clears the elevation summary and shows the exact exception message.
- If summary sampling throws `GdalException`, the draft logs the failure and shows `Tasmania elevation data is unavailable on this device`.
- If summary sampling throws any other error, the draft clears the elevation summary and shows `Failed to sample elevation: <error>`.
- When committed geometry drops below 2 points, the draft clears elevation summary, point elevations, and elevation error instead of retaining stale derived metadata.
- Save-time 3D distance and elevation-summary fields are taken from the current draft summary only when that summary is non-null, not still loading, and exactly matches the active `routeDraftElevationRequestId` and `routeDraftGeometryVersion`. Otherwise the saved route falls back to zeros for `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, and `highestElevation`.
- Save-time per-point elevations are always sampled again from the current committed geometry and rounded to ints. If that save-time sampling throws, every saved point elevation becomes `null`.
- Edit-mode rehydration seeds draft `distance2d`, saved point elevations, and saved 3D elevation summary from the saved route snapshot immediately, then later committed-geometry changes replace that snapshot through the live resampling path.
- When editing a saved route, timing preservation only runs if the source route still has both `estimatedTime` and `routeTimingProfileJson`. Otherwise save recalculates timing from the current geometry using `Naismith`.
- Current edit-save segment provenance resolution uses stored `routeTimingSegmentKindsJson` when it matches the source segment count. When it does not, current code synthesizes all-manual segment kinds for `naismith`, all-preserved segment kinds for `verified-walk`, and all-preserved segment kinds when the source timing source is `null`. Other mismatches fall back to a full geometry-based timing recalculation.
- When source timing data is present, current edit save first tries to extend the stored timing profile and stored segment-provenance data across the edited geometry. If the combined profile length stays unchanged, the saved route keeps the previous timing source. If the geometry grows and extension succeeds, the saved route switches to `extended-route`. If profile extension or segment-kind reconciliation fails, current save falls back to a full geometry-based `Naismith` recalculation.

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

- `Snap to Trail` is the default mode for a new draft unless edit-mode hydration starts in `Route to Peak` because the saved route has at least one peak-derived `Waypoint`.
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
- `ai_specs/routes/route_bottom-sheet-spec.md` still describes route save as placeholder-only with temporary discarded markers and no persistence backend. Current implementation persists routes, elevations, timing metadata, display cache data, and saved route-waypoint metadata.
- `ai_specs/routes/route-edit-spec.md` says edit rehydration should seed all saved geometry points as editable control endpoints and preserve non-editable saved route metadata unless the user changes it. Current implementation rehydrates only start plus saved `Waypoint`s plus end as visible editable control points, and interactive save rebuild resets at least `desc`, `visible`, and `walkingSpeedKmh` instead of preserving them.
- `ai_specs/routes/route-out-and-back-spec.md` and `ai_specs/routes/route-loop-spec.md` still describe generic turnaround or loop waypoint persistence that no longer matches the intended contract. The follow-up route-rules refinement resolves that disagreement in favor of plain saved route geometry unless the user explicitly creates a named `Waypoint` or a point remains peak-derived.

## Proposed Rule Changes

- Add Save As functionality which requires duplicate name checking
- Lines 70 & 71: The `desc` and `walkingSpeedKmh` from the source `Route` are to be preserved
- Line 75 - During save generic waypoints are not to persist
- Line 78 - All waypoints are to become editable - but do not need specific markers nor do they need to become visible editable control points. However, it should be possible to select any point and apply any of the current actions such as delete, move etc.
- Line 82 - Elevation requests should only be made if dem is available for the region in question
- On Route Save - Lat/Long is to be saved to 6 decimal places only
- Line 102 - Add an icon for a named waypoint Icons.location-pin. Clicking on a point brings up the popup menu, with a new option "Create Waypoint" to sit above "Delete".
- Line 107 - Do not save generic waypoints
- Line 119 - Duplicate handling to be changed to be a no-op
- Line 120 - Instead of an error, change the display marker so that it is number mod 100, and internally the numbers keep incrementing.
- Line 125 - manually rechecked against current implementation and regression coverage; deleting the final remaining draft point does clear all visible markers and committed geometry while leaving the draft session open in `awaitingStart`.
- Line 146 - During route drafting the Hover marker should move along the elevation profile as per the current behaviour in the track/route info popup.
- Line 151 - As per Line 102 comments above.
- Line 154 - Remove Ctrl+Z and Ctrl+Shift+Z shortcuts - they are Windows specific and this is macOS only.
- Line 201 - Change it so that it first attempts to find the closest track and route along the track back to the start and falls back to a direct straight line closing segment.
- Line 207 - Generic waypoints are for route draft and should be saved as a plain route point. This change of behaviour will need to be implemented.
- Line 208 - Update the spec to reflect the current state
- Line 209 - The route-edit-spec is correct, the implementation to be updated to this.
- Line 210 - resolved in favour of the follow-up contract: `Out and Back` and `Close Loop` remain geometry transforms and must not implicitly create semantic saved waypoints.

## New Functionality
- When clicking and dragging any route point that is currently on a trail, to a new trail, the autorouting should re-route via the new route point. 
