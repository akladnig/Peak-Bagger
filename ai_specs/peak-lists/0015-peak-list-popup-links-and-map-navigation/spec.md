---
type: Spec
title: Peak List Popup Links And Map Navigation
---

## Problem

 The Peak Lists screen exposes a mini-map popup and a summary sentence, but recent-ascent peak names are plain text, the popup still offers a Peak Lists-specific `Drop Marker` path that conflicts with the desired no-amber-marker behavior, and popup navigation links to the main map are incomplete. Mouse users also do not get consistent pointing-finger cursor feedback across the relevant tappable links, sort headers, and primary Peak Lists actions. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## Proposed Outcome

 Peak Lists users can open a specific recent-ascent peak from the details summary, inspect it on the mini-map with the existing blue selected-peak circle and anchored popup, and jump from popup links to the main map with the expected destination behavior: peak-title links center the requested peak, while valid `My Ascents` links open the normal track info panel. The Peak Lists screen no longer exposes or renders the amber selected-location marker flow, and tappable links, sort headers, and primary Peak Lists FAB actions consistently advertise clickability with a pointing-finger cursor. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## User Stories

1. As a Peak Lists user, I can tap any recent-ascent peak name in the details summary and inspect that exact peak on the mini-map without leaving the screen. [L1] [L2]
2. As a user viewing a peak popup from Peak Lists, I can jump to the main map from the peak title or a valid `My Ascents` row and land on the corresponding centered peak or track info surface. [L4] [L5]
 3. As a mouse user, I can see a pointing-finger cursor on interactive links, sort headers, and primary Peak Lists actions so clickable UI is obvious before I press it. [L5] [L6] [L7]

## Requirements

1. The Peak Lists details summary must render each peak name named in the "most recent ascent" sentence as an individually tappable link. Commas, spaces, and `and` must remain plain text, not links. [L2]
2. Tapping a recent-ascent peak name in the summary must open that peak's existing anchored mini-map popup on the same Peak Lists screen and must set that peak as the selected peak for the blue selected-peak circle. It must not open the peak edit/view dialog or navigate away from Peak Lists. [L1] [L2]
3. The Peak Lists mini-map must keep the existing blue selected-peak circle behavior for the currently selected peak, including selections made from summary links and popup interactions. [L1]
4. The Peak Lists screen must not render the amber selected-location marker on the mini-map for this flow. Peak Lists-specific peak inspection and popup actions must not create or persist an amber selected-location marker from that screen. [L1] [L3]
5. The Peak Lists mini-map popup must not show the `Drop Marker` action. [L3]
6. The popup section currently labeled `My Ascents:` must keep that visible label and must be the canonical term for climbed-track links associated with the peak. The popup must not introduce a new visible `Available Tracks` label. [L4]
7. The popup peak title must be tappable. Activating it must navigate to `/map` and center on the same peak. It must not be required to auto-open the main map's peak info popup. [L4] [L5]
8. Each `My Ascents` row in the popup with a valid, resolvable climbed track must be tappable. Activating such a row must navigate to `/map`, show that track on the map, and open the normal track info panel for that track. If a popup ascent row cannot resolve to an openable track, it must remain visible as plain non-interactive text, must not use the pointing-finger cursor, and must not trigger navigation. [L4] [L5]
9. Navigation from Peak Lists popup links to the main map must remain compatible with the existing shell-based repeated navigation behavior so subsequent peak-title clicks keep centering the requested peak and subsequent ascent-row clicks keep opening the requested track info panel. [L5]
 10. Every enabled tappable link and relevant sort header touched by this feature must show a pointing-finger cursor. This includes at least the Peak Lists summary links, popup peak title, popup interactive `My Ascents` rows, links in the peak-list edit/details popup, Peak Lists summary-table sort headers, Peak Lists detail-table sort headers, and the Peak Lists `Add New Peak List` and `Import Peak List` FABs. Disabled or non-interactive text must not use the pointing-finger cursor. [L5] [L6] [L7]

## Technical Decisions

1. Reuse the existing anchored Peak Lists mini-map popup and existing blue selected-peak circle instead of introducing a new popup, dialog, or marker type for summary-link interactions. [L1] [L2]
2. Treat `My Ascents` as the canonical popup term for climbed-track links associated with a peak, reusing the existing glossary term and avoiding a visible `Available Tracks` label. [L4]
3. Reuse the established main-map navigation surfaces: peak links navigate to `/map` with the requested peak centered, while valid `My Ascents` links land on the normal track info panel. [L4] [L5]
4. Remove the Peak Lists-specific `Drop Marker` affordance from this popup context rather than allowing an action whose visible result is hidden on the same screen. [L3]

## Testing Strategy

1. Extend `test/widget/peak_lists_screen_test.dart` to cover summary peak-name links, blue selected-peak circle updates from summary selection, popup opening for the tapped peak, absence of the amber selected-location marker, and absence of the `Drop Marker` action in the Peak Lists popup. [L1] [L2] [L3]
2. Extend popup-focused widget coverage in `test/widget/peak_lists_screen_test.dart` and `test/widget/peak_list_peak_dialog_test.dart` to verify the popup peak title and valid `My Ascents` rows are interactive, use the pointing-finger cursor when enabled, unresolved ascent rows remain visible plain text without the click cursor, and the popup does not introduce an `Available Tracks` label. [L4] [L6]
3. Reuse existing shell/navigation regression coverage patterns from `test/widget/peak_list_peak_dialog_test.dart` and `test/widget/tasmap_map_screen_test.dart` to verify repeated peak-title navigation keeps centering the requested peak on `/map` and repeated ascent-row navigation keeps opening the correct track info panel. [L5]
 4. Extend Peak Lists cursor coverage in `test/widget/peak_lists_screen_test.dart` to verify both summary-table and detail-table sort headers use the pointing-finger cursor when interactive, alongside the existing link cursor assertions and the `Add New Peak List` and `Import Peak List` FAB cursor assertions. [L6] [L7]
5. Add stable selectors for any new summary-link or popup-link tap targets that need deterministic widget coverage; prefer existing popup, row, and panel keys where they already make the journey testable. [L2] [L4] [L5]

## Out of Scope

1. Changing the main map's own peak popup, track info panel, or `Drop Marker` behavior outside the Peak Lists screen context.
2. Renaming existing `My Ascents` terminology elsewhere in the app.
3. Changing peak-list sorting rules beyond cursor feedback for the existing sort headers.
