---
type: Work Item
title: Peak List Mini-Map Interactive Camera Controls And Commit Semantics
parent: ../spec.md
---

## What to build
Make the `peak list mini-map` on `PeakListsScreen` an interactive map surface that mirrors the current `main map` desktop control contract for pointer and camera input while preserving the existing click-only peak popup and cluster flows. Add `grab` on hover over pannable map space, `grabbing` from pointer-down until pointer-up during a drag attempt, grab-and-drag panning, the same click-vs-drag threshold contract used by the `main map`, the existing `main map` trackpad gesture contract including horizontal-only two-finger no-op handling, the existing `main map` mouse-wheel zoom behavior, and one history entry per accepted camera commit for drag-pan, trackpad zoom, mouse-wheel zoom burst, and cluster expansion when they change the camera. Preserve the exact rule that drag releases must not open a popup, change peak selection, expand a cluster, or apply other click side effects when pointer movement exceeds the accepted threshold.

## Required context
- `lib/screens/peak_lists_screen.dart` currently renders the `peak list mini-map` with `InteractiveFlag.none`, a `MouseRegion`, and click-only hit testing layered above `FlutterMap`. This slice should expand that existing vertical slice instead of replacing it with a separate mini-map architecture.
- `lib/screens/map_screen.dart` contains the current source contracts for `grab` / `grabbing`, pointer-down versus drag-release behavior, trackpad `PointerPanZoom*` handling, held-key camera commit timing, and mouse-wheel commit debouncing. Mirror those semantics rather than approximating them.
- Keep peak popup and cluster hit-testing flows layered around pan support, as required by the Spec, instead of moving to marker-owned gestures or adding visible controls.
- Reuse the local camera/history seam from Work Item 1 so drag-pan, trackpad zoom, mouse-wheel zoom burst, and cluster expansion commits can be asserted deterministically in widget and robot tests.
- Extend `test/widget/peak_lists_screen_test.dart` with fake/in-memory seams only. Reuse existing widget patterns already used in map tests for `PointerDeviceKind.trackpad`, mouse hover cursor assertions, and `PointerScrollEvent` dispatch.

## Acceptance criteria
- [ ] The `peak list mini-map` supports grab-and-drag panning with `main map`-style pointer affordances: `grab` on hover over pannable map space and `grabbing` from pointer-down until pointer-up during a drag attempt.
- [ ] Existing peak popup and cluster interactions remain click-only and continue to use the same click-vs-drag threshold contract as the `main map`.
- [ ] If pointer movement exceeds the accepted drag threshold, the release is treated as a pan and does not open a popup, change peak selection, expand a cluster, or otherwise apply click side effects.
- [ ] If pointer movement stays within the accepted drag threshold, existing click interactions remain available, including opening peak popups and expanding clusters.
- [ ] The `peak list mini-map` mirrors the current `main map` trackpad gesture contract, including the same supported zoom gestures and the same behavior for horizontal-only two-finger motion.
- [ ] The `peak list mini-map` mirrors the current `main map` mouse-wheel zoom behavior.
- [ ] Mini-map history records one entry per accepted camera commit, not one entry per intermediate animation or gesture frame: drag-pan records once on pointer-up if the camera changed, trackpad zoom records once on pan-zoom end if the camera changed, mouse-wheel zoom records once per completed wheel-driven zoom burst if the camera changed, and cluster expansion records once when its camera move completes.
- [ ] Adjacent duplicate camera states are not recorded.
- [ ] Hover, popup open or close, and peak selection do not create history entries unless they also change the camera.
- [ ] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies `grab` / `grabbing` cursor states, drag-pan camera movement, preserved click-only popup and cluster behavior, absence of popup or selection side effects on drag release, trackpad gesture behavior including horizontal-only no-op handling and end-of-gesture commits, mouse-wheel zoom burst commit behavior, and history commits from cluster expansion when the camera changes.

## Covers
- User Stories: 2, 3
- Requirements: 1, 4-7, 9-10
- Technical Decisions: 1, 3-5
- Testing Strategy: 2-5, 7
- Interview Ledger: L1, L3-L8

## Blocked by
- `01-peak-lists-screen-level-mini-map-keyboard-controls-and-local-camera-history.md`
