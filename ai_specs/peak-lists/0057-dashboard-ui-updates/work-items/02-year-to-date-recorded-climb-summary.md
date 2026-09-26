---
type: Work Item
title: Year To Date Recorded-Climb Summary
parent: ../spec.md
---

## What to build

Make My Year to Date's `Peaks climbed` value count persisted, dated `PeaksBagged` associations in the selected local calendar year. Repeated recorded climbs of the same peak on separate walks count once per association. Extend the existing `YearToDateSummaryService` input boundary and Dashboard wiring to receive persisted `PeaksBagged` rows alongside tracks; do not add a network call, API key, background work, persistence setting, or data migration.

Preserve the existing local-year handling and `New peaks climbed` first-ever-climb calculation. Change the metric labels to exactly `Kilometers walked`, `Metres climbed`, `Total walks`, `Peaks climbed`, and `New peaks climbed`. Enabled My Year to Date previous/next controls use `SystemMouseCursors.click`; disabled controls retain the default cursor.

## Required context

- `lib/services/year_to_date_summary_service.dart` currently derives the distinct-peak total from `GpxTrack.peaks`; preserve the existing `newPeaksClimbed` logic while changing only the `peaksClimbed` source to persisted `PeaksBagged` rows.
- `lib/models/peaks_bagged.dart`, `lib/services/peaks_bagged_repository.dart`, `lib/providers/map_provider.dart`, and `lib/providers/peaks_bagged_repository_provider.dart` establish the existing persisted-row and Riverpod boundary; retain current provider ownership and lifecycle.
- `lib/screens/dashboard_screen.dart` passes Dashboard data into `lib/widgets/dashboard/year_to_date_card.dart`; the card owns its selected-year navigation, loading state, keys, and visible metric labels.
- Follow behavior-first TDD in `test/services/year_to_date_summary_service_test.dart`. Use the established widget and Dashboard harnesses in `test/widget/year_to_date_card_test.dart` and `test/widget/dashboard_screen_test.dart`; preserve existing keys and Dashboard robot seams.

## Acceptance criteria

- [x] Begin by extending `year_to_date_summary_service_test.dart` with persisted `PeaksBagged` rows: selected-year dated rows include repeated climbs of one peak on separate walks; other-year and missing-date rows do not contribute; `New peaks climbed` remains unchanged.
- [x] `YearToDateSummaryService.buildSummary` accepts persisted `PeaksBagged` rows alongside tracks and calculates `peaksClimbed` as the number of rows whose `PeaksBagged.date` falls in the selected local calendar year. It does not collapse associations by peak ID.
- [x] The Dashboard passes the existing persisted `PeaksBagged` rows through the established Riverpod/repository boundary to My Year to Date; tracks continue to supply kilometres, metres, total walks, and the existing `newPeaksClimbed` calculation.
- [x] My Year to Date displays exactly `Kilometers walked`, `Metres climbed`, `Total walks`, `Peaks climbed`, and `New peaks climbed`, and its corrected `Peaks climbed` value is shown for the selected year.
- [x] Enabled My Year to Date previous/next controls use `SystemMouseCursors.click`; disabled controls retain the default cursor. Existing navigation, loading state, tooltips, keyboard semantics, and error behavior are unchanged.
- [x] Focused service and widget tests cover the repeated-association total, unrelated years and missing dates, unchanged `New peaks climbed`, exact labels, and enabled versus disabled cursor behavior. Existing Dashboard robot journeys continue to pass without a new robot journey, external fake, or selector.
- [x] Run `flutter analyze`, the focused service/widget/robot tests, and `flutter test` before completion.

## Covers

- User Stories: 2-3
- Requirements: 3-4, 8 (My Year to Date controls), 9
- Technical Decisions: 2, 5
- Testing Strategy: 1, 3-6
- Interview Ledger: L1, L2, L4

## Blocked by

None - ready to start
