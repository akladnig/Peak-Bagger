---
type: Work Item
title: macOS Map Metadata Filter Cursor And Clear Filters Polish
parent: ../spec.md
---

## What to build

Polish the macOS `Map metadata filter` interaction affordances as one vertical Flutter slice through the shared app-bar trigger, popup controls, styling anchor reuse, and deterministic widget coverage. On macOS, the interactive `Map metadata filter` controls named in the Spec must use the pointing-finger cursor, and `Clear filters` must remain labeled `Clear filters`, stay enabled while the popup is open, remain right-aligned, use the same filled high-emphasis treatment as the existing `Create Route` cancel control, and keep its current behavior of resetting `Rating`, `Difficulty`, and `Duration` to `Any` while keeping the popup open.

## Required context

- `lib/widgets/map_metadata_filter_popup.dart` currently owns the popup rows, dropdown triggers, and `Clear filters` control. Today `Clear filters` is left-aligned and uses the lower-emphasis text-button treatment that the Spec rejects.
- `lib/router.dart` and the shared map app-bar shell own the visible `Filter` trigger, while `lib/screens/map_screen.dart` owns popup presentation and backdrop behavior. Keep that navigation and presentation structure intact instead of introducing a second popup path.
- The visual source of truth for this slice is the existing `Create Route` cancel control treatment already used in map UI. Reuse that app-owned style anchor rather than default `TextButtonTheme` styling.
- Apply cursor changes only to interactive metadata-filter controls. Do not change cursor behavior for non-interactive metadata-filter labels, row containers, or the popup backdrop.
- `PopupShell` already provides the popup close button path used by the metadata-filter popup. Keep its existing interaction contract intact while aligning interactive affordances with the approved map metadata-filter behavior.
- Extend deterministic widget coverage in `test/widget/map_screen_metadata_filter_test.dart` and related map widget tests using existing stable keys such as `app-bar-map-filter-trigger`, `map-metadata-filter-rating-trigger`, `map-metadata-filter-difficulty-trigger`, `map-metadata-filter-duration-trigger`, and `map-metadata-filter-clear`. Follow existing test patterns that inspect `MouseRegion`, `InkWell`, and button widgets directly for cursor and presentation assertions.

## Acceptance criteria

- [ ] On macOS, the app-bar `Filter` trigger exposes the pointing-finger cursor.
- [ ] On macOS, the `Rating` dropdown trigger, `Difficulty` dropdown trigger, `Duration` dropdown trigger, and `Clear filters` action each expose the pointing-finger cursor.
- [ ] This hover bugfix does not change cursor behavior for non-interactive metadata-filter labels, row containers, or the popup backdrop.
- [ ] `Clear filters` keeps the visible label `Clear filters` and remains right-aligned within the popup.
- [ ] `Clear filters` uses the same filled, high-emphasis visual treatment as the existing `Create Route` cancel control.
- [ ] `Clear filters` stays enabled while the popup is open and preserves the existing interaction contract of resetting `Rating`, `Difficulty`, and `Duration` to `Any` while keeping the popup open.
- [ ] This slice does not change the canonical `Map metadata filter` terminology, add new controls, alter routes, or change popup backdrop behavior outside the hover and action-affordance polish defined in the Spec.
- [ ] Deterministic widget assertions verify the app-bar filter trigger, each dropdown trigger, and the `Clear filters` action expose the pointing-finger cursor on macOS.
- [ ] Deterministic widget assertions verify `Clear filters` is right-aligned and uses the intended filled high-emphasis treatment rather than the lower-emphasis default text-button styling.
- [ ] Automated coverage remains local and deterministic with existing widget seams, provider overrides, and stable selectors only.

## Covers

- User Stories: 3
- Requirements: 1, 7-10
- Technical Decisions: 3
- Testing Strategy: 3-4
- Interview Ledger: L1, L5-L6

## Blocked by
None - ready to start
