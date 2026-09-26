---
type: Work Item
title: Recorded Climb And List Presentation
parent: ../spec.md
---

## What to build

Update the My Ascents, Latest Walk, and My Lists Dashboard surfaces without changing their navigation, table layout, sorting semantics, loading or empty states.

Use the existing `formatTrackDateShortMonth` output, including its `Unknown` fallback, for My Ascents row dates and Latest Walk's date summary only. Derive each My Ascents heading from its existing `MyAscentsYearSection.rows` as `<year> - <count> peaks climbed`, so undated `PeaksBagged` rows excluded from sections are not counted. Rename the My Lists percentage heading to exactly `Climbed %` without changing its data, order, or numeric alignment.

Use `SystemMouseCursors.click` for the enabled My Ascents sort button and enabled Latest Walk previous/next controls; disabled Latest Walk controls retain the default cursor.

## Required context

- `lib/core/date_formatters.dart` owns `formatTrackDateShortMonth`; do not add a parallel formatter.
- `lib/services/my_ascents_summary_service.dart` creates the grouped `MyAscentsYearSection.rows`; `lib/widgets/dashboard/my_ascents_card.dart` renders those sections and retains the existing sort key.
- `lib/services/latest_walk_summary.dart` and `lib/widgets/dashboard/latest_walk_card.dart` own Latest Walk's displayed date and previous/next controls.
- `lib/widgets/dashboard/my_lists_card.dart` owns the percentage heading and preserves its table contract.
- Extend the established focused tests in `test/services/my_ascents_summary_service_test.dart`, `test/services/latest_walk_summary_test.dart`, `test/widget/my_ascents_card_test.dart`, `test/widget/latest_walk_card_test.dart`, and `test/widget/my_lists_card_test.dart`. Keep the existing Dashboard robot keys and journeys; do not add selectors or a new robot journey.

## Acceptance criteria

- [x] My Ascents row dates use `formatTrackDateShortMonth`, including `Unknown` when the existing formatter receives an absent date; non-Dashboard track-information surfaces retain their current formatter.
- [x] Every rendered My Ascents section heading is exactly `<year> - <count> peaks climbed`, where `count` is `section.rows.length`; dated rows remain grouped and sorted as before, and undated `PeaksBagged` rows do not create or contribute to a heading.
- [x] Latest Walk's date summary uses `formatTrackDateShortMonth`, including its existing `Unknown` fallback.
- [x] The My Lists percentage column heading is exactly `Climbed %`; its data, order, and numeric alignment are unchanged.
- [x] The enabled My Ascents sort button and enabled Latest Walk previous/next controls use `SystemMouseCursors.click`; disabled Latest Walk controls retain the default cursor. Existing keyboard semantics and tooltips remain intact.
- [x] Focused service and widget tests assert the short-month dates, yearly heading counts matched to displayed rows, empty-state preservation, `Climbed %`, and enabled versus disabled cursor behavior. Existing Dashboard robot journeys continue to pass without new robot seams or selectors.
- [x] Run `flutter analyze`, the focused service/widget/robot tests, and `flutter test` before completion.

## Covers

- User Stories: 1-4
- Requirements: 1-2, 6, 8 (My Ascents and Latest Walk controls)
- Technical Decisions: 1, 3, 5
- Testing Strategy: 2-6
- Interview Ledger: L1, L2, L4

## Blocked by

None - ready to start
