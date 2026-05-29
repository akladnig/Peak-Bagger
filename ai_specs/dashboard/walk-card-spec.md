<goal>
Create the Latest Walk dashboard card so users can see their most recent walk at a glance, including the walk name, key metrics, and a static mini-map preview.
This benefits dashboard users who want a quick summary without opening the map screen.
</goal>

<background>
Flutter app using Riverpod, ObjectBox, and `flutter_map`.
The dashboard already has a registered `latest-walk` card slot and a 4:3 dashboard tile contract.
Files to examine:
@lib/screens/dashboard_screen.dart
@lib/providers/dashboard_layout_provider.dart
@lib/providers/map_provider.dart
@lib/models/gpx_track.dart
@lib/services/track_display_cache_builder.dart
@lib/screens/map_screen_panels.dart
@lib/screens/peak_lists_screen.dart
@test/widget/dashboard_screen_test.dart
@test/providers/dashboard_layout_provider_test.dart
@test/robot/dashboard/dashboard_journey_test.dart
</background>

<user_flows>
Primary flow:
1. The user opens the dashboard.
2. The Latest Walk card shows the newest track by most recent `startDateTime`; if that track has no usable geometry, the card shows the empty placeholder instead of falling back to an older track.
3. The card renders the track name in bold, then date, distance, and ascent on one row, then a static mini-map preview.

Alternative flows:
- Returning user with stored dashboard order: the Latest Walk card still renders in its configured position.
- After importing a newer GPX track: the card updates to the new track without requiring a restart.
- The newest track has unusable geometry: the card shows an empty placeholder instead of falling back to an older track.

Error flows:
- No tracks have `startDateTime`: show the empty placeholder.
- The newest track has no usable geometry: show the empty placeholder.
- Tile loading fails: keep the card shell and text stable; do not crash the dashboard.

Preview framing:
- For 2+ geometry points, build a `CameraFit.bounds` preview from all points with padding.
- For exactly 1 geometry point, center the mini-map on that point with `MapConstants.defaultMapZoom`.
- For 0 geometry points or unreadable geometry, show the empty placeholder.
</user_flows>

<requirements>
**Functional:**
1. Render the Latest Walk card body inside the existing dashboard tile titled `Latest Walk`.
2. Select the newest `GpxTrack` by descending `startDateTime`; ignore tracks with null `startDateTime` and do not fall back to an older track when the newest track is broken.
3. If multiple tracks share the same `startDateTime`, use the highest `gpxTrackId` as the tie-breaker.
4. Render the track name as bold text at the top of the card body.
5. Render date, distance, and ascent on a single row beneath the track name.
6. Render a static mini-map preview at the bottom of the card body using the newest track geometry.
7. Frame the preview by fitting bounds with padding for 2+ points, centering on the point for a single-point track, and showing the empty placeholder when no geometry can be framed.

**Error Handling:**
8. Show a simple empty placeholder when no tracks exist, no track has `startDateTime`, or the newest track has no usable geometry.
9. Keep the card stable if the mini-map tiles cannot load.

**Edge Cases:**
10. Long track names and compact dashboard widths must not overflow the card.
11. The metadata row must stay single-line; if space is tight, truncate or compact the text rather than wrapping into multiple rows.

**Validation:**
12. Use the existing track date formatter output format, matching `Wed, 7 January 2026`-style text.
13. Use `distance2d` for the distance metric and the app’s existing ascent formatting, including sensible fallback text for missing ascent.
</requirements>

<boundaries>
Edge cases:
- Empty track list: show the empty placeholder.
- All tracks missing `startDateTime`: show the empty placeholder.
- Valid track with missing or corrupt cached geometry: show the empty placeholder.
- Duplicate timestamps: resolve deterministically with `gpxTrackId`.

Error scenarios:
- Network or tile failures should not block the rest of the card.
- Geometry decode failures should not crash the dashboard.

Limits:
- The mini-map is a preview only; do not add pan, zoom, or tap interaction.
- Keep the implementation within the existing 4:3 dashboard grid contract.
</boundaries>

<implementation>
Create `./lib/services/latest_walk_summary.dart` with a pure selector/formatter helper for the card.
Create `./lib/widgets/dashboard/latest_walk_card.dart` for the populated and empty card UI.
Update `./lib/screens/dashboard_screen.dart` to render the Latest Walk widget in the `latest-walk` slot.
Watch `mapProvider.tracks` as the source of truth so the card updates automatically after imports and other track refreshes.
Reuse existing track geometry caches and existing distance/elevation helpers where possible.
Avoid adding a new repository API unless the card cannot determine the latest track from the loaded track list.
</implementation>

<validation>
Add unit coverage in `./test/services/latest_walk_summary_test.dart` for newest-track selection, null filtering, tie-breaking, and empty inputs.
Add widget coverage in `./test/widget/latest_walk_card_test.dart` for populated rendering, empty placeholder rendering, single-row metadata, and mini-map layout stability.
Extend `./test/robot/dashboard/dashboard_journey_test.dart` or add a sibling robot test to confirm the dashboard opens and the Latest Walk card is present with stable keys.
Use stable selectors such as `dashboard-card-latest-walk`, `latest-walk-card`, `latest-walk-mini-map`, and `latest-walk-empty-state`.
Follow vertical-slice TDD: write one failing test, implement the minimal behavior, then refactor after green.
Keep tests deterministic by overriding `mapProvider` with a fake notifier or equivalent seam instead of live storage or network.
Baseline automated coverage must include logic/unit behavior, widget behavior, and one dashboard journey check.
</validation>

<stages>
1. Implement the pure latest-walk selection helper and prove it with unit tests.
2. Build the dashboard card widget with empty and populated states, then prove it with widget tests.
3. Wire the widget into the dashboard screen and add the dashboard journey assertion.
4. Verify the final card still fits the existing 4:3 dashboard grid without overflow.
</stages>

<done_when>
The dashboard shows the newest walk by `startDateTime`.
The card falls back to an empty placeholder when no track exists, no track has `startDateTime`, or the newest track has unusable geometry.
The mini-map renders as a static 4:3 preview and the existing dashboard layout tests still pass.
New unit, widget, and journey coverage all pass.
</done_when>
