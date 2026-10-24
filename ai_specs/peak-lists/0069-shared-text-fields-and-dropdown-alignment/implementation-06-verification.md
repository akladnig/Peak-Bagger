# Work Item 06 — Dashboard dropdown migration

## Delivery scope — 2026-10-23

The independent dropdown/state/input slice is implemented. **Work Item 06 remains
incomplete:** Spec 0066 L19–L22's Time header/chart-height reachability contract and
dependent enlarged-text checks remain unresolved. No global minimum, compact icon
trigger, passing independent test or native fixture resolves that gate.

## Implementation

- `DashboardDropdown` is now a thin adapter over `SharedDropdown`. Shared code owns
  field/icon/menu presentation, committed-relative navigation, dismissal, current
  eligibility checks, scrolling and overlay resources. The adapter retains P/C
  registration, card-only traversal and unchanged/changed menu-return reasons.
- All summary Period callers use the exact floating **Period** label and label-only
  rows. Removed the fixed 160px box and local outline/padding; width is measured by
  shared presentation and bounded by the existing one-row toolbar's constraints.
  The toolbar gives the field loose use of the remaining space rather than splitting
  it artificially with a Spacer. The existing shared presentation remains the
  owner of content measurement; extra toolbar space does not stretch the field.
- Time retains its current-type icon, **Chart type** action/tooltip, accessible
  current value and expanded state, with the exact three icon-plus-label choices.
  Opening, hover, immediate Enter and unchanged selection do not write preferences.
  Changed selection still dispatches to the existing Time-only Riverpod owner.
- Card/grid dimensions, breakpoints, summary/header policy, calendar semantics,
  other cards' binary modes, domain records and preference timing are unchanged.
  No schema, model, generated binding, native-window or foundation changes.
- Caller regressions cover actual pointer/keyboard gestures, shared menu metrics,
  stable Period sizing, selected semantics, no-op Enter after hover, inspection,
  Tab traversal, Escape/Ctrl+C/back, consumed outside gestures, same-frame route
  obscuring, removed anchors, stale callbacks, resize and draft retention.

## Verification

All theme-related checks use **My Seed Colour (`#7E47EB`) / dark** only.
Automated, native and human evidence are separate; no starter/template Pass is used.

- `flutter analyze` — passed, no issues.
- Native command: `flutter run -d macos -t test/harness/verify_dashboard_dropdowns.dart`
  — **passed all four size/scale configurations**, exercising both production menu
  variants in each. OS keyboard and CoreGraphics pointer input verified opening,
  unchanged Enter, changed selection, Escape/Ctrl+C, eligible card-focus return,
  consumed outside gestures, preference writes, retained draft and open-menu resize.
  No native framework errors; the documented upstream ObjectBox SwiftPM warning
  remains informational. Native logs end with the explicit overall PASS marker;
  Flutter's subsequent device-disconnection message is the fixture's normal exit.
- Focused Dashboard/provider/summary/shared-menu/robot run — 367 passed, one gated
  skip, one new test-fixture failure; its correction passed in an isolated rerun.
  All affected files subsequently passed in the final full suite below.
- **Final full suite: 2,877 passed, six existing skips, zero failures**, approximately
  9 minutes 45 seconds. Command:
  `caffeinate -i env TZ=Australia/Hobart flutter test --concurrency=4 --reporter expanded`.
  The inherited Time height/reachability skip remains; these results do not settle
  its feature contract or establish whole-Dashboard layout compliance.
- `dart format --output=none --set-exit-if-changed` on all 16 affected Dart files —
  passed, no changes. Staged whitespace checks and local delivery-record/Work Item
  link checks passed.
- Intermediate full suite — 2,876 passed, six inherited skips, one failure in the
  same new hover/Enter test. This is **not** the completion run.

### Findings corrected or retained during verification

- Initial caller checks exposed older plain `MaterialApp` fixtures with no shared
  icon-button theme. Affected Time/calendar/navigation/readiness fixtures now use
  `MyTheme.dark`; production styling was not duplicated or weakened to accommodate
  an unthemed fixture.
- The initial toolbar composition artificially split remaining width between a
  Flexible field and a Spacer, causing unnecessary value wrapping and an 18px
  overflow in the 1600 × 1000 preference fixture. Giving the content-sized anchor
  loose access to the remaining toolbar space fixes that introduced constraint bug.
  The original 1600 × 1000 preference and 320px calendar fixtures are retained;
  neither was enlarged to force a Pass. This does **not** fix or waive the inherited
  Time long-header/plot-height gate.
- The same-frame route-obscuring test disables Hero animations in its harness:
  unrelated existing binary FABs share default Hero tags. It still uses actual
  Navigator route changes and the current route guard, before anchor rebuild.
- The first broad regression run failed (323 passed, 44 failed, one inherited gated
  skip). Superseded full runs were stopped after the fixture and anchor corrections
  to avoid competing with corrected verification; none is claimed as a passing
  completion run.
- Two subsequent completion attempts were interrupted by server restarts, not test
  failures; their shutdown stream/finalization errors are not product regressions.
  The final suite ran in an independent process and completed with exit code zero.
- The new hover/Enter test initially left the mouse over a chart bucket exposed by
  overlay removal, generating a separate chart-hover input after dismissal. It now
  hovers a menu row, then parks outside the chart before Enter, isolating unchanged
  keyboard return/zero persistence from legitimate pointer inspection. Production
  chart hover behavior is unchanged. Its targeted rerun passed.

## Native surface and limitations

`test/harness/verify_dashboard_dropdowns.dart` uses the production Time/summary
callers, real card-focus adapter, synthetic Track/calendar inputs and in-memory
Time preference storage. It excludes production startup, Store, Mapping volumes,
credentials and network. It exercises OS-delivered P/C, directional selection,
unchanged Enter, Escape/Ctrl+C, pointer opening, consumed outside dismissal,
preference boundaries, retained draft and open-menu resizing at 1280 × 960 and
1600 × 1000 content sizes with 1× / 1.5× text.

The isolated card fixture is **not** whole-Dashboard geometry/reachability evidence.
The native window's existing launch/configuration is unchanged. No attributed human
visual review or screenshot-parity acceptance is claimed.

## Journey Verification

- Journey: Dashboard selects shared Period and Time menus, retaining Time preference
  on unchanged Enter.
- Verification command(s): `TZ=Australia/Hobart flutter test test/robot/dashboard/dashboard_journey_test.dart --reporter expanded`
- Required seams/selectors: existing routed Dashboard robot, in-memory repositories,
  synthetic Tracks, fixed Dashboard clock, preference mocks; scoped
  `summary-period-dropdown`, `time-chart-type-button`, `time-chart-type-line` and
  `shared-dropdown-menu` keys. Existing robot methods are extended, not replaced
  by a new framework.
- Result: `pass` — the extended journey passed in the final full suite as well as
  the earlier focused and intermediate full runs.
- Remaining risk: inherited Time long-header/plot-height reachability remains gated;
  widget journeys do not establish native input or human visual acceptance.

## Retained blockers

The existing Time long-summary height/reachability tests remain explicitly skipped.
No dependent height/layout work was attempted, no toolbar wrapping or downscaling
was introduced, and Spec 0066 Work Items 01–02 remain incomplete. Existing
destination-only shell keyboard accessibility limitations remain separately recorded
in Spec 0066; this migration neither widens that scope nor approves an exception.

## Commit scope

The user approved including the pre-existing dark-theme-only updates **only in
files touched by this migration**, so the commit retains the tested fixtures and
their required theme. Broader pre-existing theme/docs/harness work is excluded;
no parent Spec, Interview Ledger or unrelated workflow item is swept into this
commit. The selected Work Item and this delivery record retain partial completion.
