---
type: Work Item
title: Add Typed Track Date Search and Robot Journey
parent: ../spec.md
---

## What to build

Extend the normal `MapSearchPopup` input to use the shared Track date range for complete typed date/date-range expressions, retain raw text separately from parsed state and effective name query, show the exact invalid date-like feedback, and complete the desktop AppBar Search robot journey with deterministic date-qualified data.

## Required context

- Build on the parser and active-range criterion from `01-track-date-query-search.md` and the picker state and selectors from `02-search-popup-track-date-picker.md`; do not duplicate their parsing or date-search logic.
- Preserve the text-input debounce and existing text-only behavior in `lib/widgets/map_search_popup.dart`. The text field must display its raw value even when its effective name query is empty.
- Add widget coverage alongside `test/widget/map_screen_peak_search_test.dart` and robot methods/data to `test/robot/map/appbar_search_robot.dart`, then journey coverage in `test/robot/map/appbar_search_journey_test.dart`.
- Robot fixtures must use `GpxTrackRepository.test`, `PeakRepository.test`, `PeaksBaggedRepository.test`, and their in-memory storages. Do not use ObjectBox, network services, API keys, or external secrets.

## Acceptance criteria

- [ ] Entering a complete supported typed date or date range activates the same active range as the picker, retains its raw text for display, supplies an empty effective name query, updates the picker trigger label, refreshes results, and permits date-only search with the normal text field otherwise empty.
- [ ] Mixed name-and-date text such as `Bonnet 28 Jul 62` is not supported. A picker-selected active range plus ordinary name text is the supported combined-search path; while it remains active, any optional non-empty ordinary name query narrows Tracks by Track name and Peaks by Peak name.
- [ ] A date-like typed value that is partial, invalid, or cannot form a real supported date/range shows the exact inline message `Enter a valid date or date range`, returns no results and no candidates, and never falls back to failed name search. A non-date-like value, including `123 Peak`, remains a normal name query.
- [ ] Replacing a valid typed date/date-range expression with any non-valid expression immediately removes its typed-source active range. Clearing a typed expression removes only its typed-source active range; replacing it with ordinary non-date-like text makes that text the effective name query. Picker-originated ranges remain active while the text field is empty or has ordinary optional name text.
- [ ] Applying a picker range clears a typed date expression; picker Clear removes the shared active range immediately. Typed state, picker state, raw text, effective query, results, request invalidation, and text-field focus are cleaned up when the Search popup closes, with no persistence across sessions.
- [ ] Widget tests cover valid typed dates and ranges using an empty effective name query, all supported parser forms and separators through the input, raw-text and picker-label synchronization, rejection of mixed expressions, exact invalid copy, partial/invalid date-like values, `123 Peak`, typed-range clearing/replacement, picker-originated optional-name behavior, and no stale results for invalid typed input.
- [ ] Extend the existing desktop AppBar Search robot with stable selector-based actions and deterministic Tracks, Peaks, and `PeaksBagged` rows. Its journey tests cover picker-driven date-only selection of a matching Track and bagged Peak, plus typed single-date input and typed date-range input.
- [ ] The robot tests continue to exercise existing result selection behavior and use only the repository fakes and stable selectors required by the Search popup.

## Covers

- User Stories: 3-4
- Requirements: 1, 6, 10-15
- Technical Decisions: 1, 5-7
- Testing Strategy: 3-5
- Interview Ledger: L2-L3, L7-L8, L10-L13

## Blocked by

- 01-track-date-query-search.md
- 02-search-popup-track-date-picker.md
