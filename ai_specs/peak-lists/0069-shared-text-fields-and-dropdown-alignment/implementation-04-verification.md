# Work Item 04 verification — Peak List fields and import recovery

Date: 2026-10-22. Scope: [item 04](work-items/04-peak-list-fields-filters-and-import-recovery.md).
Subsequent user-reported Cmd+F failure and routed-shell correction:
[Cmd+F follow-up](cmd-f-follow-up.md). The earlier evidence below is retained as
delivery history; use the follow-up for current shortcut verification.
Verification uses only **My Seed Colour / `MyTheme.dark`**, with distinct behaviour,
failure, resize and enlarged-text checks retained. Runtime theme options are unchanged.

**Current status: all 15 criteria verified**, including the subsequent real-shell
Cmd+F correction and strict native rerun in [the follow-up](cmd-f-follow-up.md).
The initial partial-delivery evidence below is historical; its native shortcut
limitation was resolved by correcting the probe's device-modifier flags and
foreground activation, not by adding a native application workaround.

## Delivered boundaries

- Shared List Name and repeated GPX Track Name / Route Name inherit central
  decoration and common complete wrapping errors. Create remains uncalled.
- Add New Peak and selected-list details expose **Search ⌘F**, descriptive Search
  hints and accessible names, with decorative 24px icons and no field tooltips.
  Disposable focus owners and current eligibility checks select existing text only;
  modal/popup/menu ownership and disabled/inactive contexts exclude background focus.
- Add/Edit mutation guards cover Search, selection, Points, duration, Save and
  captured callbacks. Numeric Points retain integer/clamp/step behaviour, visible
  labels and peak-specific semantic names. Focus/lock/rebuild changes do not overwrite
  a retained numeric draft; the ordinary idle empty-input focus-loss rule remains.
- Points and metadata criteria use shared labelled-field / label-only dropdowns.
  Non-selectable region headings are separate from typed choices. Unavailable
  Difficulty stays checked and disabled, with the existing region display name
  (for example **Easy (Tasmanian) — unavailable for this list**); revalidation
  removes the retained row rather than duplicating it. Rating's exact textual
  thresholds and accessible minimum wording leave domain enums/matching/stars intact.
- Import takes its attempt lock before duplicate checking and starter hand-off.
  Its guarded route rejects direct programmatic pop as well as back/outside/keyboard
  dismissal. Child duplicate confirmations remain independently usable. Failure or
  rejected acceptance keeps CSV/name, releases protection and provides retry guidance;
  acceptance alone closes the form. Accepted work and later failures remain owned by
  Background Jobs, without cancellation, retained replay plans or Jobs-panel Retry.
- Dialog bodies and controls use actual available bounds, scaling and scrolling.
  Details header reflows when needed rather than clipping enlarged controls; no new
  breakpoint, reduced text scale, database schema/model, persistence or native window
  geometry/full-screen change is introduced.

## Deterministic verification

- `flutter analyze`: **no issues**.
- Focused 14-file regression run: **188 passed**, including shared dropdown
  rendering/input, Peak List/GPX fields, metadata/provider/domain rules, import
  background runner and the Peak Lists, Background Jobs and GPX robot journeys.
- Final six-file focused run: **142 passed**, including same-frame captured edit
  Save/Points callbacks, 2× GPX validation wrapping, retained numeric drafts through
  lock/unlock, 1280 × 960 / larger 2× details reflow, and owner removal during import
  preparation.
- `TZ=Australia/Hobart flutter test --reporter expanded`: **2,826 passed, 6
  skipped**, exit 0 (25m 34s). Skips are not counted as verified behaviour; the
  output includes existing ObjectBox-native-library availability skips. No new
  Flutter test skip was introduced for this item.

All new fixtures use controlled file pickers, in-memory repositories or provider
overrides. They require no production Store, Mapping volumes, network or credentials.
Owned controllers/focus/route resources are disposed. GPX asynchronous file-name
preparation also disposes unadopted controllers on failure or owner removal.

## Native macOS verification

`flutter run -d macos -t test/harness/verify_peak_list_fields.dart` is an isolated
production-widget probe with fixture data, real CoreGraphics pointer input and
System Events keyboard input. Native verification is not complete yet: an initial
probe needed to wait for window availability, and a subsequent probe found that
native Cmd+F did not focus the Add dialog's Search. Diagnostic traces showed no
Flutter key event for Cmd+F. Neither a window key-equivalent override nor removing
the default Find accelerator solved that probe; both experiments were removed.
A local native event-monitor experiment also failed to resolve that probe and was
removed. **No native application changes from these experiments are retained.**
Physical CoreGraphics Command/F injection (including a flags-changed modifier
event) delivered plain F down/up but **no Command modifier** to Flutter. Native
Cmd+F therefore remains **unverified**, not a product Pass or a proven menu defect.
Widget tests do verify contextual Cmd+F and select-all. A manual native shortcut
check, or an input harness that demonstrably delivers the Command modifier, is
still needed. The fixture's explicit `PEAK_LIST_NATIVE_SKIP_FIND=true` switch runs
the independent rendering/pointer/plain-key matrix without claiming that missing
check; its successful result is recorded below. The default probe remains strict and fails at Cmd+F.
Neither a successful build nor the Flutter runner's exit code constitutes a Pass.

Independent native rerun:

```sh
flutter run -d macos -t test/harness/verify_peak_list_fields.dart \
  --dart-define=PEAK_LIST_NATIVE_SKIP_FIND=true
```

**Passed all four independent configurations:** 1280 × 960 and 1600 × 1000 actual
macOS content sizes, each at 1× and 2× text, using My Seed Colour/dark. Actual
window resizing preserves the Duration draft and exercises an open shared menu.
CoreGraphics pointer input verifies Add selection/Points adjustment, edit validation
and Points-menu opening; native plain Return/Escape and Down/Return exercise
unchanged menu close and unavailable-Difficulty-to-Any navigation. Native Import
failure retains CSV/name and idle Cancel closes. **No Flutter rendering errors.**
Every configuration explicitly reports **Cmd+F=NOT VERIFIED**. This is not whole-item
completion, a native shortcut Pass, human visual acceptance or template parity.

No attributed human visual acceptance or template parity is claimed. The separate
Dashboard/Time layout gate is unaffected.

## Journey Verification

### Journey Verification
- Journey: Import attempt lock, duplicate cancellation, retained failure and retry
- Verification command(s): `flutter test test/widget/peak_list_import_recovery_test.dart`
- Required seams/selectors: controlled duplicate/starter futures, fake CSV picker;
  `peak-list-import-*`, `peak-list-update-*` and `peak-list-name-field` keys
- Result: `pass`
- Remaining risk: No real OS file-picker or production importer throughput is
  exercised. Native Cmd+F delivery is a separate outstanding check.

### Journey Verification
- Journey: Active details Search versus Add dialog Search; enlarged reflow and drafts
- Verification command(s): `flutter test test/widget/peak_lists_screen_test.dart test/widget/peak_list_peak_dialog_test.dart`
- Required seams/selectors: in-memory repositories/provider overrides; existing
  details/Add Search, selection, Save, Points and failure keys
- Result: `pass`
- Remaining risk: Native Command-modifier delivery remains unverified. The small
  new widget flows reuse local fixtures rather than adding a new robot framework;
  extract shared setup if their scope grows.

### Journey Verification
- Journey: Nullable Any, retained unavailable Difficulty and exact Rating thresholds
- Verification command(s): `flutter test test/widget/peak_list_filter_dropdown_test.dart test/providers/peak_list_details_metadata_filter_provider_test.dart`
- Required seams/selectors: typed fixture options; existing criterion/option keys,
  unavailable-entry key and accessible Rating wording
- Result: `pass`
- Remaining risk: Fixture/domain tests do not replace live dataset validation.

### Journey Verification
- Journey: Existing Peak Lists add/import regressions
- Verification command(s): `flutter test test/robot/peaks/peak_lists_journey_test.dart`
- Required seams/selectors: existing `PeakListsRobot` (`openAddPeakDialog`,
  `toggleAddPeak`, `enterAddPeakPoints`, `submitAddPeakDialog`), fake picker,
  controlled refresh scheduler and repository overrides
- Result: `pass`
- Remaining risk: Local fakes do not exercise production filesystem permissions.

### Journey Verification
- Journey: Background import/export progress across shell navigation
- Verification command(s): `flutter test test/robot/background_jobs/background_jobs_journey_test.dart`
- Required seams/selectors: existing `BackgroundJobsRobot` (`openDashboard`,
  `expectJobStatus`, `expectJobProgressText`, `dismissJob`), controlled job/notifier
  state, fake file selection and existing Jobs/shell keys
- Result: `pass`
- Remaining risk: This existing regression seeds/controls Jobs state; it is not
  independent proof of real importer throughput or OS background execution.

### Journey Verification
- Journey: GPX names/failed start and existing imported-Track selection regression
- Verification command(s): `flutter test test/widget/gpx_import_dialog_test.dart test/robot/gpx_tracks/single_track_import_journey_test.dart`
- Required seams/selectors: fake picker/prefilled names/starter, repeated GPX name
  keys, `TestMapNotifier`, seeded selected Track and `track-info-panel`
- Result: `pass`
- Remaining risk: The existing Track journey starts from selected imported state;
  it does not itself execute the real GPX importer or native file picker.

Summary: all six listed automated flow groups passed. No required automated flow
was silently skipped. The outstanding native shortcut check is not counted as
automated/native acceptance, and inherited full-suite skips remain explicit above.
