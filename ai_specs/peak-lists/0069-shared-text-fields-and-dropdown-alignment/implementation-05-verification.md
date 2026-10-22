# Work Item 05 — Settings field and preference recovery

## Scope and ownership

- Retained ADS-1.0 and the local 2026-10-21 verification amendment: all themed
  fixtures and native checks use **My Seed Colour / dark**, without theme matrices.
- Settings uses the existing shared labelled-field/label-only dropdown for Scheme
  Variant, Track Filter and dependent windows, correlation thresholds, and Tile
  Cache zoom limits. Labels, option order, typed identities, preference keys and
  commit timing remain with their existing owners. Binary/multi-select controls
  are unchanged. Dependent-window callbacks reread current filter availability.
- API key and Local URL inherit central field decoration and wrapping errors.
  URL uses URL keyboard affordances and the exact syntax guidance. No associated
  tooltip, generic local border or field-level submit button was added.
- Tile Cache Search shows `Search ⌘F`, retains `Search Tasmap sheets`, has a
  contextual accessible name and decorative Search icon. Its owned keyboard
  handler checks current route/ancestor route, ticker, local-history/menu and
  download eligibility before focus/select-all/scroll. It never changes the query
  or selected sheet, switches routes, or queues an unavailable request.

## Persistence boundaries

### API key

The dialog stays mounted while its provider saves. The route's live attempt gate
protects barrier/back/direct `Navigator.pop`; Cancel and keyboard callbacks consult
the same current lock. Duplicate submissions are rejected before preparation.
The provider updates the effective key only after an accepted preference write;
false results and exceptions retain the prior effective key. Failure keeps the
controller/draft and actionable Save/Cancel guidance; success closes once. Idle
dismissal discards without writing. Controllers and keyboard resources are disposed,
and mounted/generation checks reject stale preparation/hydration/completion.

Diagnostic messages contain error types and stacks, not exception payloads or keys.
No online credential request or credential migration was added. The pre-existing
default credential's validity/exposure/rotation review remains Spec Follow-Up 2;
this work does not disclose, replace or rotate it. No new server-only-secret
boundary was identified.

### Local Topo

One synchronous attempt gate covers preference preparation, Save/Retry/Clear,
network validation, snapshot/status writes and recovery. False write/removal
results are failures. Save-before-validation, existing capability parsing,
overlay evolution, last-successful snapshot compatibility and safe Tracestrack
fallback are retained; no background probe, authentication or migration is added.

| Outcome | Result and recovery |
| --- | --- |
| Preparation/URL write fails before a new URL is confirmed | Keep the previous confirmed configuration and draft; retry **Save**. |
| URL saved, then cleanup/status fails | Read back actual storage; retain the newly saved URL, deactivate incompatible snapshots, offer **Retry** against that confirmed URL. |
| Capability request fails | Keep saved URL, remove active capabilities, distinguish network failure and offer **Retry**. |
| Snapshot/final validation status cannot persist | Do not publish the new snapshot or `Live validated`; quarantine incomplete persistence and offer **Retry**. |
| Clear partially fails | Reconcile remaining URL, deactivate availability, report incomplete Clear and keep **Clear** retry even if URL removal already succeeded. |
| Storage readback fails | Disable availability and uncertain Retry, identify the last-confirmed saved value, offer Save/Clear recovery. |

Readback calls `SharedPreferences.reload`: the legacy plugin's failed writes can
still mutate its optimistic cache. Runtime publication follows the confirmed
phase boundary, independently of draft text. A stored `validating`/failed snapshot
does not become a successful restored snapshot on launch; legacy snapshots without
a status remain supported. All terminal outcomes release the attempt lock. Stale
hydration/HTTP/preference work cannot publish after its owner/generation expires.

## Deterministic coverage

`test/harness/controlled_preferences.dart` models confirmed storage separately from
the optimistic cache, with controlled preparation/write/removal/readback outcomes.
Provider/widget/runtime tests cover false results and exceptions at URL, snapshot
and status phases, including cleanup after network failure and partial Clear;
assert saved/runtime/display consistency, recovery targets, fallback, retained
drafts, early duplicate/dismissal guards and no premature snapshot activation.

`test/widget/settings_selector_alignment_test.dart` exercises all nine Settings
selectors' typed option sets/order and actual immediate-Enter/navigated-Enter
behaviour at 1×/2× text, stable content-sized field width, dependency changes before
rebuild, Tile Cache 0–18 zoom menus, Search select-all/modal/menu/inactive-route/
pending exclusions, stale commits, resize and anchor removal. Existing shared
dropdown tests retain skip/wrap, hover/press/focus, consumed outside gesture,
Escape/Ctrl+C/back, focus return and cleanup coverage. Existing Settings/filter/
correlation/Tile Cache robot regressions remain part of completion verification.

No production Store, Mapping volume, live HTTP service or real key is needed.
Preference/HTTP/catalog/repository/Riverpod fixtures are deterministic. Existing
native ObjectBox prerequisite is `lib/libobjectbox.dylib` (README); no new native
dependency, schema/model/generated change or platform/window change is introduced.

## Verification results

Verification ran in the existing working tree, including the user's pre-existing
dark-only documentation/fixture changes. Only this slice's intended changes are
staged; unrelated work remains untouched. In the already-modified
`settings_screen_theme_test.dart`, only the shared-dropdown migration assertions
are included in this slice's commit. These results describe the verified working
tree, not a separate clean-checkout run.

Automated results:

- Initial focused provider/runtime/Settings/Tile Cache regression command: **75 passed**.
- Final focused provider/runtime/widget/shared-dropdown and Settings/basemap robot
  command: **109 passed**. This includes both shared menu rendering/input suites.
- GPX filter journey plus Settings filter regression rerun: **19 passed**.
- Final preference/provider/runtime rerun, including legacy URL/snapshot encoding
  compatibility after failed writes: **50 passed**.
- `flutter analyze`: **no issues found**. Formatting and `git diff --check` also pass.
- The first full `TZ=Australia/Hobart flutter test --reporter expanded` run reported
  **2,871 passed, 6 skipped, 1 failure**. The failure was the GPX filter robot's
  obsolete unscoped `None` lookup/framework-dropdown assertions. The robot now
  anchors actions to the existing field keys and open shared menu, and asserts
  the shared field's disabled availability; its targeted rerun passes.
- The second full run reported **2,872 passed, 6 skipped, 1 failure** in the newly
  added legacy URL/snapshot-encoding regression while its implementation/test were
  being updated during compilation. The final isolated 50-test persistence run
  passes, including that regression. Completion uses a further full rerun with
  source held unchanged, rather than treating this mixed-snapshot run as a Pass.

- **Final stable-source full suite:** `TZ=Australia/Hobart flutter test --reporter expanded`
  completed in **7:08**, with **2,873 passed, 6 inherited skips and no failures**.
  This includes the final legacy-encoding regression and corrected GPX robot.
  Skips are not counted as passes or a waiver of inherited feature gates.

Native rendering/input is distinct from human visual acceptance; no template-parity
or unrelated Dashboard/Time layout Pass is claimed.

### Native macOS rendering/input — 2026-10-22

The isolated runner is `test/harness/verify_settings_alignment.dart`:

```sh
flutter run -d macos -t test/harness/verify_settings_alignment.dart \
  --dart-define=SETTINGS_PROJECT_ROOT="$PWD"
```

Optional fixture-only defines `SETTINGS_NATIVE_WIDTH=1280|1600` and
`SETTINGS_NATIVE_SCALE=1|2` isolate a size/scale without changing application
preferences. The full runner uses both content sizes and scales, always
`MyTheme.dark`. It uses mock preferences, the local fixture catalog/repository and
fake capability HTTP; no normal application startup, Store or live service.

Completed OS pointer/keyboard evidence:

| Native content size | Text scale | Result |
| --- | --- | --- |
| 1280 × 960 | 1× | `SETTINGS_NATIVE_PASS` in the initial combined run. |
| 1280 × 960 | 2× | `SETTINGS_NATIVE_PASS`, isolated minimum/enlarged run completed. |
| 1600 × 1000 | 1× | `SETTINGS_NATIVE_PASS`, larger-size run. |
| 1600 × 1000 | 2× | `SETTINGS_NATIVE_PASS`, larger-size run completed both configurations. |

Checks use actual macOS content dimensions, CoreGraphics pointer events and
System Events keyboard events. They cover API save failure/retained draft/retry,
resizing a live failed form, exact URL syntax guidance, saved-URL retention after
snapshot persistence failure, validation Retry, Scheme Variant immediate and
navigated Enter, Tile Cache Search native Cmd+F/select-all, menu-owned Search
exclusion, open-menu/query resize retention and dropdown-only Ctrl+C. Flutter
framework/rendering errors are collected and fail the runner; all completed rows
above had no such errors.

Earlier native attempts were **not** counted as complete passes: the first clicked
the dropdown's surrounding layout rather than its actual box; subsequent runs
exposed native activation/text-input and transient AX window failures. The runner
now targets the real input/box, activates before clicking, confirms pointer delivery,
paces native typing, releases modifiers and retries only idempotent AX resizing
(never selection/typing). Minimum/enlarged and larger-size checks were isolated
to finish verification. This is automated native evidence, not an attributed human
visual review. No human Pass was requested or inferred. The build retains the
documented upstream ObjectBox SwiftPM warning, without preventing completion.

### Journey Verification

- Journey: Disabled Track Filter selections persist and disable dependent windows.
- Verification command(s): `TZ=Australia/Hobart flutter test --reporter expanded test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/widget/gpx_filter_settings_test.dart`
- Required seams/selectors: existing GPX robot/provider/preference fixtures;
  `gpx-filter-*` field keys and `shared-dropdown-menu`, with menu-scoped exact
  `None` copy and the field's shared decoration as the activation target.
- Result: `pass`
- Remaining risk: Widget journeys do not validate real GPX imports or preference
  backend durability. Persistence failures have separate deterministic coverage.

### Journey Verification

- Journey: Tile Cache downloads the selected Tasmap polygon.
- Verification command(s): `TZ=Australia/Hobart flutter test --reporter expanded test/robot/settings/tile_cache_journey_test.dart`
- Required seams/selectors: existing Tasmap repository and download-starter fakes,
  `tile-cache-*` field/suggestion/selection/download keys.
- Result: `pass`
- Remaining risk: No live tile downloads are performed; selection, geometry and
  dispatch are verified without a real cache backend or external service.

### Journey Verification

- Journey: Validated Local Topo selection works in Tasmania.
- Verification command(s): `TZ=Australia/Hobart flutter test --reporter expanded test/robot/map/basemap_selection_journey_test.dart`
- Required seams/selectors: existing catalog/HTTP/map fixtures and basemap option keys.
- Result: `pass`
- Remaining risk: Fixtures verify accepted capability/selection/fallback ownership,
  not a deployed server's availability or tile contents.

**Journey summary:** 3 declared affected journeys pass; none failed or unrun after
the selector correction. Real services/credentials remain intentionally outside
deterministic verification. Existing split journey/robot/harness ownership is
retained; no new journey framework or broad retrofit is introduced.
