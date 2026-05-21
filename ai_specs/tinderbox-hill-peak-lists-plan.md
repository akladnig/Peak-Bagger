## Overview

Tinderbox Hill peak-list regression.
Negative `osmId` stays valid end-to-end; trace the drop, then lock it with regression coverage.

**Spec**: `n/a` (bug report)

## Context

- **Structure**: layer-first (`lib/services`, `lib/screens`, `lib/widgets`, `test/...`)
- **State management**: Riverpod + ObjectBox repos
- **Reference implementations**: `lib/services/peaks_bagged_repository.dart`, `lib/services/year_to_date_summary_service.dart`, `lib/services/peaks_bagged_summary_service.dart`, `lib/services/peak_refresh_service.dart`, `lib/screens/peak_lists_screen.dart`, `test/services/peaks_bagged_repository_test.dart`, `test/services/year_to_date_summary_service_test.dart`, `test/services/peaks_bagged_summary_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`
- **Assumptions/Gaps**: negative `osmId` was being dropped from GPX-derived bagged data and summary counts; full-suite failures remain unrelated to this fix

## Plan

### Phase 1: Data path proof

- **Goal**: prove negative `osmId` survives storage/import/refresh
- [x] `test/services/peaks_bagged_repository_test.dart` - `TDD:` negative-id peak derives into bagged rows; zero still excluded
- [x] `lib/services/peaks_bagged_repository.dart` - keep negative peak ids in derived bagged rows
- [x] `test/services/year_to_date_summary_service_test.dart` - `TDD:` negative-id peaks count in year-to-date totals
- [x] `lib/services/year_to_date_summary_service.dart` - count negative peak ids as valid climbs
- [x] `test/services/peaks_bagged_summary_service_test.dart` - `TDD:` negative-id peaks count in summary series
- [x] `lib/services/peaks_bagged_summary_service.dart` - count negative peak ids as valid peaks
- [x] `lib/services/peak_refresh_service.dart` - keep negative ids eligible in synthetic match path
- [x] Verify: `flutter analyze` && `flutter test test/services/peaks_bagged_repository_test.dart test/services/year_to_date_summary_service_test.dart test/services/peaks_bagged_summary_service_test.dart`

### Phase 2: Peak Lists UI proof

- **Goal**: Peak Lists renders negative-id peaks
- [x] `test/widget/peak_lists_screen_test.dart` - `TDD:` summary row and detail row keep a negative `osmId` peak visible after bagged refresh
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - `TDD:` Peak Lists journey shows Tinderbox Hill via existing robot harness
- [x] Verify: `flutter analyze` && `flutter test test/widget/peak_lists_screen_test.dart test/robot/peaks/peak_lists_journey_test.dart`

## Risks / Out of scope

- **Risks**: full `flutter test` still has unrelated failures in existing robot/widget suites; negative key names need stable assertions; source data may still omit Tinderbox Hill entirely
- **Out of scope**: changing OSM/HWC ID policy; unrelated Peak Lists UX
