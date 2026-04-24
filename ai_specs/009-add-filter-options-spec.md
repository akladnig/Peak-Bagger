<goal>
Update GPX track filter settings so users can disable the outlier filter and either smoother independently from the settings screen.

The existing numeric window dropdown stays in place. The new behavior is:
1. add an `Outlier Filter` dropdown with `None` and `Hampel Filter`
2. add `None` as an option to the existing `Elevation smoother` dropdown
3. add `None` as an option to the existing `Position smoother` dropdown
</goal>

<background>
Tech stack: Flutter with Riverpod state management and SharedPreferences for persistence.

Relevant files:
- `./lib/providers/gpx_filter_settings_provider.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/services/gpx_track_filter.dart`
- `./test/widget/gpx_filter_settings_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

Current filter controls:
- Hampel window: 5, 7, 9, 11
- Elevation smoother: Median, Savitzky-Golay
- Position smoother: Moving average, Kalman
</background>

<user_flows>
Primary flow:
1. User opens Settings.
2. User expands `Track Filter`.
3. User chooses `None` or `Hampel Filter` in `Outlier Filter`.
4. User optionally sets `Elevation smoother` or `Position smoother` to `None`.
5. The corresponding window control is disabled whenever its parent stage is set to `None`.
6. The saved window value is preserved while disabled so it can be restored when the stage is re-enabled.
7. Settings persist after leaving and reopening the app.

Alternative flows:
- Returning user: previously saved `None` selections remain selected after reload.
- First-time user: sees the current defaults, with the new `Outlier Filter` defaulting to `Hampel Filter`.
- Mixed state: user can disable outlier filtering while leaving one or both smoothers enabled.
</user_flows>

<requirements>
**Functional:**
1. Add a new `Outlier Filter` dropdown with options `None` and `Hampel Filter`.
2. Add `None` as a selectable option in `Elevation smoother`.
3. Add `None` as a selectable option in `Position smoother`.
4. Keep the existing Hampel window dropdown options unchanged.
5. When `Outlier Filter` is `None`, the Hampel filter stage is skipped entirely.
6. When `Elevation smoother` is `None`, elevation smoothing is skipped entirely.
7. When `Position smoother` is `None`, position smoothing is skipped entirely.
8. Persist the three new/updated selections through SharedPreferences and restore them on app start.

**Error Handling:**
9. Missing or invalid stored values fall back to the existing defaults.

**Edge Cases:**
10. Disabling one filter must not reset the stored value for any other filter.
11. The Hampel window value remains stored even when `Outlier Filter` is `None`, so re-enabling the outlier filter restores the previous window selection.
12. Selecting `None` for a smoother does not alter its stored numeric/window-related settings.

**Validation:**
13. Dropdown labels show `None` for the disabled choices and the existing labels for enabled choices.
14. The settings summary line reflects disabled states clearly, for example `Outlier Filter: None • Elevation smoother: Median • Position smoother: None`.
15. The summary example is illustrative only; the disabled-control behavior still applies even if the wording changes slightly.
</requirements>

<boundaries>
Edge cases:
- All three controls disabled: only the base GPX point pruning still runs.
- Only outlier filtering disabled: elevation and position smoothing still run if enabled.
- Only smoothers disabled: Hampel filtering still runs if `Outlier Filter` is `Hampel Filter`.
- A disabled window control is visibly disabled, not hidden.

Error scenarios:
- Corrupted stored enum names or unexpected values: fall back to defaults, not to `None`.

Limits:
- Do not change the existing Hampel window choices or rename the window control.
</boundaries>

<implementation>
Files to modify:
1. `./lib/providers/gpx_filter_settings_provider.dart`
   - Add a new enum for `Outlier Filter` with `none` and `hampel`.
   - Add `none` to the elevation and position smoother enums.
   - Add any new provider fields needed to store the outlier filter selection.
   - Keep the Hampel window field and its numeric defaults unchanged.
   - Update save/load logic so the new enum values round-trip through SharedPreferences by name.

2. `./lib/screens/settings_screen.dart`
   - Add the `Outlier Filter` dropdown above the existing window control.
   - Add `None` to the elevation smoother dropdown.
   - Add `None` to the position smoother dropdown.
   - Keep the Hampel window dropdown and its numeric options unchanged.
   - Disable the corresponding window control whenever its parent selector is `None`, while preserving the stored value.
   - Update the settings summary text to include the disabled/enabled state of the three controls.

3. `./lib/services/gpx_track_filter.dart`
   - Skip the Hampel stage when the new outlier filter selection is `None`.
   - Skip elevation smoothing when the elevation smoother selection is `None`.
   - Skip position smoothing when the position smoother selection is `None`.
   - Preserve the existing processing order for enabled stages.

4. `./test/widget/gpx_filter_settings_test.dart`
   - Add widget coverage for the new dropdown options and disabled-state rendering.

5. `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
   - Add robot helpers for selecting `None` on the new dropdowns, using clear names such as `setOutlierFilterNone()`, `setElevationSmootherNone()`, and `setPositionSmootherNone()`.

6. `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
   - Add an end-to-end journey that proves the new selections persist.

Patterns to follow:
- Use the existing dropdown helper style for the smoother enums.
- Preserve existing widget keys where possible and add a stable key for the new `Outlier Filter` control.
- Prefer explicit enums over sentinel values for disabled states.
</implementation>

<validation>
**Manual verification:**
- Open Settings and confirm the new `Outlier Filter` dropdown appears.
- Select `None` for `Outlier Filter`, `Elevation smoother`, and `Position smoother` independently.
- Verify the summary text updates immediately.
- Restart the app and verify all selections persist.
- Import a GPX track and verify disabled stages do not run.

**Automated tests:**
- Widget test: `Outlier Filter`, `Elevation smoother`, and `Position smoother` each show `None` plus their enabled options.
- Widget test: selecting `None` updates provider state and summary text.
- Widget test: each dependent window control is disabled when its parent selector is `None` and re-enabled when restored.
- Robot journey: the settings flow persists the new selections across navigation and reload.
- Unit test: provider save/load round-trips the new enum values.
- Unit/integration test: the filter service skips disabled stages but still runs enabled stages in the existing order.

Test split:
- Widget tests for dropdown labels, selection state, and summary text.
- Robot tests for the settings journey and persistence.
- Unit tests for provider serialization and filter-service branching.
</validation>

<done_when>
1. `Outlier Filter` exists with `None` and `Hampel Filter`.
2. `Elevation smoother` and `Position smoother` each include `None`.
3. The Hampel window dropdown stays unchanged.
4. Disabled selections persist across app restarts.
5. Disabled stages are skipped in the filter service.
6. Widget, robot, and unit tests cover the new behavior.
</done_when>
