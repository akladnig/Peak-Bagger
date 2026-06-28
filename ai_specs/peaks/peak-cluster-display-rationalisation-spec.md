<goal>
Rationalize peak rendering so the app uses one shared custom-painted peak display path across the main map and peak-list mini-map, plus a shared peak marker helper for latest-walk and popup-adjacent peak UI, while adding separate persisted Settings toggles for map-screen clusters and peak-list mini-map clusters.

This matters because the current codebase renders peaks through two different methods: the main map uses `./lib/screens/map_screen_peak_layer.dart`, while mini-map and popup-adjacent surfaces still use SVG marker assets via `buildPeakMarkers()` or inline `SvgPicture.asset(...)`. The outcome should make peak presentation visually consistent, easier to maintain, and reusable on more than one map surface, while still letting users tune cluster display independently for the main map and peak-list mini-maps.
</goal>

<background>
Tech stack: Flutter, Riverpod, `SharedPreferences`, `flutter_map`, and existing widget/robot tests.

Current state:
- `./lib/screens/map_screen_peak_layer.dart` contains the custom-painted main-map peak layer.
- `./lib/screens/map_screen_layers.dart` still exposes `buildPeakMarkers()` for SVG-based peak markers.
- `./lib/screens/peak_lists_screen.dart` still renders peaks from SVG marker assets.
- `./lib/widgets/dashboard/latest_walk_card.dart` still renders latest-walk peak markers from SVG marker assets.
- `./lib/screens/map_screen_panels.dart` still uses the SVG peak asset inline for `Move Peak to Marker`.
- `./lib/providers/peak_marker_info_settings_provider.dart` and `./lib/providers/show_polygons_settings_provider.dart` show the existing persisted-boolean settings pattern.

Files to examine:
- `./pubspec.yaml`
- `./lib/screens/settings_screen.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_peak_layer.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/providers/peak_marker_info_settings_provider.dart`
- `./lib/providers/show_polygons_settings_provider.dart`
- `./lib/providers/peak_correlation_settings_provider.dart`
- `./lib/core/constants.dart`
- `./lib/theme.dart`
- `./test/widget/*`
- `./test/robot/*`

Output paths:
- Create `./lib/providers/peak_map_cluster_display_settings_provider.dart` and `./lib/providers/peak_list_mini_map_cluster_display_settings_provider.dart` for the new persisted toggles.
- Update `./lib/screens/settings_screen.dart` for the Settings switches.
- Update `./lib/screens/map_screen_peak_layer.dart` to remain the shared custom-painted peak display layer.
- Update `./lib/screens/map_screen.dart` to read the map-screen toggle and feed the shared layer.
- Update `./lib/screens/peak_lists_screen.dart` to use the shared custom-painted layer instead of SVG peak markers.
- Update `./lib/widgets/dashboard/latest_walk_card.dart` to use the shared peak marker helper for latest-walk peaks.
- Update `./lib/screens/map_screen_panels.dart` to replace the inline SVG peak icon in `Move Peak to Marker` with the shared peak marker helper.
- Update `./pubspec.yaml` to remove `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg` from the registered Flutter assets.
- Update or delete `./lib/screens/map_screen_layers.dart` peak-marker helpers if they become dead after the migration.
</background>

<user_flows>
Primary flow:
1. User opens Settings.
2. User sees separate `Show Map Peak Clusters` and `Show Peak List Mini-Map Clusters` switches alongside the existing peak display settings.
3. User turns either cluster setting on or off.
4. The next render of the main map or peak-list mini-map uses the shared custom-painted peak path and reflects the chosen cluster mode for that surface family.
5. Both settings persist across app restarts.

Alternative flows:
- Returning user: the stored cluster preferences restore on app start and immediately affect the relevant peak surfaces.
- Main map flow: `Show Map Peak Clusters` controls clustering in the main map and any map-screen-owned peak affordances.
- Peak-list mini-map flow: `Show Peak List Mini-Map Clusters` controls clustering in the peak-list mini-map only.
- Peak-list mini-map interaction flow: hovering an individual peak shows the same hover affordance as the main map without changing selection; tapping an individual peak selects it and opens the mini-map popup; hovering a cluster does nothing beyond the existing cursor/visual presence and does not select a peak; tapping a cluster clears hover, closes any open peak popup, expands the mini-map camera to that cluster, and does not change the currently selected peak.
- Latest-walk flow: the latest-walk card always shows individual peak markers for each peak, never clusters them, and still respects `Show Peak Info`.
- Move Peak to Marker flow: the popup control continues to show a peak glyph, but it uses the shared peak marker helper rather than the SVG asset.

Error flows:
- Preferences unavailable: keep the UI usable and fall back to the default cluster-on state.
- Missing or invalid peak coordinates: skip the affected peak only and keep the rest of the layer usable.
- Empty peak data or impossible viewport size: render an empty layer without error.
</user_flows>

<discovery>
Before implementation, confirm:
- Whether `./lib/screens/map_screen_peak_layer.dart` can remain the shared layer name or should be renamed to a more neutral peak-display name.
- Whether the peak-list mini-map should reuse the existing peak projection/clustering services directly or via a small shared wrapper.
- Whether the peak-list mini-map should simply switch between clustered and unclustered custom-paint rendering, rather than reintroducing SVG markers in the off state.
- Whether any non-runtime reason remains to keep `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg` in the repo after they are removed from `./pubspec.yaml`.
</discovery>

<requirements>
**Functional:**
1. Add two persisted boolean settings for peak clustering, using the existing Riverpod + `SharedPreferences` pattern used by the other app settings.
2. Default both new settings to `true` so the app preserves its current cluster-enabled peak presentation on first launch.
3. Add Settings screen switches labeled `Show Map Peak Clusters` and `Show Peak List Mini-Map Clusters`, each with a concise subtitle explaining that it enables or disables clustered peak display for that surface family.
4. Use the map-screen setting to control whether the main map renders clustered peak groups or only individual peak glyphs.
5. Use the peak-list mini-map setting to control whether the peak-list mini-map renders clustered peak groups or only individual peak glyphs.
6. Reuse the shared custom-painted peak viewport layer on the main map and peak-list mini-map.
7. Reuse a shared peak marker helper for latest-walk peaks and popup-adjacent peak UI.
8. Keep the latest-walk card on the shared individual-peak path with no clustering branch.
9. Remove the SVG-based runtime path from migrated peak-rendering surfaces; no migrated peak-rendering surface should call `SvgPicture.asset('assets/peak_marker.svg')` or `SvgPicture.asset('assets/peak_marker_ticked.svg')` after the refactor.
10. Remove `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg` from `./pubspec.yaml` while allowing the raw files to remain in the repo only if they are intentionally retained as non-runtime reference assets.
11. Replace the inline SVG usage in `Move Peak to Marker` with the shared peak marker helper so the popup UI matches the same visual language as the map layers.
12. Preserve existing peak hover, popup, hit testing, and label behavior on the main map and peak-list mini-map using these explicit rules: individual peak hover does not change selection, individual peak tap selects and opens the popup, cluster hover does nothing beyond the existing cursor/visual presence and does not select a peak, and cluster tap expands the camera, clears hover, closes the popup, and preserves the current selected peak.
13. Preserve the existing peak-info setting behavior; this work is about cluster display and shared rendering, not changing the meaning of `Show Peak Info`.
14. Keep `Show Peak Info` behavior on the latest-walk card for its individual peak markers.

**Error Handling:**
15. If preference loading or saving fails, continue with the in-memory/default value and do not block rendering.
16. If a peak cannot be projected or rendered, skip only that peak and keep the rest of the layer intact.

**Edge Cases:**
17. First launch must use cluster-enabled rendering for the main map and peak-list mini-map.
18. The latest-walk card must always render individual peak markers and never cluster them.
19. Tapping a cluster on the peak-list mini-map must expand the mini-map camera, clear hover, close any open peak popup, and leave the current selected peak unchanged.
20. Very small peak-list mini-map surfaces must not overflow; they should degrade gracefully to the available peak glyph/label layout.
21. Empty peak collections must return a valid empty layer with no spurious marker widgets.

**Validation:**
22. Verify the new toggles are persisted and restored through the same deterministic settings pattern used elsewhere in the app.
23. Verify the shared custom-painted viewport layer is the only live peak-rendering path for map surfaces after migration, and the shared peak marker helper is the only live non-map peak UI path after migration.
</requirements>

<boundaries>
Edge cases:
- The map-screen and peak-list mini-map toggles are global within their respective surface families, not per-peak-list.
- Peak-list mini-map interactions should follow the explicit contract in this spec: individual peak hover does not change selection, individual peak tap selects and opens the popup, cluster hover does nothing beyond the existing cursor/visual presence and does not select a peak, and cluster tap expands the camera, clears hover, closes the popup, and preserves the current selected peak.
- The latest-walk card is fixed to individual peak markers and has no cluster toggle.
- The `Move Peak to Marker` control is decorative UI, not a map overlay; it should still use the shared peak marker helper even though it is not clustered.
- Mini-maps should keep the same peak-label policy they already have today unless the shared layer forces a safer constraint.

Error scenarios:
- A failed preference read/write must not surface a blocking error state.
- A failed peak projection or empty viewport must not crash the map or mini-map.

Limits:
- No new dependencies.
- No database migration.
- No changes to peak ingestion, correlation, or clustering algorithm internals unless required to parameterize the new settings.
- The SVG peak assets may remain in the repo, but they must not remain registered in `./pubspec.yaml` after the runtime migration is complete.
</boundaries>

<implementation>
Create or update these files:
- `./lib/providers/peak_map_cluster_display_settings_provider.dart`
- `./lib/providers/peak_list_mini_map_cluster_display_settings_provider.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/screens/map_screen_peak_layer.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/screens/map_screen_panels.dart`
- `./pubspec.yaml`
- `./lib/screens/map_screen_layers.dart` if any SVG peak-marker helpers remain to be removed or retired
- `./lib/widgets/peak_marker_glyph.dart` if a small shared peak marker helper is needed for `Move Peak to Marker` and latest-walk markers

Implementation approach:
- Follow the existing settings-provider shape used by `showPolygonsSettingsProvider` and `peakMarkerInfoSettingsProvider`: synchronous boolean state with background hydration and silent persistence failure handling.
- Keep the custom-painted peak viewport layer as the shared renderer for map surfaces and feed it from existing viewport/projection services instead of duplicating peak rendering per screen.
- Keep the shared peak marker helper separate for latest-walk and popup-adjacent UI.
- Use the new settings to switch cluster aggregation on and off for the relevant surface family, not to reintroduce SVG peak markers.
- Keep the latest-walk card on the shared individual-peak path with no clustering branch.
- Keep the shared peak marker helper visually aligned with the map-layer peak glyph by extracting the smallest shared helper needed.
- Prefer one peak rendering approach after migration; do not leave a second SVG-based path in active use.

What to avoid:
- Avoid introducing a second peak renderer just for mini-maps.
- Avoid coupling widget rendering directly to `SharedPreferences`.
- Avoid changing peak selection or popup behavior as part of this refactor.
- Avoid leaving `buildPeakMarkers()` and the SVG asset path half-alive on some surfaces and removed on others.
</implementation>

<stages>
Phase 1: Add the settings.
- Introduce the persisted boolean providers and wire the Settings switches.
- Verify default-on behavior and persistence for both surface families.

Phase 2: Share the renderer.
- Reuse the custom-painted peak viewport layer on the main map and peak-list mini-map.
- Verify cluster-on and cluster-off rendering modes for both settings.
- Verify the latest-walk card renders individual peak markers, never clusters, and still honors `Show Peak Info`.
- Verify the peak-list mini-map interaction model follows the explicit contract for peak and cluster hover/tap behavior.

Phase 3: Remove the SVG peak path.
- Replace the `Move Peak to Marker` icon helper and delete direct runtime SVG peak-marker usage from peak surfaces.
- Verify no runtime peak-rendering code still references `assets/peak_marker.svg` or `assets/peak_marker_ticked.svg`, and remove both assets from `./pubspec.yaml`.

Phase 4: Regression pass.
- Run focused widget/robot tests for settings, map, and mini-map journeys.
- Run analyze/tests and confirm the shared custom-painted viewport layer is the only live peak renderer for map surfaces and the shared peak marker helper is the only live peak renderer for non-map peak UI.
</stages>

<illustrations>
Desired:
- Separate Settings toggles control peak-cluster display for the main map and peak-list mini-map.
- The main map and peak-list mini-map use the same custom-painted peak visuals, so they feel consistent.
- The latest-walk card uses the same shared peak marker visuals, but always as individual peaks.
- `Move Peak to Marker` uses the same visual language as the map rather than an inline SVG asset.

Avoid:
- One surface using custom paint while another still paints the same peaks from SVG.
- Hiding the cluster toggles behind a single global switch.
- Leaving `assets/peak_marker.svg` or `assets/peak_marker_ticked.svg` registered in `./pubspec.yaml` after the runtime migration is complete.
</illustrations>

<validation>
Use vertical-slice TDD:
- Write one failing test per behavior slice.
- Keep each implementation step minimal.
- Refactor only after the current slice is green.

Baseline automated coverage outcomes:
- Logic/state: provider default, hydrate, toggle, and persistence-failure fallback for both settings.
- UI/widget: Settings switches render and toggle; shared viewport layer renders clustered and unclustered states; latest-walk card renders individual peak markers with `Show Peak Info` support; shared peak marker helper renders without the SVG path.
- Critical journeys: toggling the main-map setting changes the main map presentation; widget coverage proves the peak-list mini-map setting changes the mini-map on the next rebuild/navigation cycle; robot coverage proves cluster taps on the peak-list mini-map expand the camera, clear hover, close any open popup, and preserve the selected peak.

Required test split:
1. Provider tests for default-on behavior, persisted values, and failed preference access fallback for both settings.
2. Widget tests for the Settings screen switches and for `MapScreenPeakLayer` in both cluster-enabled and cluster-disabled modes.
3. Widget tests for the peak-list mini-map and latest-walk card proving the peak-list mini-map respects the mini-map toggle, follows the explicit interaction contract for peak and cluster taps, and the latest-walk card remains individual-peaks only with `Show Peak Info` support.
4. Robot/journey test for opening Settings, toggling the main-map switch, returning to the map, and seeing the corresponding cluster mode change.
5. Robot/journey test for peak-list mini-map cluster/selection interaction, including cluster expansion preserving the selected peak.
6. Regression test for `Move Peak to Marker` proving it no longer depends on the inline SVG marker asset.
7. Static or test-assisted verification that `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg` are no longer referenced by migrated runtime peak-rendering code and are no longer registered in `./pubspec.yaml`.

Stable selectors and seams:
- Keep stable keys on the new switches, the peak-list mini-map viewport layer, cluster affordances, individual painted peak affordances, popup shell/anchor, and latest-walk peak marker helper instances needed by widget/robot tests.
- Preserve or replace the current deterministic marker selectors with explicit equivalents for painted peak affordances so tests do not depend on vanished `Marker` widgets.
- Keep viewport projection and cluster derivation in service/helpers with deterministic inputs.
- Prefer fakes or in-memory `SharedPreferences` for provider tests.
- If a shared peak marker helper is introduced, make it a small public widget so it can be tested without private painter introspection.
</validation>

<done_when>
The Settings screen has persisted peak-cluster toggles for the main map and peak-list mini-map, the map surfaces use the shared custom-painted viewport layer, and the non-map peak UI uses the shared peak marker helper instead of mixed SVG/widget rendering.
The main map, peak-list mini-map, latest-walk card, and `Move Peak to Marker` UI are visually consistent.
The SVG peak assets are no longer referenced by runtime peak-rendering code and are no longer registered in `./pubspec.yaml`.
Automated tests cover the settings, renderer, and end-to-end journeys.
</done_when>
