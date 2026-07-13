---
type: Work Item
title: Peak Lists Recent-Ascent Summary Links And Mini-Map Selection
parent: ../spec.md
---

## What to build

Update the Peak Lists recent-ascent summary sentence so each peak name named in the "most recent ascent" sentence is rendered as an individually tappable link while commas, spaces, and `and` remain plain text. Activating a peak-name link must stay on the Peak Lists screen, open that exact peak's existing anchored mini-map popup, and set that peak as the selected peak for the existing blue selected-peak circle without opening the peak edit/view dialog or navigating away. In the same slice, remove the Peak Lists amber-marker flow by ensuring this screen does not render or persist the amber selected-location marker for these interactions and by ensuring the Peak Lists mini-map popup does not show the `Drop Marker` action.

## Required context

- `lib/screens/peak_lists_screen.dart` owns the Peak Lists summary sentence, selected-peak state, mini-map popup state, selected-location marker rendering, and the Peak Lists-specific `PeakInfoPopupCard` wiring.
- `lib/screens/map_screen_panels.dart` currently exposes the popup `Drop Marker` affordance when `onDropMarker` is provided. Preserve the shared popup behavior outside Peak Lists while removing that action from the Peak Lists context.
- Keep the existing anchored mini-map popup and blue selected-peak circle behavior rather than introducing a new dialog, popup, or marker type.
- Extend `test/widget/peak_lists_screen_test.dart` and reuse existing stable `Key` conventions there for any new deterministic summary-link assertions.

## Acceptance criteria

- [x] The Peak Lists details summary renders each peak name named in the "most recent ascent" sentence as its own enabled tap target, while commas, spaces, and `and` remain visible plain text and are not tappable.
- [x] Tapping a recent-ascent peak name on Peak Lists opens that exact peak's existing anchored mini-map popup on the same screen and sets that same peak as the selected peak for the blue selected-peak circle.
- [x] Tapping a recent-ascent peak name on Peak Lists does not open the peak edit/view dialog and does not navigate away from Peak Lists.
- [x] The Peak Lists mini-map keeps the existing blue selected-peak circle behavior for the currently selected peak, including selections made from summary links.
- [x] The Peak Lists screen does not render the amber selected-location marker for this flow, and Peak Lists summary-link or popup interactions do not create or persist an amber selected-location marker from that screen.
- [x] The Peak Lists mini-map popup does not show the `Drop Marker` action in this context.
- [x] Enabled recent-ascent summary links use the pointing-finger cursor, and any new deterministic summary-link targets added for widget coverage use stable selectors.
- [x] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies summary peak-name links, popup opening for the tapped peak, blue selected-peak circle updates from summary selection, absence of the amber selected-location marker, absence of the `Drop Marker` action in the Peak Lists popup, and the click cursor for enabled summary links.

## Covers

- User Stories: 1
- Requirements: 1-5, 10
- Technical Decisions: 1, 4
- Testing Strategy: 1, 5
- Interview Ledger: L1-L3, L6

## Blocked by

None - ready to start
