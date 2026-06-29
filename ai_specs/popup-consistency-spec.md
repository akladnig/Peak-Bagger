<goal>
Unify the app's popup surfaces so dialogs, transient cards, and helper-driven alerts read as one coherent UI system. The change should remove visual drift in padding, header treatment, and close affordances without changing the underlying flows, validation, or results.
</goal>

<background>
This is a Flutter app. Popup-like UI currently exists in three shapes:
- standard `AlertDialog` flows in `./lib/widgets/dialog_helpers.dart`, `./lib/widgets/peak_list_create_dialog.dart`, `./lib/widgets/peak_list_import_dialog.dart`, `./lib/screens/settings_screen.dart`, and `./lib/screens/map_screen_panels.dart`
- a custom `Dialog` + `Card` shell in `./lib/widgets/gpx_import_dialog.dart`
- multiple transient `Card` overlays in `./lib/screens/map_screen_panels.dart`

`./lib/widgets/peak_list_peak_dialog.dart` is a separate bespoke panel, but it should still match the shared popup visual language for close button treatment, padding, border radius, and background color.

Popup inventory in scope:

Transient overlays:
- `TrackRouteChooserPopup`
- `RouteTimingInfoDialog`
- `MapInfoPopupCard`
- `MapTapActionPopupCard`
- `FavouritesPopupCard`
- `PeakInfoPopupCard`
- `DriveEtaPopupCard`
- `RouteDraftMarkerDeletePopupCard`

Modal and panel popups:
- `GpxImportDialog`
- `PeakListCreateDialog`
- `PeakListImportDialog`
- `PeakListPeakDialog`
- `FavouriteNameDialog`
- `showDangerConfirmDialog`
- `showExportConflictDialog`
- `showSingleActionDialog`

Relevant files:
- `./lib/widgets/dialog_helpers.dart`
- `./lib/widgets/gpx_import_dialog.dart`
- `./lib/widgets/peak_list_create_dialog.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/core/constants.dart`

The implementation should prefer a reusable shared popup shell under `./lib/core/widgets/` over one-off local layouts so the reusable UI layer stays available for unrelated app work.
</background>

<user_flows>
Primary flow:
1. User opens a popup from a map interaction, peak-list action, import flow, or settings action.
2. User reads the popup, dismisses it, or completes the action.
3. The popup presents a consistent title/header area, predictable padding, and a clear close or confirm control.

Alternative flows:
- Confirmations: user cancels or confirms destructive actions from a modal dialog.
- Info popups: user reads transient information and closes it without changing state.
- Multi-step popups: user enters text, validates input, then submits or cancels.

Error flows:
- Validation failure: keep inline validation visible and do not dismiss the popup.
- Action failure: show the existing failure dialog paths and keep the original popup semantics.
- Popup out-of-bounds/size constraints: keep the content accessible through scrolling or clamping without changing the action result.
</user_flows>

<requirements>
**Functional:**
1. Create a reusable full popup shell for transient card-based overlays, with consistent outer padding, header spacing, title treatment, close-button treatment, and optional footer spacing.
2. Standardize icon-only close affordances on all transient overlays: compact close icon, zero padding, compact constraints, and a tooltip.
3. Keep `PeakListPeakDialog` visually aligned with the same popup language for close button treatment, padding, border radius, and background color, while preserving its bespoke draggable behavior.
4. Keep the current close buttons and their callbacks wired to the same dismiss behavior; do not change the underlying state transitions or navigation.
5. Add keyboard dismiss shortcuts to all dismissible popup surfaces: `Escape` and `Ctrl+C` on macOS must both close the popup by following the same dismiss path as the close button, including when a descendant input is focused.
6. Normalize shared dialog helpers so confirm-style dialogs use the same button hierarchy everywhere: secondary/cancel first, primary action last, and the primary action visually emphasized.
7. Remove ad-hoc visual drift in helper dialogs and confirm dialogs, including hover-driven button emphasis swaps in `showExportConflictDialog`.
8. If a popup is currently a transient overlay with no explicit close affordance, add one rather than relying only on parent toggles.
9. Preserve existing keys, result types, and validation messages.

**Error Handling:**
10. Existing failure and result dialogs must remain on the same code paths and continue to report the same messages.
11. Dismissal controls must remain disabled when the current flow already blocks exit during save/import work.
12. Non-dismissible confirm dialogs must stay non-dismissible.

**Edge Cases:**
13. Narrow viewports must not clip the close icon, title, or primary action.
14. Popups with long titles must ellipsize or wrap in the same way across the popup family rather than each widget choosing a different behavior.
15. Popups that can grow with content must still keep header and action areas visually stable.
16. Every transient overlay in scope must expose both an explicit close affordance and the shared keyboard dismissal behavior.

**Validation:**
17. Add widget tests for the shared popup chrome and at least one representative modal dialog helper.
18. Add widget tests for representative transient popup cards to verify consistent header padding, close affordance, keyboard dismissal, and action/footer spacing.
19. Add robot-driven journey coverage for at least one map popup and one dialog flow that exercise open, close, and confirm/cancel behavior using stable app-owned keys.
20. Keep coverage split as: widget tests for popup chrome and edge states, robot tests for critical open/close journeys, unit tests only where helper logic changes.
</requirements>

<boundaries>
Edge cases:
- Popups with only one action: still present an obvious dismissal path.
- Dismissible popups should close on `Escape` and `Ctrl+C` on macOS. `Ctrl+C` is an intentional dismiss shortcut here and should behave exactly like `Escape`.
- Large content blocks: use scrolling within the popup body, not ad-hoc resizing of the close button or title row.

Error scenarios:
- Import failure, picker failure, or destructive-action failure: preserve the existing failure dialogs and messages.
- Validation failure: keep the popup open and surface inline errors in place.
- Cancel during a blocked operation: keep the current disabled state until the operation completes or fails.

Limits:
- Do not redesign the app theme globally.
- Do not add a new design system; reuse Material widgets and the existing `UiConstants` where possible.
- Do not change business logic, persistence, or popup result payloads.
</boundaries>

<implementation>
Create `./lib/core/widgets/popup_shell.dart` as the shared full popup shell for transient popup-card header/padding/close-button layout.

Create a shared keyboard-dismiss primitive under `./lib/core/widgets/` for dismissible popup surfaces that are not using `popup_shell.dart`, so `Escape` and `Ctrl+C` follow the same close path for standard dialogs and bespoke panels.

Keep `GpxImportDialog` as a custom outer `Dialog` because it has viewport/measurement-specific layout behavior, but make it adopt the shared popup shell for its visible header/body/actions chrome where that does not break its measured scrolling behavior.

Update `./lib/widgets/peak_list_peak_dialog.dart` to consume the same visual tokens or shell values for close button treatment, padding, border radius, and background color, without changing its drag handling or saved-state behavior.

Keep shared numeric/style tokens such as border radius, padding, and close icon sizing in a new `PopupUIConstants` class in `./lib/core/constants.dart` rather than duplicating them inside the shell widget.
`UiConstants` remains the broader app-wide UI constants container, while `PopupUIConstants` owns popup-shell-specific tokens only.

Implementation track 1: transient overlays use the shared shell:
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`

Implementation track 2: Material dialogs keep `AlertDialog` structure but adopt shared action and keyboard rules:
- `./lib/widgets/dialog_helpers.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/widgets/peak_list_create_dialog.dart`
- `./lib/widgets/peak_list_import_dialog.dart`

Implementation track 2a: `GpxImportDialog` keeps its custom outer `Dialog` and measurement logic, but adopts shared shell chrome plus keyboard dismissal:
- `./lib/widgets/gpx_import_dialog.dart`

Implementation track 3: `PeakListPeakDialog` adopts shared visual tokens plus keyboard dismissal, without adopting the transient overlay shell:
- `./lib/widgets/peak_list_peak_dialog.dart`

Keep the custom popup behavior and placement logic intact in `./lib/screens/map_screen.dart`; only the chrome and dismiss affordances should change.

Avoid introducing more than one transient popup shell pattern. Where a popup already uses standard `AlertDialog`, keep Material structure unless the helper or action ordering is inconsistent.
</implementation>

<stages>
Phase 1: Define the popup standard
- Extract the shared popup chrome/helper.
- Add `PopupUIConstants` in `./lib/core/constants.dart` for popup tokens.
- Lock in the padding, header, title, and close-button rules.
- Verify the shared helper can represent both info popups and action popups.

Phase 2: Migrate the popup family
- Update the transient card popups to the shared chrome.
- Migrate `GpxImportDialog` to the shared popup shell chrome while preserving its custom outer `Dialog`, measured height calculation, and scroll behavior.
- Normalize confirm dialogs and any ad-hoc button ordering.
- Add explicit close affordances where the popup is otherwise dismiss-only.
- Wire `Escape` and `Ctrl+C` to the same dismiss action on all dismissible popup surfaces.
- Add the shared keyboard-dismiss wrapper/pattern to `AlertDialog`-based flows and `PeakListPeakDialog`.

Phase 3: Test and polish
- Add widget tests for the helper and representative popup variants.
- Add robot coverage for representative open/close and confirm/cancel journeys.
- Run targeted tests, then `flutter analyze`.
</stages>

<illustrations>
Desired:
- A map info popup, peak info popup, drive ETA popup, track chooser, and route-draft delete popup all share the same header rhythm and close icon treatment.
- Confirm dialogs always show cancel/secondary first and a clearly emphasized primary action last.

Avoid:
- One popup with a large default close button, another with a tiny icon, and another with no tooltip.
- Hovering over a confirm dialog changing which action is primary.
- One-off dialog padding values that do not match the rest of the popup family.
</illustrations>

<validation>
Use test-first implementation for the shared popup shell:
1. Write the smallest failing widget test for the shared header/close-button contract.
2. Add a failing widget test for one transient popup card.
3. Implement the helper and migrate one popup at a time.
4. Add the keyboard-dismiss regression tests for shell-based overlays, `GpxImportDialog`, `AlertDialog` flows, and `PeakListPeakDialog`.
5. Add the confirm-dialog helper regression tests after the visual contract is in place.

Testing seams:
- Keep popup content injectable through existing constructors and callbacks.
- Prefer stable `Key` selectors already present in the codebase; add only the keys needed for new shared chrome or new close buttons.
- Avoid timing-based assertions; use deterministic widget state and callback fakes.

Automated coverage outcomes:
- Logic/helper coverage: shared dialog helpers preserve return values and button ordering.
- UI behavior: shared popup shell renders consistent padding, title layout, close affordances, and keyboard dismissal.
- Critical journeys: at least one representative map popup, `GpxImportDialog`, and one representative modal dialog can be opened, dismissed, and completed through the new standard.

Robot coverage expectations:
- Use key-first selectors for the popup root, close icon, confirm button, and cancel button.
- Reuse representative keys such as `peak-info-popup-close`, `drive-eta-popup-close`, `track-route-chooser-close`, `route-draft-delete-popup-close`, `peak-list-create-button`, `peak-list-import-button`, and existing helper dialog keys.
- Cover one map overlay close journey and one confirmation-dialog journey; report any popup families intentionally left to widget-only coverage.

Recommended verification:
- `flutter test test/widget/...` for the popup-related widget suites
- `flutter test test/robot/...` for the representative journey coverage
- `flutter analyze`
</validation>

<done_when>
All popup surfaces reviewed in this spec follow one consistent visual language for padding, header treatment, and close affordances.
Shared helper dialogs use the same action hierarchy everywhere.
Representative widget and robot tests pass.
No popup behavior, validation, or result payload changes unexpectedly.
</done_when>
