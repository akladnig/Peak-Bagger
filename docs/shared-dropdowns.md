# Shared selection-only dropdowns

`lib/widgets/shared_dropdown.dart` owns presentation, focus, scrolling and menu
lifetime. `lib/theme.dart` owns `SharedDropdownStyle`, field decoration and circular
icon-action states. Callers still own typed values, drafts, validation, operation
locks and persistence. This is a local component, with no starter-app dependency.

```dart
SharedDropdown<String>(
  label: 'Source of truth',
  value: sourceOfTruth,
  choices: const [
    SharedDropdownChoice(value: 'OSM', label: 'OSM'),
    SharedDropdownChoice(value: 'Manual', label: 'Manual'),
  ],
  enabled: !locked,
  isInteractionAllowed: () => !currentLock,
  errorText: fieldError,
  onSelected: updateDraft,
)
```

- Default: content-sized labelled field and label-only rows. Keep meaningful labels;
  no field tooltip or Search icon is added. Values/labels/errors wrap at constrained
  widths; width accounts for all options and is stable across selection changes.
- Independently configure `trigger: SharedDropdownTrigger.iconOnly` (with `icon`)
  and `rows: SharedDropdownRows.iconAndLabel` (with decorative choice icons). Icon
  triggers retain the action `label`, selected-value semantics and desktop tooltip.
  Configuration is not a user preference. Both variants share the same menus.
- For a nullable **Any**, use `SharedDropdown<T?>` and an actual null-valued choice.
  `hasSelection: false` means no committed selection, unlike committed null. Supply
  `hint` for an absent value. Retained unavailable choices can be disabled but
  checked; never replace their typed value just to make a menu selectable.
- An option may supply `groupLabel` / `groupKey` for a non-selectable heading
  immediately before it. Headings are not synthetic typed choices: they have no
  checkmark or keyboard target, so nullable Any and disabled retained selections
  keep their identities. Peak List Difficulty uses this to retain region grouping.
- Pass `enabled` for rendering **and** an `isInteractionAllowed` closure reading the
  current authoritative lock. Activation and commit reread it before rebuilding;
  widget flags alone do not reject same-frame stale callbacks. Options changing,
  an unavailable owner, disabled/removed anchor or resize can dismiss without a
  commit. Presentation never writes or replays a rejected action.
- External `focusNode` and `controller` remain caller-owned; keep their identities
  stable for the anchor lifetime. Internal focus/scroll resources are disposed by
  the component. A choice-less required labelled field can receive programmatic
  validation focus but cannot be activated; mutation-disabled fields cannot focus.
- Menus open without a keyboard target. Down/j and Up/k skip disabled choices and
  wrap relative to the committed choice; Enter before navigation closes unchanged,
  including after mere pointer hover. Pointer activation selects directly. The
  first outside gesture only dismisses. Escape/Ctrl+C/back close only this menu;
  Cmd+C remains ordinary copy and background Cmd+F cannot steal menu focus.
- Card integrations can supply `onOpened`, `onClosed`, `restoreFocus: false`,
  `skipTraversal: true`, a focus node and a menu controller. `onClosed` distinguishes
  `unchanged`, `selected`, `tabForward`, `tabBackward` and `unavailable`, so the card
  can restore its own inspection/focus reason or continue whole-card traversal.
  Default field integration restores eligible invoker focus; Tab continues normal
  traversal. Dashboard uses `lib/widgets/dashboard/dashboard_dropdown.dart` as a
  thin card-ownership adapter: Period uses labelled-field/label-only presentation,
  and Time's Chart type uses icon-only/icon-plus-label presentation. P/C, full-card
  Tab traversal and unchanged-versus-changed inspection return remain card-owned.
  Spec 0066 L23 now supplies Time's scrollable overflow policy while retaining
  card/grid geometry. P/C reveals its toolbar before opening a scrolled-off invoker.

## Complete field errors

Use `sharedFieldDecoration(labelText: ..., errorText: ...)` for common wrapping
errors. It supplies `SharedFieldError` as `InputDecoration.error`, with no line cap,
ellipsis or fixed height. It inherits the central decoration/error style. Editable
content caps stay separate. The shared Admin builder's consumers use this helper;
validation timing and existing read-only/five-line presentation are unchanged.

## Verification

Use only **My Seed Colour (`#7E47EB`) in dark mode** (`MyTheme.dark`) for widget,
native and visual verification. Do not repeat checks with light or custom-seed
themes; keep distinct input, error, variant, scale, resize and draft-retention
checks. The app profile's 2026-10-21 amendment supersedes older theme matrices;
dated verification records retain their historical scope/counts.

Widget coverage: `test/widget/shared_dropdown{,_rendering}_test.dart`, existing
shared-field tests and affected Admin selector/form/browser/shell/robot regressions.
The isolated native runner is
`flutter run -d macos -t test/harness/verify_shared_dropdown.dart`; it needs macOS
Accessibility/Automation permission for System Events. It uses controlled fixture
values, no production startup, network, credentials, Mapping volumes or Store.
Native pointer injection uses CoreGraphics through the installed Xcode Swift tool;
`--dart-define=DROPDOWN_NATIVE_POINTER_ONLY=true` reruns only the four pointer
combinations without repeating the keyboard matrix. This is fixture configuration,
not an application preference.
`--dart-define=DROPDOWN_NATIVE_RESIZE_ONLY=true` isolates the real macOS
content-resize/open-menu/draft/theme checks for all four combinations at 2× text.

For the production Dashboard caller adapter, run
`flutter run -d macos -t test/harness/verify_dashboard_dropdowns.dart`.
This isolated fixture uses the real Time/summary menus, a controlled Track/date,
in-memory Time preference storage and card focus ownership. It exercises OS keyboard
and pointer input, unchanged Enter, dismissal, preference timing and open-menu resize
at 1280 × 960 / 1600 × 1000 content sizes and 1× / 1.5× text in My Seed Colour/dark.
It excludes the inherited Time header/chart-height reachability gate and does not
establish whole-Dashboard layout or human visual acceptance.

The later Time height/reachability probe uses the actual Dashboard grid:
`flutter run -d macos -t test/harness/verify_time_card_layout.dart`.
It covers long summaries, all chart types, actual 1280 × 960 / 1600 × 1000 content
sizes and 1× / 1.5× / 2× text. Native wheel and Page Up/Down scroll Time content;
P/C reveals its controls and directional inspection reveals its reserved plot.
See `ai_specs/peak-lists/0066-time-dashboard-card/implementation-layout-verification.md`
for execution results, the resolved L23 scope and the separate human-review limit.

See Spec 0069's `implementation-01-verification.md` for actual command outcomes and
the automated/native/human-evidence distinction. No template-parity or inherited
Dashboard Time layout acceptance is implied.
