---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which mini-map surface is in scope for the requested zoom, pan, and history controls?

Recommended Answer:
- Treat `peak-lists-mini-map` as the only in-scope mini-map for this feature.
- Keep `latest-walk-mini-map` unchanged as a non-interactive preview/link card.
- Use `peak list mini-map` as the durable term for this feature work.
- Use `main map` to mean `MapScreen`.

Answer: agreed

Decision: The feature applies only to the `peak list mini-map` on `PeakListsScreen`. The dashboard `latest-walk-mini-map` remains unchanged.

### L2

Status: current

Question: When should the `peak list mini-map` capture navigation controls instead of the rest of `PeakListsScreen`?

Recommended Answer:
- While `PeakListsScreen` is the active route, the `peak list mini-map` owns its map-navigation keyboard shortcuts as screen-level shortcuts rather than focus-local ones.
- Those keyboard shortcuts act only on the `peak list mini-map` and are otherwise silent no-ops for the rest of `PeakListsScreen`.
- Ignore those keyboard shortcuts while an editable text control, dialog, modal surface, or other higher-priority input surface on `PeakListsScreen` is active.
- Trackpad and pointer gestures act on the mini-map only when the pointer is over it.
- While active, the mini-map matches `MapScreen` navigation controls for zoom and pan, plus `Cmd+[` back and `Cmd+]` forward camera-history shortcuts.

Answer: agreed

Decision: While `PeakListsScreen` is active, the `peak list mini-map` owns its keyboard map controls as screen-level shortcuts, except when a higher-priority input surface is active. Pointer and trackpad interactions stay local to the mini-map region.

### L3

Status: current

Question: What should count as mini-map history, and when should that history reset or clear its forward branch?

Recommended Answer:
- Record mini-map history entries from accepted camera changes.
- `Cmd+[` moves to the previous recorded camera state.
- `Cmd+]` moves to the next recorded camera state.
- After going back, any new camera change clears the forward history branch.
- Changing the selected peak list resets history and starts a new history from that list's initial fitted camera.

Answer: agreed

Decision: The `peak list mini-map` uses local camera history with browser-style branching semantics. A new camera change after moving backward clears forward history, and selecting a different peak list resets history to that list's initial fitted camera.

Examples:
- `A -> B -> C`, then `Cmd+[` to `B`, then a new move to `D` produces `A -> B -> D` with no forward entry to `C`.

### L4

Status: current

Question: What does "as per the main map" mean for the `peak list mini-map` control model?

Answer: the main map enables drag via grab and drag, so it is not just zoom

Decision: The `peak list mini-map` must match the `main map` control model rather than being limited to zoom. That includes keyboard zoom and pan parity, grab/grabbing drag-pan affordances, and the existing `main map` trackpad gesture contract.

Answer History:
- Initial recommendation narrowed trackpad parity to zoom-only behavior plus newly added pointer drag-pan.
- Final clarification: `main map` parity must include drag via grab-and-drag, not only zoom.

### L5

Status: current

Question: Should `Cmd+[` and `Cmd+]` replay only zoom-level changes, or any accepted camera change including drag-pan?

Recommended Answer:
- Treat this as camera history, not zoom-number history.
- Record accepted camera states after keyboard zoom, keyboard pan, drag-pan, trackpad zoom, and cluster expansion.
- Do not record hover, popup open/close, or peak selection unless they change the camera.

Answer: agreed

Decision: `Cmd+[` and `Cmd+]` operate on accepted mini-map camera states, including pan and zoom changes, not only numeric zoom changes.

### L6

Status: current

Question: When grab-and-drag panning is added, should peak selection and cluster expansion stay click-only, using the same drag-vs-click split as the `main map`?

Recommended Answer:
- Match `main map` pointer behavior.
- Show `grab` on hover over pannable mini-map space.
- Show `grabbing` from pointer-down until pointer-up during a drag attempt.
- Treat release as a click only when pointer movement stays within the existing small drag threshold.
- If that threshold is exceeded, treat it as a pan and do not open a peak popup, select a peak, expand a cluster, or clear/change popup state because of the release alone.

Answer: agreed

Decision: The `peak list mini-map` must preserve click-only peak and cluster actions while using the same small-movement threshold to distinguish click from pan. Drag releases must not trigger click side effects.

Negative Requirements:
- Do not open a peak popup on drag release.
- Do not change peak selection on drag release.
- Do not expand a cluster on drag release.

### L7

Status: current

Question: For continuous mini-map interactions, when should the `peak list mini-map` create a history entry?

Recommended Answer:
- Create one history entry per completed continuous interaction, not per intermediate frame.
- Drag-pan records once on pointer-up if the camera changed.
- Trackpad zoom records once on pan-zoom end if the camera changed.
- Held-key pan records once when scrolling stops.
- Discrete keyboard zoom records once per keydown.
- Cluster expansion records once when the camera move completes.
- Do not add duplicate adjacent entries when center and zoom are effectively unchanged.

Answer: agreed

Decision: History granularity must follow accepted camera commits, not every in-motion frame.

### L8

Status: current

Question: What should happen when `Cmd+[` or `Cmd+]` is used on `PeakListsScreen` but there is no previous or next camera state for the `peak list mini-map`?

Recommended Answer:
- Keep these as keyboard-only shortcuts with no new visible buttons.
- If there is no previous history entry, `Cmd+[` is a silent no-op.
- If there is no next history entry, `Cmd+]` is a silent no-op.
- Leave current screen input state unchanged after the no-op.
- Do not show a toast, dialog, snackbar, or error state.

Answer: agreed

Decision: Missing previous/next history states are silent no-ops that leave current screen input state unchanged and add no new visible history UI.
