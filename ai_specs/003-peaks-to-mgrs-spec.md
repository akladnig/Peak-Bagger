<goal>
Add persisted MGRS metadata to peak records and ensure the Refresh Peak Data action populates it safely. This lets the app reuse peak grid data without recomputing it from lat/lon every time and keeps the refresh flow deterministic for users.
</goal>

<background>
Flutter app with ObjectBox, Riverpod, OverpassService, and a Settings screen refresh action. Current `Peak` records store name, elevation, latitude, longitude, and area only. `MapNotifier.refreshPeaks()` currently clears the peak repository before refetching, which must be replaced with an atomic replace flow. `MapNotifier` currently hardcodes its `OverpassService` and `PeakRepository` dependencies, so the refresh path needs Riverpod-backed seams for deterministic tests, and `lib/main.dart` must override those providers at app startup the same way the existing repository providers are wired. Existing MGRS formatting already uses `mgrs_dart` in `MapNotifier._convertToMgrs()`, so the new peak enrichment must follow the same library and formatting conventions.

Files to examine:
`./lib/models/peak.dart`
`./lib/providers/map_provider.dart`
`./lib/screens/settings_screen.dart`
`./lib/services/overpass_service.dart`
`./lib/services/peak_repository.dart`
`./lib/objectbox.g.dart`
`./test/...`
</background>

<discovery>
Before implementation, inspect the current ObjectBox migration path, peak import flow, and any existing tests for refresh behavior. Confirm where to place a shared MGRS derivation helper so startup load and manual refresh use one code path, and verify how ObjectBox schema regeneration is handled in this repo.
</discovery>

<user_flows>
Primary flow:
1. User opens Settings.
2. User taps Refresh Peak Data.
3. App shows a confirmation dialog.
4. User confirms the refresh.
5. App shows loading state.
6. App fetches peaks, derives MGRS fields, stores the replacement dataset, and shows the result dialog.
7. If refresh fails, the app shows the failure dialog and keeps existing peaks.

Alternative flows:
- First launch with an empty peak store: peak loading uses the same enrichment pipeline during startup.
- Repeated refresh: refresh replaces the existing stored peak set with fresh data.
- Cancel from the confirmation dialog: no data changes, no loading state, and the user stays on Settings.

Error flows:
- Network or Overpass failure: keep existing peaks and show an error.
- Partial bad data: skip invalid peak records, keep valid ones, and show a warning count; if no valid records remain, keep existing data and show an error.
</user_flows>

<requirements>
**Functional:**
1. Add persisted `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` fields to `Peak`.
2. Store MGRS components as fixed-width strings so leading zeros are preserved. All four new fields must be non-null `String` values, and each must default to `''` for existing records. For a combined MGRS string like `55GEN1234567890`, map `gridZoneDesignator = 55G`, `mgrs100kId = EN`, `easting = 12345`, and `northing = 67890`.
3. Derive the fields from lat/lon using `mgrs_dart` in one shared enrichment path used by both startup load and manual refresh.
4. Replace the stored peak set atomically after successful fetch and enrichment. Build the full replacement list first, then replace the stored rows in one rollback-safe repository operation or transaction. Do not clear existing peaks before the replacement write succeeds.
5. Make `MapNotifier.refreshPeaks()` return a `PeakRefreshResult` that carries imported and skipped counts plus an optional warning message for partial successes.
6. Make `MapNotifier.refreshPeaks()` throw on hard failure after preserving the existing dataset.

**Error Handling:**
7. If fetch, conversion, or storage fails, leave the existing dataset unchanged and surface an error.
8. If some records are invalid, skip only those records and report the skipped count; if no valid records remain, fail the refresh.

**Edge Cases:**
9. Preserve behavior for peaks already loaded before this change by backfilling them on the next refresh.
10. Keep current peak search and selection behavior unchanged aside from the new fields being available.

**Validation:**
11. Add stable selectors for the refresh tile, confirmation dialog, confirm button, cancel button, result dialog close button, failure dialog close button, and refresh status so widget and robot tests do not rely on localized text.
</requirements>

<boundaries>
Edge cases:
- Null or malformed peak coordinates: skip the record, do not crash the refresh.
- Empty Overpass response: treat as a failed refresh and keep existing data.
- Repeated refresh taps: disable the action while loading.
- Refresh confirmation dialog: use the same pattern as `_confirmResetTrackData` with title `Refresh Peak Data?`, a warning that the current peak set will be overwritten, a cancel action, and a confirm action.
- Refresh result dialog: use the same pattern as `_showResetTrackDataResult` with title `Peak Data Refreshed` and body text `X Peaks imported`, plus warning text when applicable.
- Refresh failure dialog: use the same pattern as `_showResetTrackDataFailure` with title `Peak Data Refresh Failed` and the error text surfaced from `MapNotifier`.
- The refresh flow is modal: confirmation first, then loading while the refresh runs, then either the result dialog or the failure dialog.

Error scenarios:
- Overpass 500 or timeout: show an error and preserve stored peaks.
- ObjectBox write failure: show an error and preserve stored peaks.
- Conversion failure on one peak: count it as skipped, continue if valid peaks remain.

Limits:
- Keep MGRS precision fixed at 5 digits for easting and northing.
- Do not add search or filter features on the new fields unless separately requested.
</boundaries>

<implementation>
1. Update `./lib/models/peak.dart` to hold the new fields and a conversion-friendly factory or helper.
2. Add Riverpod providers for `OverpassService` and `PeakRepository`, then inject them into `MapNotifier` so refresh can be swapped in tests.
3. Update `./lib/main.dart` to override the new providers at app startup.
4. Add a shared peak MGRS converter in `./lib/services/peak_mgrs_converter.dart` or an equivalent service.
5. Refactor `./lib/providers/map_provider.dart` so peak load and refresh both use the same atomic replace path and return `PeakRefreshResult`.
6. Update `./lib/services/peak_repository.dart` with an atomic replace method.
7. Update `./lib/screens/settings_screen.dart` with a stable refresh key and consistent status messaging.
8. Regenerate ObjectBox schema artifacts as needed.
9. Add tests under `./test/...` for conversion, repository replacement, and refresh UI and journey coverage.
10. Avoid computing MGRS in the UI layer; keep it in the data or domain path so tests stay deterministic.
</implementation>

<stages>
Phase 1: Add the MGRS converter and Peak schema fields, then verify with unit tests for known coordinates and invalid input handling.
Phase 2: Refactor peak load and refresh to use atomic replacement, then verify repository and provider tests for success, empty-result, and failure rollback.
Phase 3: Add widget and robot coverage for the Settings refresh journey, then verify loading, success, warning, and failure states.
</stages>

<validation>
1. TDD slice order: converter tests first, then repository atomic replace tests, then provider refresh tests, then settings widget and robot tests.
2. Use Riverpod overrides or injected test doubles for Overpass and peak storage; do not mock internal helpers.
3. Unit tests must verify:
   - known peak coordinates produce the expected grid zone, 100k id, easting, and northing
   - leading zeros are preserved
   - invalid coordinates are skipped or rejected as specified
4. Repository and provider tests must verify:
   - successful refresh replaces the dataset atomically
   - failed refresh leaves preexisting peaks untouched
   - empty refresh results do not wipe stored peaks
5. Widget tests must verify:
     - refresh tile shows loading state and disables repeat taps
     - confirmation dialog appears before overwrite and cancel is a no-op
      - result dialog shows `X Peaks imported` and warning text when applicable
      - failure dialog shows `Peak Data Refresh Failed`
      - warning counts surface when some peaks are skipped
      - dialog sequence is confirmation -> loading -> result/failure
6. Robot coverage must verify the critical Settings journey end to end using stable selectors:
    - `Key('refresh-peak-data-tile')`
    - `Key('peak-refresh-status')`
7. Baseline coverage outcome:
   - logic and business rules: covered by unit tests
   - UI behavior: covered by widget tests
   - critical user journey: covered by a robot test
</validation>

<done_when>
1. Every persisted peak has populated MGRS fields after a successful refresh.
2. Refresh never destroys existing peak data on network, conversion, or storage failure.
3. Settings refresh has deterministic loading, success, and error feedback with stable selectors.
4. Automated tests cover conversion, atomic replacement, and the refresh journey.
</done_when>
