# Work Item 03 verification

Date: 2026-10-21. Scope: [Map fields, Search and calendar alignment](work-items/03-map-fields-search-and-calendar-alignment.md), ADS-1.0 and the locally adopted 2026-10-19/20/21 amendments/supplements; macOS / Desktop wide only.

**Outcome: complete.** All 14 acceptance criteria are verified at their recorded
automated/native surfaces. Final analysis, the 284-test focused run, the full suite
and the complete native matrix/resize probe passed. Historical failed/interrupted
attempts and verification limits remain below rather than being counted as Passes.

## Implementation

- Map Search, Start/End date, both Year controls, Walking Speed, Go to location,
  Route/Waypoint/Favourite name prompts, Peak Info Name/Elevation, route-draft name
  and repeated overlay Opacity fields inherit the existing central decoration.
  Removed local generic outlines/density/padding. Common `SharedFieldError` keeps
  complete errors soft-wrapped outside editable content, without duplicate endpoint
  feedback. Ordinary labels remain floating; Search is exactly **Search ⌘F** with
  the retained descriptive **Search Peaks** hint and **Main Map Search** semantics.
- Region, Sort, Group and both Month selectors use `SharedDropdown` labelled-field /
  label-only presentation and retain typed values/options/order. Region's closed
  value now uses the complete menu label rather than the obsolete compact trigger.
  Existing trigger/choice selectors retain their meaning; tests no longer depend
  on `PopupMenuButton` / `DropdownButtonFormField` internals. The shared component
  now tolerates an unthemed host's absent content padding instead of crashing;
  centrally themed production styling is unchanged.
- Main Map Cmd+F opens Search or selects its **raw** existing query, without
  reopening/resetting categories, flushing debounce or changing criteria/drafts.
  Current route/TickerMode, modal, drawer, picker and Save eligibility are checked
  before focus. Shared menus consume background shortcuts. Unavailable actions are
  not queued. Search retains its existing 180ms debounce, minimum query length,
  date parser, category/region/sort/group/pagination and result-selection owners.
- Each calendar Year has its own presentation-owned controller/focus/error. Partial
  edits do not validate; Enter or blur accepts 1…9999 or retains input with exactly
  **Enter a year from 1 to 9999**. Invalid navigation changes neither calendar nor
  dates; valid navigation changes only that calendar. Dismissal disposes transient
  navigation edits/errors. Apply still uses selected draft dates independently of
  Year errors. Existing date-only parsing, endpoint copying, Clear/Cancel/Apply and
  trigger focus remain unchanged. Escape/Ctrl+C close the picker locally after
  any open dropdown has had first refusal.
- Calendar and Walking Speed adjustment/choice controls keep semantic names without
  field-associated tooltips. Calendar body scrolling, wrapping Month/Year controls,
  scaled calendar row heights and wrapping FilledButton Clear/Cancel/Apply keep
  inputs/errors/actions reachable without downscaling or new breakpoints.
  The Search owner also coordinates its picker TapRegion with the real shared-menu
  controllers. Menu row selection and a menu-consumed outside pointer event cannot
  cascade into picker dismissal, even when the menu closes before TapRegion's
  handler runs. The same-event guard is transient, not another draft/value owner.
- Walking Speed is a labelled field with wrapping adjacent controls/units, not a
  `FittedBox.scaleDown`. Numeric parsing/normalisation and route timing remain at
  their existing owners. Opacity retains integer entry and invalid-blur reversion;
  visible labels and accessible names include overlay context. Peak Info uses
  **Elevation / Elevation:** and signed integer input, preserving metres/data.
- Route-name input/mode controls disable during current Save. The notifier rejects
  captured name/mode callbacks before rebuild; existing Save duplicate protection
  remains authoritative. Focused name edits are not overwritten by provider
  projection updates. No persistence ownership, database model/generated files,
  routing foundation, native window configuration or platform scope changed.

## Automated evidence

- `map_field_alignment_test.dart`: invalid blank/non-numeric/0/10000 Year cases,
  partial typing, Enter/blur timing, 1/9999 boundaries, independent errors/recovery,
  unchanged calendars/dates and Apply eligibility, dismissal/reopen; actual Month
  immediate Enter, directional/pointer selection, Escape/Ctrl+C/back without picker
  cascade, and consumed first outside clicks retaining the picker;
  1280 × 960 / larger 2× custom light/dark wrapping/scrolling and retained invalid
  drafts; current/stale selection/focus guards and raw-query select-all.
- `map_screen_peak_search_test.dart`: routed Cmd+F open/repeat/select-all, raw-query
  debounce preservation, menu/picker/modal/drawer/Save exclusions and no replay,
  complete region values/canonical IDs; existing parser/category/pagination/date
  and selection regressions remain in place.
- Route sheet regression invokes captured name/mode callbacks after the current
  Save lock begins, before rebuild, and verifies unchanged draft/no replay.
  Overlay regression checks semantic/visible labels, valid integer commit and
  blank/non-numeric/−1/101 reversion on actual focus traversal. Existing Peak Info
  widget/robot assertions now use the approved Elevation terminology. Existing
  route panel tests preserve timing, validation, keyboard adjustment and semantic
  foreground/cursor checks.
- No new parser or date-qualified domain logic was introduced; earlier parser,
  category, routing and overlay TDD seams remain intact. Tests use existing controlled
  repositories/providers/preferences/clock/platform fixtures, not user data/services.

## Commands and outcomes

- Final `flutter analyze`: **passed, no issues**.
- Final combined focused run: **passed, 284 tests (2:34)**, covering all affected
  field/Search/Peak Info/route-panel/route-sheet/overlay widgets, existing Search,
  Peak Info, basemap, route-info, route-edit and drop-marker robot journeys, route
  state, Map search service and the date-query parser.
- Focused Search/field/Peak Info/route-panel run: **passed, 103 tests**.
- Focused route-sheet/overlay run: **passed, 46 tests**.
- Existing Search, Peak Info, basemap and route-info robot journeys, route state,
  search service and date parser: passed in the regression run; that attempted
  command also named a nonexistent provider-test path and initially exposed an
  overlay test's touch-versus-focus-loss assumption. Neither failed command is
  counted as a complete passing verification run. The corrected overlay test uses
  actual Tab focus traversal, not an unfocusing assumption about tapping a heading.
- `TZ=Australia/Hobart flutter test --reporter expanded`: **passed, 2,863 tests,
  7 inherited skips, zero failures (17:28)** on the final production implementation.
  Inherited Dashboard height/reachability skips are not counted as a layout Pass.
  The run also reports existing non-fatal off-target gesture warnings in Peak List
  mini-map, peak-visibility, Tile Cache and route-edit journeys; passing assertions
  do not establish delivery of those warned-about gestures.

Initial iterations caught missing theme padding in isolated hosts, superseded
Height/compact-trigger assertions, and the old ancestor-cursor test depending on
the removed downscaling wrapper. These were corrected and rerun; failed attempts
are not passing evidence. The field cursor retains normal editable text behaviour.
A stronger Month pointer regression then exposed TapRegion closing the picker
both on a menu-row click and after an already-consumed outside event. The final
menu-controller/same-event guard passes both cases. Two earlier in-progress full
runs were deliberately interrupted as coverage/production fixes were added; their
interruption output is not final suite evidence. One combined focused attempt hit
the command's 120-second harness timeout (268 tests had passed) and is likewise
not counted as complete. The later 284-test run above completed successfully.
The inherited route-edit robot emitted a non-fatal off-target map-drag warning;
its assertions passed, but the warning itself is not proof of a delivered gesture.

## Native evidence and limits

`test/harness/verify_map_fields.dart` renders isolated production Search/calendar,
Peak Info and Route Info widgets. It uses System Events keyboard and CoreGraphics
pointer input, never app startup, network, credentials, Mapping volumes or a Store.
It checks supported content sizes, default/custom light/dark themes, 1×/2× text,
invalid Year/Apply/menu ownership, unsaved Peak draft theme retention and Walking
Speed validation. A separate `MAP_FIELDS_RESIZE_ONLY=true` probe exercises real
macOS content resizing with an open menu and raw query/theme preservation.

Initial native matrix: **16 configurations passed**, at **1280 × 960 / 1600 × 1000**,
default/custom light/dark and **1×/2×** text. OS pointer/keyboard exercised Year
validation, immediate Month Enter, Apply with invalid navigation text, Peak editing,
draft retention through a theme change and Walking Speed validation. This run
predated the stronger Month pointer-selection/outside-click regression, so it is
not claimed as evidence for that corrected path. The final native rerun adds both
pointer cases. Its first attempt passed all eight 1280 × 960 configurations, then
failed to reopen Month by pointer in the first 1600 × 1000 configuration. The
runner reported no product framework error, but this incomplete attempt is **not
a native Pass**; the later diagnostic rerun below supersedes it for acceptance.
A second attempt passed 15 configurations, then failed at the same reopen step
in the final larger/custom-dark/2× configuration. Neither incomplete matrix
establishes an all-configuration Pass. The diagnostic runner now observes actual
native pointer-down delivery and coordinates and allows the window-foreground
transition to complete before injection; it does not retry or silently skip an
unsuccessful click. Production code is unchanged by this diagnostic refinement.

**Final native matrix: passed, all 16 configurations**, using
`flutter run -d macos -t test/harness/verify_map_fields.dart`. The diagnostic runner
observed delivery of each OS pointer-down at the expected content coordinates,
with no hidden retry/skip. All four themes at both sizes and scales passed actual
pointer Month selection and the consumed outside-click path as well as Year,
immediate Enter, Apply, Peak draft/theme retention and Walking Speed validation.
This final clean run produced no framework errors and completed fixture cleanup.
The foreground-settle refinement and observed delivery resolve the verification
gate; the two earlier incomplete attempts are retained as runner/input uncertainty,
not silently attributed to a proven product defect or counted as passing matrices.

Initial actual native resize probe: **passed**, at **2× text**, through macOS content
**1280 × 960 → 1600 × 1000 → 1280 × 960**, opening Group before each resize,
alternating default light/custom dark themes, retaining raw Search input and
cleaning any remaining menu without commit. This preceded the picker-specific
pointer fix. **Final native resize rerun also passed**, in the same complete run
as the 16 configurations above, on the final production implementation with
observed pointer delivery. It again verified actual content dimensions,
open-menu cleanup/dismissal, raw query and theme retention with zero framework errors.

Routed Cmd+F and the remaining prompt/overlay/route
callers are covered deterministically; isolated native renders are not a production
startup or whole-Map native navigation acceptance. No attributed human visual
review, template parity, whole-app compliance or inherited Dashboard layout Pass
is claimed. Native full-screen and Spec 0066's Time layout gate remain outside this item.
Native builds report the existing upstream ObjectBox Swift Package Manager fallback
warning; the isolated fixture does not open an ObjectBox Store. Its explicit process
exit produces Flutter's expected `Lost connection to device` teardown message.
