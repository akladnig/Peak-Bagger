---
type: Spec
title: Peak List Mini-Map Camera Controls And History
---

## Problem

The `peak list mini-map` on `PeakListsScreen` is currently rendered as a non-interactive preview with popup and cluster hit-testing layered on top, while the `main map` already supports richer desktop camera controls. Users cannot zoom or pan the `peak list mini-map` with the same keyboard and pointer model they already use on `MapScreen`, and there is no local camera-history shortcut for stepping backward and forward through prior mini-map views. The request is scoped to the `peak list mini-map`; the dashboard `latest-walk-mini-map` must remain unchanged. [L1] [L2] [L4] [L5]

## Proposed Outcome

The `peak list mini-map` becomes an interactive map surface that matches the `main map` control model closely enough for desktop use: screen-level keyboard zoom and pan shortcuts while `PeakListsScreen` is active, grab-and-drag panning, the existing `main map` trackpad and mouse-wheel zoom contracts, and screen-level `Cmd+[` / `Cmd+]` camera-history navigation that targets only the mini-map. Existing peak popup and cluster interactions remain available as click-only actions, and missing history states stay silent no-ops without adding new visible controls. [L2] [L3] [L4] [L5] [L6] [L7] [L8]

## User Stories

1. As a Peak Lists user, I can use the same map-navigation keyboard controls as the `main map` anywhere on `PeakListsScreen`, unless a text field, dialog, or other higher-priority input surface is active. [L1] [L2] [L4]
2. As a desktop user, I can pan the `peak list mini-map` with grab-and-drag while still using existing click interactions for peak popups and cluster expansion. [L4] [L6]
3. As a user exploring a peak list's geography, I can use `Cmd+[` and `Cmd+]` to move backward and forward through prior mini-map camera states, including views reached by pan or zoom. [L3] [L5] [L7] [L8]

## Requirements

1. This feature applies only to the `peak list mini-map` on `PeakListsScreen`. The dashboard `latest-walk-mini-map` must remain a non-interactive preview/link surface. [L1]
2. While `PeakListsScreen` is the active route, the `peak list mini-map` must own its map-navigation keyboard shortcuts as screen-level shortcuts rather than focus-local ones. These shortcuts act only on the `peak list mini-map`, are otherwise silent no-ops for the rest of `PeakListsScreen`, and must be ignored while an editable text control, dialog, modal surface, or other higher-priority input surface on `PeakListsScreen` is active. Pointer and trackpad interactions remain local to the mini-map region. [L2]
3. The `peak list mini-map` must reuse the current `MapScreen` keyboard zoom and pan shortcuts rather than introducing mini-map-specific mappings. This includes `-` / `_` for zoom out, arrow keys plus `H` / `J` / `K` / `L` in a case-insensitive way for pan, and any existing alternate punctuation or numpad variants already supported on `MapScreen`. [L2] [L4]
4. The `peak list mini-map` must support grab-and-drag panning with `main map`-style pointer affordances: `grab` on hover over pannable map space and `grabbing` from pointer-down until pointer-up during a drag attempt. [L4] [L6]
5. The `peak list mini-map` must preserve click-only peak and cluster interactions using the same click-vs-drag threshold contract as the `main map`. If pointer movement exceeds that threshold, the release must be treated as a pan and must not open a popup, change peak selection, expand a cluster, or otherwise apply click side effects. If movement stays within that threshold, existing click interactions remain available. [L6]
6. The `peak list mini-map` must mirror the current `main map` trackpad gesture contract instead of inventing a mini-map-specific one. This includes the same supported zoom gestures and the same behavior for horizontal-only two-finger motion. [L4]
7. The `peak list mini-map` must mirror the current `main map` mouse-wheel zoom behavior. If wheel input changes the camera, it must create one history entry per completed wheel-driven zoom burst. [L4] [L5] [L7]
8. While `PeakListsScreen` is the active route and no higher-priority input surface is active, `Cmd+[` must move to the previous recorded mini-map camera state and `Cmd+]` must move to the next recorded mini-map camera state. These shortcuts are screen-level shortcuts that target only the `peak list mini-map` and must not introduce new visible buttons or menu-only controls for this feature. [L2] [L5] [L8]
9. Mini-map history must be camera history, not zoom-number history. Accepted history-producing moves include keyboard zoom, keyboard pan, grab-and-drag pan, trackpad zoom, mouse-wheel zoom, and cluster expansion when they change the camera. Hover, popup open/close, and peak selection must not create history entries unless they also change the camera. [L3] [L5]
10. History must record one entry per accepted camera commit, not one entry per intermediate animation or gesture frame. Drag-pan records once on pointer-up if the camera changed, trackpad zoom records once on pan-zoom end if the camera changed, mouse-wheel zoom records once per completed wheel-driven zoom burst if the camera changed, held-key pan records once when scrolling stops, discrete keyboard zoom records once per keydown, and cluster expansion records once when its camera move completes. Adjacent duplicate camera states must not be recorded. [L5] [L7]
11. After the user moves backward in mini-map history, any new accepted camera change must clear the forward-history branch. [L3]
12. Changing the selected peak list must reset mini-map history and start a new history from that list's initial fitted camera state. [L3]
13. If there is no previous history entry for `Cmd+[`, the shortcut must be a silent no-op. If there is no next history entry for `Cmd+]`, the shortcut must be a silent no-op. In both cases, the shortcut must leave current screen input state unchanged and must not show a toast, dialog, snackbar, or other error surface. [L8]
14. The mini-map camera/history implementation must expose a deterministic local test seam for current committed camera state and history navigation state so widget and robot tests can verify replay, forward-history clearing, and reset behavior without relying only on pixel-position inference. [L5] [L7]

## Technical Decisions

1. Reuse the existing `MapScreen` control contracts as the source of truth for keyboard navigation, pointer affordances, drag-threshold behavior, trackpad gesture semantics, and mouse-wheel zoom behavior instead of defining a separate mini-map interaction language. [L2] [L4] [L6]
2. Keep camera history local to the `peak list mini-map` rather than promoting it to app-wide or shared `main map` state. Reset that local history when the selected peak list changes and the mini-map remounts. [L3] [L5]
3. Treat `Cmd+[` and `Cmd+]` as camera-history commands over accepted mini-map camera commits, with browser-style forward-branch clearing after a backward step followed by a new camera move. [L3] [L5] [L7] [L8]
4. Preserve existing peak popup and cluster hit-testing flows by layering pan support around the current click-only interactions, not by replacing those interactions with marker-level gestures or new controls. [L6]
5. Keep mini-map camera/history state local to `PeakListsScreen`, but expose a deterministic local test seam for committed camera and history-navigation state rather than relying only on inferred pixel movement in tests. [L5] [L7]

## Testing Strategy

1. Extend `test/widget/peak_lists_screen_test.dart` to cover screen-level shortcut ownership for the `peak list mini-map`, including keyboard zoom/pan behavior while `PeakListsScreen` is active, suppression while editable text or dialog input is active, and the guarantee that these shortcuts do not affect the rest of `PeakListsScreen`. [L1] [L2] [L4]
2. Add focused widget coverage for pointer affordances and click-vs-drag behavior on the `peak list mini-map`: `grab`/`grabbing` cursor states, drag-pan camera movement, preserved click-only popup and cluster behavior, and the absence of popup/selection/cluster side effects on drag release. [L4] [L6]
3. Add focused widget tests for `peak list mini-map` trackpad behavior using simulated `PointerDeviceKind.trackpad` gestures, reusing the same gesture expectations already proven on `MapScreen` for supported zoom motions, horizontal no-op handling, and end-of-gesture history commits. [L4] [L7]
4. Add focused widget tests for `peak list mini-map` mouse-wheel zoom behavior, reusing the same zoom and history-commit expectations already proven on `MapScreen` for completed wheel-driven zoom bursts. [L4] [L7]
5. Extend widget coverage for mini-map camera history to verify `Cmd+[` and `Cmd+]` replay accepted camera states from keyboard pan, keyboard zoom, drag-pan, trackpad zoom, mouse-wheel zoom, and cluster expansion; verify forward-history clearing after going backward and then making a new move; verify reset on selected peak-list change; and verify silent no-op behavior when previous/next history does not exist. [L3] [L5] [L7] [L8]
6. Extend `test/robot/peaks/peak_lists_journey_test.dart` and `test/robot/peaks/peak_lists_robot.dart` with at least one desktop-focused journey that exercises interactive mini-map navigation plus history replay using existing stable selectors such as `peak-lists-mini-map` and `peak-lists-mini-map-interaction-region`. Add new stable selectors only if the current keys are insufficient for deterministic history assertions through the agreed local test seam. [L2] [L5] [L7]
7. Prefer existing fake repository/provider seams already used by Peak Lists widget and robot tests. Automated coverage for this feature should stay deterministic and must not require real network calls, real map services, or secrets.

## Out of Scope

1. Changing the dashboard `latest-walk-mini-map` interaction model.
2. Changing `MapScreen`'s own control mappings, history behavior, or trackpad contract as part of this feature.
3. Adding visible history buttons, snackbars, or other new UI outside the keyboard shortcuts for `Cmd+[` and `Cmd+]`.
