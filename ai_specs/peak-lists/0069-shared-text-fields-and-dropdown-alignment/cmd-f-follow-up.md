# Cmd+F follow-up — 2026-10-22

The user's manual report confirmed a real usability failure after item 04's first
delivery. The earlier native modifier limitation was not sufficient evidence to
dismiss that report.

## Reproduction and correction

- New real routed-shell tests failed before the fix: Peak Lists rejected Cmd+F
  with sidebar focus; Map's branch-local `Shortcuts` did not receive it at all.
- A focused control's `ModalRoute` is not necessarily the destination route in an
  indexed-stack shell. The sidebar legitimately belongs to a parent route.
- `lib/core/search_shortcuts.dart` now checks active route hierarchy, including
  parent Navigators, instead of rejecting every differing focused-control route.
  Root dialogs remain excluded even if they do not request focus. Local history
  still excludes menus/drawers from Search shortcut activation.
- Map registers/disposes a hardware Search handler like the existing other
  surfaces, so sidebar focus does not prevent active Map Search. Peak Lists, Add
  New Peak and Admin reuse the same eligibility policy. Existing feature mutation
  locks, raw-query select-all, draft ownership and debounce semantics remain intact.
  Map dropdown callbacks use the separate local-history-permitted interaction
  check, not the stricter shortcut guard, so open-menu commits still work.
- No native window/menu/application change is retained.

## Verification

- New routed Peak Lists and Map sidebar regressions: failed before, passed after.
- Root dialog with `requestFocus: false` leaves underlying Search selection
  unchanged. Existing local Add dialog, dropdown, drawer and Save-lock exclusions
  pass. Admin's retained editor regression additionally exercises sidebar focus.
- Focused 10-file run: **273 passed**; additional Admin sidebar/draft check:
  **1 passed**. `flutter analyze`: **no issues**.
- Full suite: `TZ=Australia/Hobart flutter test --reporter expanded` — **2,833
  passed, 6 inherited skips**, exit 0 (10m 48s). The additional Admin sidebar
  assertion was also rerun separately and passed.
- Final strict native run: **all four configurations passed**, with no Flutter
  rendering errors. Command/F down/up delivery is logged, and eligibility reports
  `meta=true`, active route and no local-history owner. Add Search focus/select-all
  and repeated Cmd+F pass at 1280 × 960 / 1600 × 1000, each at 1× / 2× text,
  alongside the existing resize/menu/validation/import recovery checks.

## Native probe correction

AppKit tracing proved that Command was present in the OS event, but the fixture
injected only the generic Command flag. Flutter's engine tracks device-specific
left/right flags. The fixture now includes `NX_DEVICELCMDKEYMASK` (`0x00000008`,
from the macOS IOKit `IOLLEvent.h`) and real flags-changed events.

With that correction, the initial strict native matrix **passed all four
configurations**, including actual Command key events, Add Search focus/select-all
and repeated Cmd+F, at 1280 × 960 / 1600 × 1000 with 1× / 2× text. The former
skip-Find probe option is removed. A subsequent native run failed to receive any
Command/F events; foreground activation before launching the Swift injector was
not sufficient under concurrent verification. The fixture now activates and
verifies its own process **inside the injector, after Swift compilation**, directly
before posting keys. With that correction the final strict run passed:

```sh
flutter run -d macos -t test/harness/verify_peak_list_fields.dart \
  --dart-define=PEAK_LIST_NATIVE_TRACE_KEYS=true
```

This separates two fixture issues (device modifier flags and lost foreground)
from the independently reproduced and corrected application sidebar-focus bug.
The final native result verifies the actual Add dialog; the real shell's Map,
Peak Lists and Admin routing and modal guards are verified by widget regressions.
No human visual acceptance or whole-app runtime compliance is inferred.

### Journey Verification
- Journey: Search from the real shell sidebar without losing query/editor context
- Verification command(s): `flutter test test/widget/peak_lists_screen_test.dart test/widget/map_screen_peak_search_test.dart test/widget/objectbox_admin_shell_test.dart`
- Required seams/selectors: existing routed `App`, in-memory repository/provider
  overrides, `shell-destination-{1,2,3}-focus` and existing Search/editor keys
- Result: `pass`
- Remaining risk: Native OS input is a separate verification surface; the fixtures
  do not verify user datasets or a production startup.

### Journey Verification
- Journey: Existing Map Search and Peak List add/import regressions
- Verification command(s): `flutter test test/robot/map/appbar_search_journey_test.dart test/robot/peaks/peak_lists_journey_test.dart`
- Required seams/selectors: existing robots, fake repositories/pickers and stable
  AppBar Search, popup, Add Peak, Points and submit keys
- Result: `pass`
- Remaining risk: These are deterministic widget regressions, not native menu or
  operating-system file-picker acceptance. No new journey framework is introduced.
