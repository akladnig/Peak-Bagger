---
type: Work Item
title: Add Search Popup Track Date-Range Picker
parent: ../spec.md
---

## What to build

Add the custom desktop Track date-range picker immediately to the right of the `MapSearchPopup` text input and wire it to the shared active range from Work Item 1. Deliver the complete picker interaction, calendar controls, focus behavior, semantics, result presentation, and widget coverage for picker-driven date-only and optional-name searches.

## Required context

- Read `GLOSSARY.md` and preserve its `Search popup`, `Track date`, and `PeaksBagged` terminology.
- Extend the existing desktop popup pattern in `lib/widgets/map_search_popup.dart`, `lib/widgets/map_search_results_list.dart`, `lib/core/widgets/popup_shell.dart`, and `lib/core/widgets/popup_keyboard_dismiss.dart`; do not change popup entry points, selection, or outer close behavior.
- Pass state and callbacks through the existing `MapScreen` `MapSearchPopup` construction and `MapNotifier` APIs. The map-level text-field autofocus must not override restored date-trigger focus after a range-state update.
- Extend `test/widget/map_screen_peak_search_test.dart` using its desktop `1600 x 900` setup and `TestMapNotifier` seams. Preserve existing `Key`-based selectors and add stable keys for the date trigger, endpoint controls, calendar navigation, Apply, Cancel, Clear, and inline validation state.
- No narrow-screen, mobile, responsive, or text-scale-specific picker layout is required. Do not add dependencies to `pubspec.yaml`.

## Acceptance criteria

- [ ] A separate custom picker trigger is immediately to the right of the normal Search popup input. It opens and closes without invoking the enclosing Search popup close callback, initially displays the exact label `Any date`, and after Apply displays `d MMM yyyy` for one day or `d MMM yyyy - d MMM yyyy` for an inclusive range.
- [ ] The picker owns local start and end drafts, opens with copies of the active range or empty drafts, and only commits a valid draft range on Apply. Start-only is one calendar day; selecting or entering an end date with no start draft immediately copies it into the start draft; a reversed range disables Apply.
- [ ] Start and end each have synchronized editable fields and custom calendar-grid controls using the shared single-date grammar. Each calendar opens to its endpoint draft month, otherwise the corresponding active-range endpoint month, otherwise the month containing the injected `DateTime Function()` clock value; the clock defaults to `DateTime.now()`.
- [ ] Each calendar supports previous/next month controls and month/year navigation for Dart `DateTime` years 1 through 9999 without changing drafts. A control changes only its corresponding endpoint draft, except an end-date entry with no start draft also copies that date into the start draft.
- [ ] Apply commits valid drafts, refreshes results, closes the picker, and clears any typed date expression so the normal text field can hold an optional name query. Clear immediately removes the committed shared range, empties both drafts, restores text-only search, and leaves the picker open.
- [ ] Cancel, Escape, outside click, and the top-right Close button discard drafts, preserve an existing committed range, close the picker, and restore focus to the date trigger. While open, the picker consumes Escape before the enclosing Search popup can dismiss; clicks in its trigger or surface are not outside clicks, while all other Search popup clicks are. None of these picker close paths invokes the Search popup close callback.
- [ ] Picker fields and calendar controls are keyboard-accessible and expose semantic labels. The implementation disposes controllers and transient popup state when the enclosing Search popup is dismissed.
- [ ] An active range counts as an executed search in `MapSearchResultsList`: an empty range-qualified result uses the existing `No results found` presentation, never stale results or the text-length helper. Range-qualified results support load-more with an empty or one-character optional name query.
- [ ] Widget tests cover the right-side trigger; exact `Any date`, single-day, and inclusive-range labels; synchronized field/calendar changes; endpoint-specific calendar updates; month navigation; injected-clock fallback; historical date selection; start-only, end-first, two-endpoint Apply, reversed-range disablement, Cancel/Escape/outside/Close preservation and focus restoration, Escape priority, and Clear remaining open.
- [ ] Widget tests cover picker-driven date-only results containing an eligible Track and bagged Peak, minimum-length bypass, no stale results for unmatched ranges, existing no-results presentation for an empty date-only range, and load-more for date-only and one-character optional-name range queries.

## Covers

- User Stories: 1-2
- Requirements: 1-9, 15
- Technical Decisions: 1, 3, 6-7
- Testing Strategy: 4
- Interview Ledger: L1-L9, L12-L13

## Blocked by

- 01-track-date-query-search.md
