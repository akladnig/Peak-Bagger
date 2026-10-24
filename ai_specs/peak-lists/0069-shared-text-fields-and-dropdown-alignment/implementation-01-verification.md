# Work Item 01 verification

Date: 2026-10-21. Scope: [Work Item 01](work-items/01-shared-field-and-dropdown-presentation.md),
ADS-1.0 amended 2026-10-19, dropdown supplement 2026-10-20 and local presentation
supplement 2026-10-21; macOS / Desktop wide only.

## Implementation and ownership

- `SharedDropdown<T>` owns one reusable selection-only presentation with independently
  configured labelled-field/icon-only triggers and label-only/icon-plus-label rows.
  `SharedDropdownStyle` in the existing theme owns menu metrics, typography, tick
  and row-state roles. Labelled controls inherit the existing central field theme;
  icon controls reuse its central circular action style. No replacement theme,
  preference, starter checkout/package or platform expansion was introduced.
- Content sizing measures full options/hint and meaningful labels using the active
  fonts/scaler, preserves width across selection changes, and wraps under actual
  constraints. Open menus grow to content within safe/keyboard-aware bounds, prefer
  below when they fit, scroll, and clip full-width interactive row backgrounds to
  their shared rounded surface. Checks use effective seed/error/disabled roles,
  independently of the icon trigger's primary focus ring.
  Wrapped floating labels reserve measured space above the outline and clear of
  values; the decoration still inherits its central 12px content padding. Opening
  reveals the committed check without assigning an initial keyboard target.
- One menu focus owner handles next/previous skip/wrap, no-op Enter before navigation
  (including nullable/unavailable/empty-choice cases and pointer hover), directional
  targeting without persistence, direct pointer selection, isolated Escape/Ctrl+C,
  local-history back and consumed outside gestures. Background shortcuts cannot
  steal menu input; Cmd+C remains ordinary copy. Explicit close reasons and optional
  caller-owned focus/controller/traversal hooks support later Dashboard integration.
- `enabled` renders availability and `isInteractionAllowed` rereads current operation
  guards at activation/commit, including before rebuild. Disabled/unavailable/removed
  owners close without commit or forced focus; resources and local history are
  cleaned up. The caller retains its sole typed value/draft and all persistence.
- Admin Entity keeps its stable selector and existing canonical descriptor
  normalization/restoration, Schema/Data behavior and entity-selection/reset owner.
  Natural Feature Source of truth retains exact **OSM / Manual**, field policy,
  local draft, validation and current Save gate. No loaders/editors/writes were added.
  Search/Delete behavior remains item 02, Dashboard callers remain item 06.
- `sharedFieldDecoration` / `SharedFieldError` supplies complete soft-wrapped widget
  errors without a line cap or ellipsis. Existing shared Admin form-builder callers
  use it while preserving their validators/timing, read-only selectable displays,
  controller ownership and measured editable five-line caps. Errors stay outside
  editable content caps. Existing central field/mode/circular-action definitions
  remain unchanged; there is no second field-hover layer.
- [Usage and integration guide](../../../docs/shared-dropdowns.md).

## Automated verification surface

- `shared_dropdown_test.dart`: all four trigger/row configurations, real pointer/
  keyboard navigation and selection, nullable Any, unavailable/absent/choice-less
  inputs, immediate Enter with zero callbacks, skip/wrap, focus return, consumed
  outside gestures, dropdown-first Escape/Ctrl+C/back, background Cmd+F exclusion,
  explicit Tab outcomes, live locks/stale callbacks, route/anchor/resize cleanup,
  content-sized stable widths, supported-size enlarged-text wrapping and scrolling
  to the final long option. A long Admin error is measured as more than five rendered
  lines with no clipping, outside the editable cap and without changing its draft.
- `shared_dropdown_rendering_test.dart`: actual painted pixels for field idle,
  hover, focused hover, exit, expanded seed border, icon hover/expanded primary ring,
  error/disabled roles, menu idle/hover/press/directional-focus and full-width edge
  backgrounds in default/custom light/dark themes. Action/value/expanded and disabled
  selected semantics are verified without duplicate decorative names.
- Existing theme/shared-field tests retain the 14/24 tokens, exact once-composited
  Data hover, error/disabled border priority, live theme/rollback and retained draft.
  Existing Admin form/browser/shell and robot coverage regress policy, canonical
  descriptor recovery, validation, Save locks, read-only/five-line values and routes.
  An added Natural Feature test selects only the draft, starts Save and invokes a
  previously captured option before rebuilding: the choice cannot bypass Save.
- Historical Flutter-constructor assertions were replaced by public menu/value
  assertions. Lazy detail tests explicitly reveal content rather than assuming a
  fixed toolbar height. No product behavior was changed to satisfy those assumptions.

## Commands and outcomes

Completed: all 16 Work Item acceptance criteria are verified.

- `flutter analyze`: **pass, no issues**.
- `TZ=Australia/Hobart flutter test --reporter expanded`: **pass, 2,812 tests,
  7 skips, zero failures (23:16)**. Includes affected Admin widget/robot/provider/
  editor regressions, all existing shared-field consumers and unchanged Dashboard
  behavior. Inherited skips are not counted as a Dashboard Time layout Pass.
- Final shared behavior/painted-state tests: **30 passed** (1:58), including measured
  wrapped-label clearance and reopening with the committed check revealed.
- Additional final hint-width/no-op-Enter regression: **4 passed**, including retained
  long hints through nullable/unavailable selections.
- Resumed review: `flutter analyze` **passed with no issues**, including the added
  native resize runner. No production behaviour changed during this continuation.
- Continuation full-suite rerun: `TZ=Australia/Hobart flutter test --reporter expanded`
  **passed, 2,812 tests, 7 skips, zero failures (25:32)**. This independently confirms
  the implementation run above; its result does not supersede the recorded skip
  boundaries or claim completion of other Work Items.

Initial runs caught a numeric width inference error, MaterialColor-vs-Color test
equality, an intentionally lock-changed fixture needing a rebuild to become
interactive again, legacy dropdown-constructor/lazy-viewport assumptions, duplicate
or split icon action semantics, and test semantics-handle cleanup. These attempts
are not passing evidence. Superseded overlapping test/full-suite runs were explicitly
stopped; their shutdown stream/sink errors are interruptions, not product passes.
The later **153-test focused run passed**, including existing Admin robot journeys.
A subsequent stronger constrained-label test found native InputDecorator's floating
label could paint outside the target and overlap values; measured label clearance
now keeps complete labels and values separate, with a passing targeted regression.
The first native attempt completed 41 configurations before an OS event-timing
failure under concurrent load; the runner now waits for observed open/focus/target/
close state before sending dependent events instead of relying on short delays.
One superseded full run overlapped the final committed-check reveal change and
failed the strengthened reopen assertion against its previously compiled component;
it was stopped and restarted from stable sources. The final complete run above
passed, as did the final focused behavior/painted-state tests. No interrupted run
or superseded assertion failure is counted as a verification pass.
That runner then passed **all 64 native keyboard configurations**, but its final
direct-child accessibility-button lookup failed: Flutter's button was nested rather
than a direct window child. The final runner uses OS pointer clicks at measured
content-to-screen coordinates for all four trigger/row combinations instead.

## Native and human evidence

`test/harness/verify_shared_dropdown.dart` is an isolated macOS fixture using native
rendering, OS-delivered System Events keyboard input and CoreGraphics pointer events, without
production startup/services, network, credentials, Mapping volumes or a Store.
It attempts to restore its original native frame on completion/failure.

- Native keyboard: **64 configurations passed** at **1280 × 960 / 1600 × 1000**,
  default/custom light/dark, **1× / 2×** text, all four trigger/row combinations.
  Actual OS Return opens/takes menu focus, immediate Return closes with zero callbacks,
  Down skips the disabled choice without committing, subsequent Return selects,
  Escape/Ctrl+C close/restore focus, menus stay within the scene and drafts survive.
- Native pointer: **four combinations passed** using
  `flutter run -d macos -t test/harness/verify_shared_dropdown.dart --dart-define=DROPDOWN_NATIVE_POINTER_ONLY=true`.
  CoreGraphics OS pointer events activate each trigger and select nullable Any in its
  actual rendered menu, exactly once. System Events accessibility click attempts
  did not deliver the required pointer activation; those attempts are recorded above,
  not counted as pointer passes. The final successful pointer run also emitted a
  non-framework `Resize timed out` warning during teardown; its four input checks,
  framework-error check and fixture cleanup completed. No claim is made that this
  warning proves a production layout fault or a verified native frame restoration.
- Native resize: **four combinations passed** using
  `flutter run -d macos -t test/harness/verify_shared_dropdown.dart --dart-define=DROPDOWN_NATIVE_RESIZE_ONLY=true`.
  Each combination opens a menu before actual macOS content resizing through
  **1280 × 960 → 1600 × 1000 → 1280 × 960**, at **2× text**, alternating default
  light and custom dark themes. Values and unsaved drafts survive; any menu closed
  by metrics changes leaves no orphan and reopens normally. Menus remain within
  content bounds, and OS Escape restores eligible trigger focus without selection.
  The framework-error and fixture cleanup checks passed. The runner emitted the
  same non-framework `Resize timed out` warning during teardown; restoration of
  the original native frame is not claimed as verified.
- All native builds completed with the existing upstream ObjectBox Swift Package
  Manager fallback warning. Native rendering/input is separate from painted widget
  assertions and attributed human visual acceptance.

No attributed human visual review or template-parity Pass is claimed or required by
this compliance slice. The inherited Dashboard Time height/reachability gate is
untouched and is not waived or counted as a Pass.

## Boundaries

No entity annotations/model identities/generated files/schema migration,
ObjectBox/Riverpod/GoRouter replacement, domain validation/persistence boundary,
native window/launch/full-screen setting, dependency, breakpoint or compact/iOS
support is changed. Minimum supported app content remains 1280 × 960 and larger,
with default/enlarged text and actual wrapping/scrolling. Small constrained component
tests do not add supported app-window sizes. User-authored standard/profile and
other planning artifacts remain outside this implementation's intended commit.
