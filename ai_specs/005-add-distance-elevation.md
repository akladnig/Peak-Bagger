<goal>
Populate the existing GPX track analytics fields from parsed GPX data so imported and rebuilt tracks have usable `distance` and `ascent` metadata.
This is for users who import or rebuild tracks and for admins who inspect track rows in ObjectBox Admin.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, latlong2, XML GPX parsing.
Context: `GpxTrack` already has `distance` and `ascent` fields, but the importer does not currently compute them from the GPX file.
The parser must use the raw GPX XML stored in `GpxTrack.gpxFile` as the source of truth for recalculation.
This spec intentionally stays on the existing schema and does not add the older draft fields like `descent`, `elevationProfile`, or min/max elevation analytics.

Files to examine:
- @lib/models/gpx_track.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_repository.dart
- @lib/services/objectbox_admin_repository.dart
- @lib/screens/objectbox_admin_screen.dart
- @lib/providers/map_provider.dart
- @lib/objectbox-model.json
- @lib/objectbox.g.dart
- @test/gpx_track_test.dart
- @test/services/objectbox_admin_repository_test.dart
- @test/widget/objectbox_admin_browser_test.dart
</background>

<discovery>
Before implementing, examine thoroughly:
- Where `GpxImporter.parseGpxFile()` already extracts track segments and metadata.
- Whether elevation is available on each `<trkpt>` as `<ele>` and how missing elevation should be represented.
- Whether `latlong2.Distance` should be reused for distance so the new logic matches existing map code.
- Whether any UI already displays `distance` and `ascent` so the spec can require only data population, not new presentation.
</discovery>

<user_flows>
Primary flow:
1. User imports tracks or triggers a reset rebuild.
2. The importer parses the stored GPX XML from `GpxTrack.gpxFile`, calculates distance and ascent, and persists those values on the `GpxTrack` row.
3. The user can inspect the imported row in ObjectBox Admin and see non-null distance/ascent values when the track contains enough data.
4. User opens Settings and taps `Recalculate Track Statistics` to refresh distance/ascent on existing rows from the stored GPX XML.

Alternative flows:
- Returning user with existing tracks: a later reset/rebuild repopulates stats for the on-disk source files without changing the track organization rules.
- Returning user with existing rows and stale analytics: `Recalculate Track Statistics` updates persisted rows in place without moving files or changing track organization.
- Tracks with partial elevation data: distance is still populated from geometry, while ascent is computed only from parseable elevation samples.

Error flows:
- Invalid GPX or missing track points: keep current skip behavior; do not invent stats for files that cannot be parsed.
- No parseable elevation data: store distance if geometry exists, leave ascent null rather than fabricating zero.
</user_flows>

<requirements>
**Functional:**
1. Compute `distance` for each parsed track from the track geometry in meters using the same geodesic distance math already used elsewhere in the app (`latlong2.Distance`).
2. Compute `ascent` for each parsed track in meters by summing positive elevation deltas between consecutive parseable track points, skipping over missing elevation samples instead of terminating the chain.
3. Persist calculated `distance` and `ascent` on every newly imported or rebuilt `GpxTrack` row.
4. Add a `Recalculate Track Statistics` action to Settings directly below `Reset Track Data`; it must recalculate `distance` and `ascent` for persisted rows using the stored `GpxTrack.gpxFile` XML.
5. `Reset Track Data` must also calculate the same statistics during the rebuild path so fresh rows and refreshed rows behave the same way.
6. Leave the existing GPX track schema unchanged; do not add `descent`, `elevationProfile`, or additional elevation analytics in this spec.

**Error Handling:**
7. If a GPX payload cannot be parsed or contains no usable track points, skip it exactly as current import behavior does and do not create partial analytics.
8. If a track has geometry but no parseable elevation samples, still persist `distance` and keep `ascent` null.
9. If a track has only one usable track point, persist `distance` as 0.0 and keep `ascent` null unless valid elevation transitions exist.
10. If `Recalculate Track Statistics` encounters rows with invalid stored GPX XML, report the failure through the existing track-operation error path and continue processing the remaining rows when possible.

**Edge Cases:**
11. Multi-segment tracks must sum distance and ascent across all segments while preserving segment boundaries; do not bridge artificial gaps between segments.
12. Mixed-elevation tracks should skip missing elevation samples and continue from the next parseable sample instead of failing the whole track.
13. Reset Track Data must recalculate the same metrics from the rebuilt source files so fresh rows and rebuilt rows stay aligned.
14. Recalculate Track Statistics must update existing persisted rows in place without changing file organization, track IDs, or the visible track list order.

**Validation:**
11. Add explicit numeric expectations for synthetic tracks in tests so calculations are verified with a small tolerance, not only via non-null assertions.
</requirements>

<boundaries>
Edge cases:
- Single-point track: distance is 0.0; ascent is null unless elevation transitions exist.
- Multi-segment GPX: calculate within each segment; do not connect the end of one segment to the start of the next.
- Partial elevation data: compute distance regardless; compute ascent only from parseable elevation pairs, skipping missing samples.

Error scenarios:
- Invalid GPX: keep current skip-and-log behavior.
- No track points: keep current skip-and-log behavior.
- Missing elevation on a valid track: keep the track import successful and leave ascent null.

Limits:
- This spec only covers the existing `distance` and `ascent` fields.
- Do not add dashboard charts or new stats fields until a separate spec requests them.
- Do not change route-vs-track classification, Tasmania rules, or file organization behavior.
- Recalculate Track Statistics is a local maintenance action; it does not read from the filesystem or reorganize files.
</boundaries>

<implementation>
Modify `./lib/services/gpx_importer.dart` to calculate distance and ascent during parse/import, preferably through a small pure helper so the math can be tested without the filesystem.
Reuse `latlong2.Distance` for distance calculations and parse `<ele>` values from GPX track points for ascent.
Add a Settings action under Reset Track Data that invokes a recalculation pass over persisted `GpxTrack` rows using each row's stored `gpxFile` XML.
Keep `./lib/models/gpx_track.dart` unchanged unless a minimal serialization fix is needed.
Verify `./lib/services/objectbox_admin_repository.dart` and `./lib/screens/objectbox_admin_screen.dart` still surface the persisted values without adding new UI requirements.
Avoid adding a second distance formula or a second GPX parsing path; the importer should remain the single source of truth for track analytics.
</implementation>

<stages>
Phase 1: Add a deterministic calculator for track distance and ascent from parsed segments and elevation samples; verify with unit tests first.
Phase 2: Wire the calculator into the importer/reset path so new and rebuilt `GpxTrack` rows persist the computed values; verify with importer tests.
Phase 3: Add the Settings recalculation action for existing rows; verify the recalculation path updates persisted rows in place.
Phase 4: Confirm admin browsing still shows the stored values and that the reset/import journey still completes without regression; verify with widget/robot coverage if the UI surface changes.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for distance calculation, ascent calculation, single-point tracks, missing elevation, and multi-segment summing.
- UI behavior: widget tests for the Settings recalculation action, reset flow, and ObjectBox Admin row inspection if the admin surface is expected to display the populated values.
- Critical user journeys: robot-driven coverage for import, reset, and recalculation flows that end with persisted rows containing calculated distance/ascent, if those paths are part of the visible journey.

TDD expectations:
- Write one failing test slice at a time: distance happy path, ascent happy path, missing-elevation edge case, parse failure handling, then persistence wiring.
- Keep the calculator pure and injectable so tests do not depend on the filesystem or ObjectBox.
- Prefer fakes for repositories and file seams; do not mock private parser internals.

Recommended test split:
- Unit tests: calculation math and parser-level edge cases.
- Widget tests: Settings recalculation action, admin screen displays populated values, and null/empty analytics handling.
- Robot tests: import/reset/recalculate journey coverage if those actions are exposed in the visible flow; otherwise keep journey coverage minimal and report the residual risk.
</validation>

<done_when>
Imported or rebuilt GPX tracks persist correct `distance` and `ascent` values.
The importer keeps current skip/log behavior for invalid files and missing track points.
The spec is specific enough that `/plan` can break it into implementation tasks without guessing the math, scope, or validation strategy.
</done_when>
