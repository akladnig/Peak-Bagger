---
type: Work Item
title: Peak Lists Screen-Level Mini-Map Keyboard Controls And Local Camera History
parent: ../spec.md
---

## What to build
Add screen-level keyboard ownership on `PeakListsScreen` for the `peak list mini-map` so the screen reuses the current `MapScreen` keyboard zoom and pan shortcuts and adds `Cmd+[` and `Cmd+]` mini-map camera-history navigation while `PeakListsScreen` is the active route. Keep these shortcuts targeted only at the `peak list mini-map`, make them silent no-ops for the rest of `PeakListsScreen`, ignore them while an editable text control, dialog, modal surface, or other higher-priority input surface is active, and keep mini-map camera/history state local to `PeakListsScreen` with a deterministic local test seam for committed camera state and history-navigation state. This slice must also reset history to the newly selected list's initial fitted camera state when the selected peak list changes, clear the forward-history branch after moving backward and then making a new accepted camera change, and preserve the exact silent no-op behavior when previous or next history does not exist.

## Required context
- `lib/screens/peak_lists_screen.dart` already owns the `peak list mini-map`, selected-peak state, popup state, list-selection updates, and current camera fitting on selected peak-list change. Keep the new camera/history state local here unless a very small helper is needed.
- `lib/screens/map_screen.dart` is the source of truth for the keyboard zoom and pan contracts that must be reused exactly, including `-` / `_`, arrow keys, `H` / `J` / `K` / `L`, and any existing alternate punctuation or numpad variants already supported there.
- Follow the current higher-priority input suppression model already used by `MapScreen` for editable text and active surfaces rather than inventing a `PeakListsScreen`-specific shortcut language.
- The deterministic local seam required by the Spec should let widget and robot tests assert committed camera state and previous/next history availability directly, without relying only on marker pixel movement.
- Extend `test/widget/peak_lists_screen_test.dart` and reuse existing fake repository/provider seams instead of adding real network, real map services, or secrets.

## Acceptance criteria
- [ ] While `PeakListsScreen` is the active route, the `peak list mini-map` owns screen-level keyboard shortcuts for the existing `MapScreen` zoom and pan mappings, and those shortcuts target only the `peak list mini-map` rather than the rest of `PeakListsScreen`.
- [ ] The `peak list mini-map` reuses the current `MapScreen` keyboard zoom and pan shortcut set exactly, including `-` / `_` for zoom out, arrow keys plus `H` / `J` / `K` / `L` in a case-insensitive way for pan, and any existing alternate punctuation or numpad variants already supported on `MapScreen`.
- [ ] While an editable text control, dialog, modal surface, or other higher-priority input surface on `PeakListsScreen` is active, these mini-map keyboard shortcuts are ignored except for any existing higher-priority surface behavior already owned by that surface.
- [ ] While `PeakListsScreen` is the active route and no higher-priority input surface is active, `Cmd+[` moves to the previous recorded `peak list mini-map` camera state and `Cmd+]` moves to the next recorded `peak list mini-map` camera state.
- [ ] If there is no previous history entry for `Cmd+[`, the shortcut is a silent no-op. If there is no next history entry for `Cmd+]`, the shortcut is a silent no-op. In both cases, current screen input state remains unchanged and no toast, dialog, snackbar, or other error surface appears.
- [ ] Mini-map history is local camera history, not zoom-number history. After moving backward in mini-map history, any new accepted camera change clears the forward-history branch.
- [ ] Changing the selected peak list resets mini-map history and starts a new history from that list's initial fitted camera state.
- [ ] The mini-map camera/history implementation exposes a deterministic local test seam for the current committed camera state and history navigation state so widget and robot tests can verify replay, forward-history clearing, and reset behavior without relying only on pixel-position inference.
- [ ] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies screen-level shortcut ownership, keyboard zoom and pan behavior while `PeakListsScreen` is active, suppression while editable text or dialog input is active, `Cmd+[` and `Cmd+]` replay behavior, forward-history clearing after going backward and making a new move, reset on selected peak-list change, and silent no-op behavior when previous or next history does not exist.

## Covers
- User Stories: 1, 3
- Requirements: 1-3, 8, 11-14
- Technical Decisions: 1-3, 5
- Testing Strategy: 1, 5
- Interview Ledger: L1-L3, L5, L7-L8

## Blocked by
None - ready to start
