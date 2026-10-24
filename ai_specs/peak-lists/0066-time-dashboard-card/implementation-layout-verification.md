# Time card height/reachability — L23 delivery

## Approved scope — 2026-10-24

The user selected: retain existing card/grid geometry, reserve a usable chart area,
and make overflowing Time content scrollable. This resolves L19's product decision,
not merely the global window minimum. L20–L22 and their earlier gated results remain
historical authorisations/evidence. ADS-1.0 and the Desktop wide/macOS-only profile
remain in force; runtime theme support is unchanged and verification uses only
My Seed Colour (`#7E47EB`) / dark.

## Delivered layout and ownership

- Time's header, one-row toolbar, full date range and plot share a single vertical
  `TimeCardViewport`. The Dashboard still owns fixed grid/card sizes, 4:3 aspect
  ratio, column thresholds, board scrolling, drag/reorder and card-only traversal.
  Other cards retain their layouts. The drag preview also constrains long Time
  summaries within its unchanged preview size, without scaling text or overflow.
- The plot fills remaining space when possible. Its minimum is measured from four
  legible text-height-plus-spacing intervals, using the active theme/TextScaler,
  plus the renderer's existing 20/28px plot insets. These insets now have shared
  names rather than duplicated literals. This is an implementation-derived metric,
  not a new approved window size, chart preference, maximum duration or breakpoint.
- A locally owned scroll controller and scrollbar provide pointer-wheel/trackpad
  access. Time Page Up / Page Down scroll content without changing calendar pages
  or adding Tab stops. Initial/directional keyboard inspection reveals the chart;
  P/C reveals the existing invoker before opening. Menu outcomes, inspection reasons,
  modified editing keys and full-order traversal remain owned by the existing card.
- Layout derives from constraints rather than copied mutable heights. Resizing,
  reordering, scrolling and menu opening do not save/reset calendar/type/draft state.
  Riverpod owns calendar/preference state as before; no schema, ObjectBox, network,
  credentials, routes, native-window or dropdown-typography changes are introduced.
  Presentation controllers are disposed with the owning viewport.

## Verification

- The original skipped long-duration test was enabled and failed before the fix,
  reproducing the insufficient-height paint failure. It is now a nine-case matrix:
  1280 × 960, 1600 × 1000 and 1920 × 1200 at 1× / 1.5× / 2× text. It uses a
  `123456d 23h 59m` total/average and verifies full text/no FittedBox, actual scrolling
  to the plot, non-overlapping axis labels, unchanged card size, one-row controls,
  full date range, long-header drag feedback and empty-state recovery.
- Focused Dashboard/Time/preference/readiness/calendar/navigation/robot regressions:
  **245 passed**. Additional keyboard coverage verifies overflow, Page Up/Down,
  P/C unchanged close, inspection reveal, Tab continuation, all three chart types,
  resize across the supported examples, reordering and retained page/type.
- Native probe: `flutter run -d macos -t test/harness/verify_time_card_layout.dart`.
  The real Dashboard grid uses synthetic Track/calendar data, in-memory repositories
  and preference storage; no production startup, Store, credentials, Mapping volumes
  or live tiles. Native OS wheel/key input checks minimum/larger actual content
  sizes, default/enlarged scales, all chart types, summary/toolbar/plot reachability,
  no-op menu return, retained state and no framework errors.
- `flutter analyze` — passed, no issues.
- Final full suite:
  `caffeinate -i env TZ=Australia/Hobart flutter test --concurrency=4 --reporter expanded`
  — **2,887 passed, five existing skips, zero failures**, approximately 12 minutes
  41 seconds including startup. The former Time layout skip is removed. One earlier
  full run was superseded while final drag-preview/axis-spacing coverage was added;
  it is not counted as completion evidence.
- Final native probe — **six size/scale combinations passed**, each exercising all
  three chart types: actual 1280 × 960 / 1600 × 1000 content at 1× / 1.5× / 2×.
  OS wheel, Page Up/Down, directional inspection and P/C menu return reached the
  header/controls/chart without changing calendar/type or outer card geometry.
  No framework errors. The fixture's explicit final PASS precedes its normal exit
  and Flutter device-disconnection message; no human visual acceptance is inferred.
- Nine affected Dart files passed format checks with no changes. Delivery links
  and staged whitespace checks are checked before commit.

Initial native fixture sizing assumed the requested outer window height was applied
unchanged. macOS constrained that first frame, giving the wrong title-bar adjustment.
The fixture now measures the actual native frame before requesting exact content
sizes; no production window setting was changed to make the check pass.

## Evidence limits

Widget paint/input, native rendering/input and human acceptance are separate.
No attributed human visual review, screenshot parity or whole-app accessibility
Pass is claimed. The destination-only F6/other-shell-actions limitation in Technical
Decision 11 remains outside this layout scope. Native full-screen is still a separate
non-blocking Pending choice; other features' unrelated thresholds are not resolved.

## Journey Verification

- Journey: existing routed Dashboard journeys, including shared Period / Time menu
  selection and unchanged Enter retaining the saved Time preference.
- Verification command(s): `TZ=Australia/Hobart flutter test test/robot/dashboard`
  (included in the focused regression command and final full suite).
- Required seams/selectors: existing DashboardRobot, controlled clock, synthetic
  Tracks, preference mocks, in-memory repositories and existing scoped card/menu keys.
- Result: `pass`.
- Remaining risk: no new journey framework or human visual review; the existing
  separately documented shell-action accessibility limitation is unchanged.

## Completion

L23's Time overflow/reachability contract is implemented and verified. Spec 0066
Work Items 01–02 and Spec 0069 item 06 can close their inherited layout criteria.
Their previous delivery entries remain dated history, not ongoing blockers or
claims that the former failing layout passed. No unrelated whole-app alignment
gaps, deferred shortcut discovery or native full-screen choice is closed here.
