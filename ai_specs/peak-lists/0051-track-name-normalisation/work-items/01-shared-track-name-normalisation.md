---
type: Work Item
title: Shared Track-name normalisation
parent: ../spec.md
---

## What to build

Create one reusable Track-name normalisation boundary for the terminal, real-calendar-date rules in the Spec. It must be the sole date-matching implementation used by later import, comparison, and bulk-maintenance slices.

Apply the shared normaliser first in `lib/services/peak_info_content_resolver.dart`, then retain the existing display-only legacy fallback regex `r'\s*\(\d{1,2}/\d{1,2}/\d{4}\)$'`. The fallback remains non-validating, supports one- or two-digit day and month components, must not modify persisted data, and must not replace the shared normaliser.

## Required context

- `lib/services/gpx_importer.dart` derives names from GPX metadata and filename fallbacks; later Work Items must use this boundary rather than introducing another regex.
- `lib/services/peak_info_content_resolver.dart` contains the existing display-only legacy fallback.
- `test/services/peak_info_content_resolver_test.dart` is the existing fallback regression-test convention.
- `test/services/track_name_normalisation_test.dart` is the focused test path required by the Spec.

## Acceptance criteria

- [x] Start with a failing test for the pure normalisation behavior, then implement the minimum code needed to make it pass.
- [x] The shared normaliser removes only a terminal real calendar date formatted exactly `dd-MM-yyyy` or `dd/MM/yyyy`, optionally wrapped in parentheses. It accepts no separator or a separator containing any whitespace, hyphen, or underscore characters, permits trailing whitespace after the suffix, removes the separator with the suffix, and trims the resulting name.
- [x] `MtAnne10-03-2025` normalises to `MtAnne`, `Mt Anne (10-03-2025)   ` normalises to `Mt Anne`, and `Mt Anne 31-02-2025` remains unchanged.
- [x] The normaliser does not modify dates outside the end of a name, date-only names, invalid calendar dates, standalone years, embedded dates, or unsupported date shapes. It does not parse, overwrite, delete, compare against, or otherwise require `GpxTrack.trackDate`.
- [x] Unit tests cover every supported suffix form, including no separator, parenthesised dates, separator runs, trailing whitespace, leap-year validation, invalid calendar dates, no suffix, a date in the middle of a name, unsupported standalone-year input, and a date-only name. They verify `trackDate` is untouched and need not equal the suffix.
- [x] Peak-info display calls the shared normaliser before preserving the current legacy fallback behavior, without persisting display-only changes.
- [x] Run `flutter test` before implementing this first slice and report its full-suite result. Unrelated baseline failures do not block this work.

## Covers

- User Stories: 1-2
- Requirements: 4-5, 10
- Technical Decisions: 1-2, 6
- Testing Strategy: 1-2, 7
- Interview Ledger: L1-L2

## Blocked by

None - ready to start
