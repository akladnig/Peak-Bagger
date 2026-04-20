<goal>
Refactor `./lib/screens/settings_screen.dart` into smaller, screen-scoped files so the Settings code is easier to navigate, review, and extend without changing how the `/settings` route behaves for users.

This matters because the current screen mixes route lifecycle handling, async action orchestration, confirmation/result/error dialogs, status messaging, and settings-section UI in one 765-line file. The outcome should preserve the existing Settings experience exactly while leaving a clear coordinator file for future work.
</goal>

<background>
Tech stack: Flutter, Riverpod, SharedPreferences-backed settings providers, GoRouter, and existing widget/robot tests.

Project constraints:
- Preserve the `/settings` route entry in `./lib/router.dart`.
- Preserve all current widget keys, user-visible copy, button labels, dialog titles, subtitles, and status text.
- Preserve all current provider entry points and notifier calls.
- Do not add packages.
- Keep the refactor local to the Settings screen; do not redesign providers, routes, or UX.

Files to examine:
- @pubspec.yaml
- @lib/router.dart
- @lib/screens/settings_screen.dart
- @lib/providers/map_provider.dart
- @lib/providers/gpx_filter_settings_provider.dart
- @lib/providers/peak_correlation_settings_provider.dart
- @lib/providers/tasmap_provider.dart
- @lib/services/tile_downloader.dart
- @lib/services/peak_refresh_result.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @test/widget/peak_refresh_settings_test.dart
- @test/widget/gpx_filter_settings_test.dart
- @test/widget/peak_correlation_settings_test.dart
- @test/widget/gpx_tracks_shell_test.dart
- @test/widget/gpx_tracks_summary_test.dart
- @test/robot/gpx_tracks/gpx_tracks_robot.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart

Output paths:
- Keep `./lib/screens/settings_screen.dart` as the stable route-facing screen and coordinator.
- Create `./lib/screens/settings_screen_actions.dart` for the action-tile area and inline status/recovery messaging widgets.
- Create `./lib/screens/settings_screen_dialogs.dart` for confirmation, result, and failure dialogs used by Settings actions.
- Create `./lib/screens/settings_screen_sections.dart` for the Track Filter section, Peak Correlation section, and shared dropdown field builders used only by Settings.
- Add a focused widget regression only if inspection shows an uncovered behavior-sensitive Settings path that is not already protected by the existing tests.
</background>

<user_flows>
These are regression flows to preserve, not new behavior to invent.

Primary flow:
1. User opens `/settings`.
2. User sees the same action tiles, provider-backed settings sections, recovery/status messaging, and app bar title as today.
3. User triggers a Settings action or expands a settings section.
4. The same loading, success, warning, error, and close/cancel states appear with the same text and keys.

Alternative flows:
- Confirmation flow: user opens the peak refresh or track reset confirmation dialog and chooses Cancel; no work starts and no new status/result dialog appears.
- Settings-load flow: user opens Settings before `gpxFilterSettingsProvider` or `peakCorrelationSettingsProvider` has resolved; the same loading tiles appear, then the same expanded/collapsed sections render once loaded.
- Navigation flow: user starts an action that sets `_status`, leaves `/settings`, and later returns; the status is cleared when the route becomes hidden, exactly as today.
- Busy-state flow: user opens Settings while track work or a local screen action is in progress; the same tiles show spinners and become non-tappable under the same conditions.

Error flows:
- Peak refresh failure: the same failure status text is set and the same `Peak Data Refresh Failed` dialog appears with the same close key.
- Track reset or recalculation failure: the same error dialogs appear, driven by the same `mapProvider` error state.
- Provider load failure: the Track Filter and Peak Correlation sections show the same `Unable to load ... settings.` fallback tiles.
</user_flows>

<discovery>
Before implementation, confirm:
- `./lib/screens/settings_screen.dart` is the only in-scope screen file for this cleanup pass.
- The existing tests listed above cover the critical Settings behavior surface well enough to support a behavior-preserving refactor.
- All stable keys used by widget and robot tests are catalogued before any extraction starts.
- No extracted Settings helper needs to become a new cross-feature shared widget; extracted code should remain Settings-scoped unless reuse is already proven.
- This refactor will not introduce `part` / `part of`; extracted files must use explicit imports and explicit parameters.
</discovery>

<requirements>
**Functional:**
1. Reduce `./lib/screens/settings_screen.dart` to a coordinator that owns route visibility handling, screen-local async state, provider reads, and composition of extracted Settings UI pieces.
2. Keep the public `SettingsScreen` type, constructor, and route wiring in `./lib/router.dart` unchanged.
3. Extract the top Settings action area into `./lib/screens/settings_screen_actions.dart` so the screen no longer inlines every `ListTile` and status block.
4. Extract Settings dialogs into `./lib/screens/settings_screen_dialogs.dart` so confirmation, result, and failure dialog construction is no longer embedded in the screen file.
5. Extract the Track Filter and Peak Correlation UI into `./lib/screens/settings_screen_sections.dart`, including the shared integer/enum dropdown builders that are only used by Settings.
6. Preserve the current action set exactly: download offline tiles, refresh peak data, reset map data, reset track data, recalculate track statistics, Track Filter settings, and Peak Correlation settings.
7. Preserve current copy exactly for all titles, subtitles, body text, status text, and button labels.
8. Preserve the current settings-provider behavior exactly, including `AsyncLoading`, `AsyncError`, and `AsyncData` render states and the current persistence calls on selection changes.
9. Preserve the current route-hidden status clearing behavior driven by `router.routerDelegate` and `_currentPath()`.
10. Preserve the current use of post-frame dialog presentation after successful peak refresh, track reset, and track-statistics recalculation.
11. Keep `settings_screen.dart` as the only route-facing Settings screen file imported by `./lib/router.dart`; extracted siblings remain screen-local implementation detail.

**Error Handling:**
12. Preserve current peak refresh error handling, including status text update, mounted checks, failure dialog title/content, and `Key('peak-refresh-error-close')`.
13. Preserve current track reset and track-statistics recalculation failure handling, including reading `trackImportError` from `mapProvider` and showing the same dialog titles and close-button keys.
14. Preserve current provider-load fallback tiles and error copy for both settings sections.
15. If extraction introduces helper APIs, surface failures through the same existing screen paths rather than swallowing exceptions or adding new fallback behavior.

**Edge Cases:**
16. Preserve current disabled/onTap-null behavior when `_isDownloading`, `_isRefreshingPeaks`, `_isResettingMaps`, or `mapState.isLoadingTracks` is true.
17. Preserve current rendering when `mapState.hasTrackRecoveryIssue`, `trackOperationStatus`, `trackOperationWarning`, or `trackImportError` is present in any combination.
18. Preserve current behavior when dialog actions are triggered after async work completes or the widget becomes unmounted; mounted checks must remain effective.
19. Preserve the current default expansion behavior: `Peak Correlation` starts expanded and `Track Filter` does not.
20. Avoid over-fragmentation: do not create extra files beyond the planned Settings siblings unless a cohesive responsibility clearly exceeds those boundaries.

**Validation:**
21. Treat this as a behavior-preserving refactor first; any new tests should lock existing behavior, not justify a redesign.
22. Keep or improve automated coverage across logic/state behavior, screen/widget behavior, and critical Settings journeys.
23. Do not update test expectations to match a changed UX; if a test fails, prefer restoring the prior behavior unless the spec explicitly allows the change, which it does not.
</requirements>

<boundaries>
Edge cases:
- `Peak Correlation` is currently initially expanded while `Track Filter` is collapsed by default; preserve that difference unless existing tests already prove otherwise.
- The same keys must remain attached to the same user-facing controls or equivalent stable elements so robot/widget selectors stay valid.
- Extracted helpers may accept callbacks/state as parameters, but they must not take ownership of route navigation, provider lifecycle, or business-state orchestration that currently belongs to `SettingsScreen`.

Error scenarios:
- If a proposed extraction requires renaming provider entry points, route names, stable keys, or visible copy, keep that change out of scope.
- If a proposed dialog extraction makes async presentation flaky under widget tests, prefer leaving more orchestration in `settings_screen.dart` rather than weakening determinism.
- If a helper would only wrap one private method and add indirection without removing a real responsibility from the screen, do not extract it.

Limits:
- No new dependencies.
- No route changes.
- No UX redesign.
- No copy edits.
- No provider API redesign.
- No `part` / `part of` split.
- No unrelated cleanup in `map_screen.dart`, provider files, or service files beyond import adjustments required by the extraction.
</boundaries>

<implementation>
Do not introduce `part` / `part of` files for this refactor. Keep the extraction screen-scoped using top-level helpers with explicit inputs, small widgets with explicit constructor arguments, or shell-owned callbacks passed into extracted widgets/functions.

Any logic that directly calls `setState`, reads `ref`, performs provider writes, listens to the router, or schedules post-frame callbacks stays in `./lib/screens/settings_screen.dart` unless it is invoked through a shell-owned callback.

Implementation style:
- Use the existing `map_screen.dart` plus sibling `map_screen_*` files as the organizational model.
- Prefer feature-local widgets/functions with explicit parameters over new abstract layers.
- Keep business actions and lifecycle-sensitive code in the coordinator when moving them would blur ownership.

File-specific expectations:
- `./lib/screens/settings_screen.dart`: keep `SettingsScreen`, `_SettingsScreenState`, route-listener setup/teardown, `_currentPath()`, `_clearStatusWhenHidden()`, action methods that call providers/services, and screen composition.
- `./lib/screens/settings_screen_actions.dart`: own widgets/builders for the top action tiles, track-recovery/status messaging block, and the peak-refresh status text block.
- `./lib/screens/settings_screen_dialogs.dart`: own dialog builders or helper functions/widgets for peak refresh confirm/result/failure, track reset confirm/result/failure, and track-statistics result/failure dialogs, but not the async orchestration that decides when to show them.
- `./lib/screens/settings_screen_sections.dart`: own the Track Filter section, Peak Correlation section, `_buildIntegerDropdown`, `_buildEnumDropdown`, and filter-description formatting.

Stable selectors to preserve:
- `Key('refresh-peak-data-tile')`
- `Key('reset-map-data-tile')`
- `Key('reset-track-data-tile')`
- `Key('recalculate-track-statistics-tile')`
- `Key('peak-refresh-status')`
- `Key('peak-refresh-cancel')`
- `Key('peak-refresh-confirm')`
- `Key('peak-refresh-result-close')`
- `Key('peak-refresh-error-close')`
- `Key('reset-track-data-cancel')`
- `Key('reset-track-data-confirm')`
- `Key('track-reset-result-close')`
- `Key('track-reset-error-close')`
- `Key('track-stats-recalc-result-close')`
- `Key('track-stats-recalc-error-close')`
- `Key('gpx-filter-settings-section')`
- `Key('gpx-filter-hampel-window')`
- `Key('gpx-filter-elevation-smoother')`
- `Key('gpx-filter-elevation-window')`
- `Key('gpx-filter-position-smoother')`
- `Key('gpx-filter-position-window')`
- `Key('peak-correlation-settings-section')`
- `Key('peak-correlation-distance-meters')`

What to avoid:
- Avoid moving Settings-only UI into `./lib/widgets/`.
- Avoid converting current screen methods into generic services or controllers for this pass.
- Avoid changing dialog timing, such as replacing post-frame dialog display with immediate dialog calls that may alter test timing or mounted behavior.
- Avoid adding new stable keys to existing controls unless a missing deterministic selector is required for a regression test that already belongs to this screen.
- Avoid altering current `ListView` ordering or section placement unless a test-backed bug forces it.
</implementation>

<stages>
Phase 1: Lock down regression boundaries.
- Confirm the stable route, copy, keys, and test-covered flows before extraction.
- Add a missing regression test first only if inspection shows a behavior-sensitive gap.

Phase 2: Extract Settings sections.
- Move Track Filter, Peak Correlation, dropdown builders, and filter summary formatting into `./lib/screens/settings_screen_sections.dart`.
- Verify section loading, expansion, and persistence behavior before continuing.

Phase 3: Extract dialogs.
- Move confirmation, success, warning, and error dialog construction into `./lib/screens/settings_screen_dialogs.dart`.
- Verify dialog titles, content, actions, and stable keys before continuing.

Phase 4: Extract action/status UI.
- Move the top action tiles and inline status/recovery messaging into `./lib/screens/settings_screen_actions.dart`.
- Keep action callbacks, enabled/disabled conditions, and spinner behavior unchanged.

Phase 5: Final sweep.
- Remove dead imports and stray inline helpers.
- Run targeted Settings/widget/robot verification first, then full analysis and tests.
- Confirm `settings_screen.dart` reads as a coordinator rather than a 700-line mixed-responsibility file.
</stages>

<illustrations>
Desired:
- `./lib/screens/settings_screen.dart` clearly shows provider reads, local state, and composition of extracted Settings pieces.
- Dialog construction details live in one adjacent file instead of being interleaved with action methods.
- Settings section UI reads as cohesive, screen-local widgets rather than as hundreds of lines inside `build()`.

Avoid:
- Replacing existing keys/text with new ones because the files became cleaner.
- Splitting every tiny helper into its own file.
- Turning this cleanup into a redesign of settings state ownership or navigation behavior.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/state behavior: preserve coverage for route-hidden status clearing, provider-backed settings persistence, and action enabled/disabled conditions through existing public/widget interfaces; if a new pure helper seam is introduced and not already covered, add the smallest public-facing test slice needed to lock its behavior.
- UI behavior: keep widget coverage green for loading/error tiles, confirmation dialogs, result/failure dialogs, status text, close/cancel controls, and current section rendering.
- Critical user journeys: keep robot-driven regression coverage green for settings flows that recalculate track statistics and persist filter/correlation settings.

TDD expectations:
- Treat pure file extraction under already-green coverage as refactor work.
- If any behavior-sensitive area is not covered well enough before extraction, add one focused failing test first, make the minimal change to pass it, then continue.
- Use vertical slices when adding coverage: one failing test, minimal extraction/change, green, then refactor further.
- Prefer existing fakes, provider overrides, and test harnesses over new mocks; mock only true external boundaries.

Robot/widget/unit split:
- Robot tests: keep `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` green for the critical happy-path journeys that open Settings, recalculate track statistics, and persist filter/correlation settings.
- Widget tests: keep or extend `./test/widget/peak_refresh_settings_test.dart`, `./test/widget/gpx_filter_settings_test.dart`, `./test/widget/peak_correlation_settings_test.dart`, `./test/widget/gpx_tracks_shell_test.dart`, and `./test/widget/gpx_tracks_summary_test.dart` for dialog states, loading/error states, visible copy, and stable keys.
- Unit tests: add no new unit-test surface unless an extracted pure helper owns behavior that is awkward to validate through existing widget coverage; if such a helper is created, test it through its public API only.

Selectors and seams:
- Preserve the stable app-owned `Key` selectors listed in this spec.
- Keep deterministic test seams via the current Riverpod overrides, fake notifiers/repositories, and mocked SharedPreferences setup already used by existing tests.
- Do not require flaky async workarounds when post-frame callbacks and current harness patterns already support deterministic verification.

Verification commands:
- `flutter test test/widget/peak_refresh_settings_test.dart`
- `flutter test test/widget/gpx_filter_settings_test.dart`
- `flutter test test/widget/peak_correlation_settings_test.dart`
- `flutter test test/widget/gpx_tracks_shell_test.dart`
- `flutter test test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `./lib/screens/settings_screen.dart` is reduced to a clear coordinator that is materially smaller than the current implementation.
- The planned sibling files exist and each owns a cohesive Settings responsibility.
- The `/settings` route, current copy, stable keys, current provider calls, and current user-visible flows are preserved.
- Existing widget and robot Settings regressions stay green, with only minimal test additions for uncovered behavior if needed.
- `flutter analyze` and `flutter test` pass.
</done_when>
