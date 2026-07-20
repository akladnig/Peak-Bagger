---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the new map FAB become the only source of truth for main-map peak visibility and clustering?

Recommended Answer:
- Yes.
- The new FAB is the sole main-map control for this behavior.
- Its cycle is exactly: `Show Peak Clusters` -> `Show Peaks` -> `Hide Peaks` -> `Show Peak Clusters`.
- The default map state on entry is `Show Peak Clusters`.
- The old Settings switch should no longer control main-map peak rendering.

Answer: agreed. remove the settings switch "Show Map Peak Clusters"

Decision: The main map uses one `Peak visibility mode` FAB as the sole source of truth for peak visibility and clustering, with default state `Show Peak Clusters`, and the old `Show Map Peak Clusters` settings switch is removed.

Reason: This resolves the existing conflict between a map-local control and a separate persisted settings switch.

### L2

Status: current

Question: When the new peak FAB is in `Hide Peaks`, and the user later selects a peak list from `Select Peak List`, should that selection automatically switch the peak FAB back to its default visible state?

Recommended Answer:
- Yes.
- Selecting any peak list while peaks are hidden automatically changes the peak FAB state to `Show Peak Clusters`.
- `Hide Peaks` immediately clears all selected peak-list buttons.
- While `Hide Peaks` is active, no peak marker rendering, clustering, hover hit-testing, or peak-list-driven peak processing runs.
- `Show Peaks` and `Show Peak Clusters` both allow normal peak-list selection behavior; they differ only in whether clustering is off or on.

Answer: agreed

Decision: Selecting a peak list while peaks are hidden automatically switches the map back to `Show Peak Clusters`; `Hide Peaks` clears live peak-list selection UI and suppresses main-map peak rendering and processing while active.

Negative Requirements:
- Do not keep rendering peaks or clusters while `Hide Peaks` is active.
- Do not keep live peak-list buttons selected while `Hide Peaks` is active.

### L3

Status: current

Question: For the new FAB's user-facing copy, should the canonical label use singular `Peak` or plural `Peaks`?

Recommended Answer:
- Use plural `Peaks` everywhere for this control.
- Tooltip and semantics cycle exactly as the next action the button will perform:
  - `Show Peak Clusters`
  - `Show Peaks`
  - `Hide Peaks`
- Keep the drawer FAB tooltip and semantics as `Select Peak List`.
- No persistent text label is shown on either FAB; these strings are tooltip and accessibility labels only.

Answer: agreed

Decision: Use plural `Peaks` for the three-state control, with exact tooltip and semantics strings `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`, while keeping the separate drawer control labeled `Select Peak List`.

### L4

Status: current

Question: Should the `Hide Peaks` icon use a custom slashed landscape asset rather than a stock Material icon?

Recommended Answer:
- Yes.
- `Hide Peaks` uses a custom icon built from `Icons.landscape` with a visible diagonal slash overlay.
- Keep the slash thickness and color aligned with the current FAB icon color.
- Do not substitute a different stock Material icon such as `visibility_off`; the hidden state should still read visually as a peak-specific control.

Answer: agreed. save the custom icon as an svg in assets/svg

Decision: `Hide Peaks` uses a custom slashed landscape SVG asset saved under `assets/svg` instead of a stock Material hidden-state icon.

Reason: The hidden-state icon must still read as a peak-specific control rather than a generic visibility toggle.

### L5

Status: current

Question: When `Hide Peaks` is chosen, should it clear only the live on-screen selection, or also erase the remembered selection state used when the map is reopened or the visible region changes?

Recommended Answer:
- Clear the live selection immediately.
- App-bar peak-list chips become unselected.
- Drawer peak-list selections become unselected.
- Keep the existing remembered per-region selection behavior unchanged behind the scenes.
- `Hide Peaks` is not persisted across map reopen.
- A fresh map entry starts in `Show Peak Clusters` and then uses the app's normal remembered peak-list selection behavior.

Answer: agreed

Decision: `Hide Peaks` clears only the live peak-list selection UI, preserves remembered per-region selection state behind the scenes, is not persisted across map reopen, and a fresh map entry starts in `Show Peak Clusters` before normal remembered-selection behavior applies.

### L6

Status: current

Question: When `Hide Peaks` clears the live peak-list selection, should the map summary keep using the existing `None` chip, or should it show no chip at all?

Recommended Answer:
- Keep the existing `None` chip.
- `Hide Peaks` clears the selected peak-list buttons, and the app-bar summary shows `None`.
- Do not add a new special hidden-only chip or blank summary state just for this feature.
- When the user selects a peak list again, the summary returns to the normal selected-list state and the peak visibility mode switches to `Show Peak Clusters`.

Answer: agreed

Decision: When `Hide Peaks` clears live peak-list selection, the map app-bar summary continues to show the existing `None` chip.

### L7

Status: current

Question: Should the existing low-zoom hide rule remain in force for all `Peak visibility mode` states?

Recommended Answer:
- Yes.
- Preserve the existing low-zoom hide rule.
- `Show Peak Clusters` and `Show Peaks` only affect rendering at or above the current peak minimum zoom.
- Below that zoom, no peaks or clusters render regardless of the selected peak visibility mode.
- The FAB tooltip, semantics, and icon still cycle normally while zoomed out; the mode just takes effect once the map is zoomed in enough.

Answer: agreed

Decision: The existing `MapConstants.peakMinZoom` hide rule remains unchanged for all peak visibility modes.
