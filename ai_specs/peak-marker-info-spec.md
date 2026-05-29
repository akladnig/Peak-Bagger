<goal>
Add a persisted `Show Peak Info` setting that controls whether peak markers show the peak name and height.
When enabled, every peak-marker surface in the app should render a compact centered label stack using a reusable outlined-text painter/helper from `lib/theme.dart`.
The labels only appear when the effective zoom is at or above the shared peak-info zoom threshold.
This matters because users need a quick way to read peak details directly from the map without opening the popup, and the behavior must stay consistent across the main map and mini-map surfaces.
</goal>

<background>
This is a Flutter app using Riverpod, `SharedPreferences`, and `flutter_map`.

Files to examine:
- `./lib/screens/settings_screen.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/screens/dashboard_screen.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/core/constants.dart`
- `./lib/theme.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/widget/latest_walk_card_test.dart`
- `./test/robot/peaks/peak_info_journey_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens Settings.
2. User turns on `Show Peak Info`.
3. User returns to the map or a peak mini-map.
4. On surfaces at or above the zoom threshold, each visible peak marker shows the peak icon, then the peak name, then the height.
5. User turns the setting off and the labels disappear.

Alternative flows:
- Returning user: the stored preference restores on app start.
- Mini-map surfaces: the same toggle is threaded through the shared renderer, but labels remain hidden below the zoom threshold.
- Existing marker interaction: tapping/hovering a peak still opens the popup and hover ring as before.

Error flows:
- Preferences unavailable: keep the last in-memory state or the default and do not block rendering.
- Missing peak data: show safe fallback text instead of crashing.
</user_flows>

<requirements>
**Functional:**
1. Add a boolean peak-info setting backed by `SharedPreferences` with a default of `false` when no stored value exists.
2. Add a simple switch on the Settings screen labeled `Show Peak Info`.
3. Persist toggle changes immediately and restore them on later launches.
4. Apply the setting to every peak-marker renderer that uses `buildPeakMarkers`, but only render the label stack when the effective zoom is at or above `MapConstants.peakInfoMinZoom`.
5. When enabled, render each peak marker as a centered vertical stack in this order: marker icon pinned to the coordinate, peak name, height.
6. Keep the marker hitbox at the current icon size; the label stack must render outside the hitbox and must not change hover or tap targeting.
7. Use the existing elevation formatter for the height text so marker labels match popup formatting.
8. Keep existing marker keys, hitboxes, hover rings, and popup behavior unchanged.
9. Add a reusable outlined-text painter/helper in `./lib/theme.dart` so the fill uses `colorScheme.surface`, the outline uses `colorScheme.onSurface`, and both use the `bodySmall` size.
10. Add a `MapConstants.peakInfoMinZoom` constant in `./lib/core/constants.dart` with a value of `12.0`.
11. Add a `MapConstants.peakInfoLabelMaxCharacters` constant in `./lib/core/constants.dart` with a value of `20`.

**Error Handling:**
12. If loading or saving the preference fails, keep the UI usable and fall back to the safe default behavior.
13. If a peak name or elevation is missing, use a safe placeholder such as `—` rather than throwing.

**Edge Cases:**
14. Long peak names should not expand the marker indefinitely; they should stay within `MapConstants.peakInfoLabelMaxCharacters`, wrap to at most 2 lines, and truncate with ellipsis after 2 lines.
15. The label layout must remain stable across different zoom levels and screen sizes.
16. The change must not alter peak selection, hover, or popup placement.

**Validation:**
17. Add coverage for the setting state machine, the shared marker renderer, and the settings-to-map journey.
18. Keep tests deterministic by using fakes or in-memory stores for preferences and repositories.
</requirements>

<boundaries>
Edge cases:
- First launch with no stored preference: treat `Show Peak Info` as off.
- Very small mini-map surfaces: keep the shared label stack compact and centered instead of introducing a second label system.
- Mini-maps are intentionally icon-only under the zoom threshold because they do not currently support zooming; a future enhancement may change that.
- Disabled setting: marker appearance must match the current icon-only behavior.
- Peak labels should wrap to at most 2 lines, stay within the 20-character cap, and use ellipsis overflow.

Error scenarios:
- `SharedPreferences` read/write failure: do not surface a blocking error state to the user.
- Missing peak name/elevation: show placeholders and continue rendering.

Limits:
- No database migration.
- No server/API changes.
- No change to peak popup content, only marker presentation and the settings toggle.
</boundaries>

<implementation>
Create or update these files:
- `./lib/providers/peak_marker_info_settings_provider.dart` or the equivalent new Riverpod settings provider
- `./lib/screens/settings_screen.dart`
- `./lib/theme.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/screens/dashboard_screen.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/core/constants.dart`

Implementation approach:
- Keep the peak-info flag as a plain boolean setting and pass it into the shared marker builder instead of reading preferences inside the renderer.
- Model the setting with a synchronous `Notifier<bool>` that defaults to off and hydrates preferences in the background, like `theme_provider.dart`.
- If late hydration returns after the user has already toggled the switch, keep the in-memory value and do not overwrite the user's choice.
- Use the shared zoom threshold to suppress labels below `MapConstants.peakInfoMinZoom`; keep the marker icon visible.
- Keep the icon anchored on the coordinate and let the labels sit centered underneath it.
- Ensure the visible label stack does not expand the `Marker` hitbox.
- Centralize the label composition in the shared marker helper so all peak-marker surfaces stay in sync.
- Add the reusable outlined-text painter/helper in `lib/theme.dart` and reuse it everywhere peak labels render.
- Enforce the 20-character cap and 2-line maximum in the shared label helper.
- Preserve existing marker keys and interaction behavior by only extending the marker child content.

What to avoid:
- Avoid duplicating separate label implementations per screen.
- Avoid coupling marker rendering directly to `SharedPreferences`.
- Avoid changing popup logic or peak-selection state as part of this feature.
</implementation>

<stages>
1. Add the persistent setting and theme helper. Verify provider-level tests cover default state, toggle persistence, and failure fallback.
2. Wire the shared marker renderer and every call site. Verify widget tests show labels off below zoom 12 and on at/above zoom 12 for the main map, while mini-map surfaces remain icon-only when their effective zoom is below the threshold.
3. Add the settings-screen journey coverage. Verify the switch can be toggled from Settings and the marker labels reflect the new state after navigation or rebuild.
4. Verify long peak names respect the 20-character cap, wrap to at most 2 lines, and ellipsize after 2 lines.
</stages>

<validation>
Use vertical-slice TDD:
- Write one failing test at a time.
- Keep each green step minimal.
- Refactor only after the behavior is green.

Baseline automated coverage outcomes:
- Logic/business rules: provider tests for default state, persistence, and failure fallback.
- UI behavior: widget tests for the settings switch and label rendering on the shared marker helper.
- Critical journeys: robot-driven coverage for toggling the setting and verifying peak labels on the map.

Required test slices:
1. Provider slice: add a test for default-off behavior, a test that persists `true`, and a test that falls back safely when persistence fails.
2. Renderer slice: add a widget test for `buildPeakMarkers` with labels disabled and enabled.
3. Screen wiring slice: add a widget test for `SettingsScreen` that finds `Show Peak Info` and toggles it.
4. Surface slice: add widget coverage for both mini-map call paths so the shared renderer remains icon-only below the zoom threshold.
5. Label slice: add a widget test for a long peak name that proves the 20-character cap, 2-line maximum, and ellipsis overflow are enforced.
6. Journey slice: add or extend a robot test under `./test/robot/settings/` or `./test/robot/peaks/` that opens Settings, toggles the switch, returns to the map, and confirms peak labels appear or disappear at the threshold.

Stable selectors and seams:
- Keep a stable key for the switch, such as `show-peak-info-switch`.
- Preserve `peak-marker-layer`, `peak-marker-hitbox-<osmId>`, and `peak-marker-hover-<osmId>` keys.
- Add stable keys for the rendered marker labels if the tests need them.
- Use in-memory preference and repository fakes so the tests do not depend on disk or network.

Expected behavior per test type:
- Provider tests should prove stored values survive rebuilds and invalid storage does not crash the app.
- Widget tests should prove the marker child changes shape when the flag changes, labels are suppressed below the threshold, and hit testing still works.
- Robot tests should prove the user can toggle the setting from Settings and observe the result on the map at or above the threshold.
</validation>

<done_when>
The `Show Peak Info` switch is present in Settings, persists across launches, and controls peak name/height labels on peak markers at or above the shared zoom threshold.
The main map and mini-map surfaces all follow the same shared rendering path, with labels suppressed below the threshold.
Automated tests cover the setting state, marker rendering, and the settings-to-map journey.
</done_when>
