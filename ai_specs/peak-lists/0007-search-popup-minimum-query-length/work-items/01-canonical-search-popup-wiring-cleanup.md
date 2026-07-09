---
type: Work Item
title: Canonical Search Popup Wiring Cleanup
parent: ../spec.md
---

## What to build
Consolidate the map-screen search flow onto one canonical `Search popup` surface by routing the existing AppBar trigger, map Search FAB, and `Meta+F` keyboard shortcut through the same `MapSearchPopup` state and cleanup behavior, and remove obsolete parallel peak-only map-search plumbing from the map flow instead of keeping duplicate state or legacy popup UI in parallel.

## Required context
- `lib/providers/map_provider.dart` currently owns both the shared popup state (`searchPopup*`) and legacy peak-only state (`searchQuery`, `searchResults`, `showPeakSearch`) updates. This item should reduce duplicate map-flow paths without changing unrelated non-popup peak search behavior elsewhere.
- `lib/screens/map_screen.dart`, `lib/widgets/map_action_rail.dart`, and `lib/router.dart` contain the active entry-point and close/focus wiring for the popup surface and map keyboard shortcuts.
- `lib/screens/map_screen_panels.dart` still contains `MapPeakSearchPanel`, which is the legacy peak-only popup UI called out in the Spec notes as obsolete map-flow plumbing to remove or fully retire from this slice.
- Preserve canonical project terminology from `GLOSSARY.md`: use `Search popup` for the map screen's `MapSearchPopup` flow instead of `peak search` when updating user-facing tests and requirements traceability for this slice.
- Follow the existing deterministic widget-test seams in `test/widget/map_screen_peak_search_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/widget/map_screen_peak_info_test.dart`, including stable selectors such as `app-bar-search-trigger`, `search-peaks-fab`, `map-search-input`, and `map-search-close`.

## Acceptance criteria
- [x] The map screen exposes one canonical `Search popup` surface backed by `MapSearchPopup`, and the map flow no longer keeps a separate peak-only popup path, duplicate controller path, or parallel map-search UI in active use.
- [x] The existing map-screen search entry points remain available and all open the same shared `Search popup` state: the AppBar trigger, the map Search FAB, and the `Meta+F` keyboard shortcut.
- [x] Opening the `Search popup` from any supported entry point still applies the current popup initialization behavior, including an empty query, cleared results, default entity filter, current initial region selection behavior, ascending sort, and no grouping.
- [x] Closing the `Search popup` from any supported entry point still restores the current focus and transient cleanup behavior so map keyboard shortcuts recover cleanly after dismissal.
- [x] Opening the `Search popup` with `Meta+F` still focuses the popup search field, and closing the popup still restores map shortcut handling such as the existing `G` goto shortcut behavior.
- [x] Opening the map Search FAB while peak info is open continues to close the peak info popup and then show the shared `Search popup` rather than a separate peak-only surface.
- [x] Widget coverage proves the shared `Search popup` behavior remains consistent across the AppBar trigger, map Search FAB, and `Meta+F` keyboard shortcut, including close and focus-cleanup behavior.

## Covers
- User Stories: 3-4
- Requirements: 1-4, 12
- Technical Decisions: 1-2, 4-5
- Testing Strategy: 4-6
- Interview Ledger: L1-L2

## Blocked by
None - ready to start
