---
type: Work Item
title: Peak Lists Popup Links To Main Map
parent: ../spec.md
---

## What to build

Extend the Peak Lists mini-map popup so the popup peak title is tappable and each `My Ascents` row with a valid, resolvable climbed track is tappable, while keeping the visible section label exactly `My Ascents:` and not introducing a visible `Available Tracks` label. Activating the popup peak title must navigate to `/map` and center on the same peak without requiring the main map's peak info popup to auto-open. Activating a valid `My Ascents` row must navigate to `/map`, show that track on the map, and open the normal track info panel for that track. If a popup ascent row cannot resolve to an openable track, it must remain visible as plain non-interactive text and must not trigger navigation.

## Required context

- `lib/screens/map_screen_panels.dart` owns the popup header and `My Ascents:` presentation used by the shared peak info popup surface. Keep `My Ascents:` as the canonical visible term.
- `lib/screens/peak_lists_screen.dart` owns the Peak Lists mini-map popup wiring and must reuse the established shell-based navigation behavior when linking to `/map`.
- `lib/widgets/peak_list_peak_dialog.dart` already contains map-navigation and track-opening patterns for peak titles and ascent rows that can be reused for link behavior and unresolved-track handling expectations.
- Reuse existing navigation regression patterns from `test/widget/peak_list_peak_dialog_test.dart` and `test/widget/tasmap_map_screen_test.dart`, and add stable selectors only where the popup links are not already deterministic.

## Acceptance criteria

- [x] The Peak Lists mini-map popup keeps the visible section label `My Ascents:` and does not introduce a visible `Available Tracks` label.
- [x] The popup peak title is tappable, uses the pointing-finger cursor when enabled, and navigating from it goes to `/map` centered on the same peak without requiring the main map's peak info popup to auto-open.
- [x] Each popup `My Ascents` row with a valid, resolvable climbed track is tappable, uses the pointing-finger cursor when enabled, and navigating from it goes to `/map`, shows that track on the map, and opens the normal track info panel for that track.
- [x] Each popup ascent row that cannot resolve to an openable track remains visible as plain non-interactive text, does not use the pointing-finger cursor, and does not trigger navigation.
- [x] Navigation from Peak Lists popup links remains compatible with the existing shell-based repeated navigation behavior so repeated peak-title clicks keep centering the requested peak and repeated ascent-row clicks keep opening the requested track info panel.
- [x] Widget coverage in `test/widget/peak_lists_screen_test.dart` and `test/widget/peak_list_peak_dialog_test.dart` verifies interactive popup peak-title and valid `My Ascents` rows, unresolved ascent rows remaining plain text without the click cursor, and the continued absence of a visible `Available Tracks` label.
- [x] Regression coverage reuses existing shell or navigation patterns to verify repeated peak-title navigation keeps centering the requested peak on `/map` and repeated ascent-row navigation keeps opening the correct track info panel.

## Covers

- User Stories: 2, 3
- Requirements: 6-10
- Technical Decisions: 2-3
- Testing Strategy: 2, 3, 5
- Interview Ledger: L4-L6

## Blocked by

None - ready to start
