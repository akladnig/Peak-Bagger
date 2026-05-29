# Trip Routing On-Track Detection

## Behavior Model

- Each tap gets classified against the nearest graph edge.
- If the tapped endpoint is farther than `maxSnapDistanceMeters`, that tap is `offTrack`.
- While the draft is in off-track mode:
- new segments are drawn straight
- each new tap is still reclassified
- when a tap is back within threshold, that segment is still straight
- after adding that segment, the draft exits off-track mode
- the next segment uses snap-to-trail again

## What Needs To Change

1. In `trip_routing`, add edge-distance classification
- Add nearest-edge search over the graph.
- Add point-to-segment distance in meters.
- Create Route.maxSnapDistanceMeters in constants.dart and set to 50.

2. In `trip_routing`, stop using `errors` for off-track
- Extend `Trip` with a status field, for example:
- `onTrack`
- `offTrack`
- `noPath`
- `graphUnavailable`
- Optionally add waypoint-level info:
- `offTrackWaypointIndexes`

3. In `peak_bagger`, change planner result shape
- Replace exception-driven off-track handling with a structured result.
- Example planner result statuses:
- `routed`
- `offTrack`
- `failed`

4. In `MapNotifier`, split two concepts that are currently conflated
- Current `routeDraftStraightLineFallback` means "stay straight forever after one failure".
- Replace with state that means:
- currently off-track / awaiting rejoin
- While in that state:
- add straight segments
- probe each new tap for rejoin eligibility
- clear the state once a tap is back within threshold

5. Keep real failures separate
- `noPath` or graph-load issues can still use the current failure/fallback path
- `offTrack` should not populate `routeDraftError`

## Tests To Add

1. `trip_routing`
- near edge, far from nodes -> `onTrack`
- beyond threshold -> `offTrack`
- null threshold -> legacy behavior
- rejoin tap classified `ok`

2. `peak_bagger` provider tests
- off-track tap enters straight-line mode without error
- later off-track taps remain straight
- rejoin tap adds a straight segment and clears off-track mode
- next tap after rejoin routes normally

3. Widget/robot tests
- update the current "falls back to straight off-track segment" journey
- add one journey covering: snapped -> off-track straight -> rejoin straight -> snapped again

## Remaining Decision

- `noPath` be treated like a real routing failure.

## Recommendation

- `offTrack`: normal state, no error
- `noPath`: also normal straight-line fallback, no user-visible error
- only infrastructure/data issues remain errors
