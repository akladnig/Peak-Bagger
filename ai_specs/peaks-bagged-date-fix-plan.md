## Overview

Fix `PeaksBagged.date` derivation from UTC `startDateTime`; use Australia/Eastern offset, then persist date-only UTC.

**Spec**: bug report only

## Context

- **Structure**: layer-first (`lib/models`, `lib/services`, `test/services`)
- **State management**: n/a
- **Reference implementations**: `./lib/services/peaks_bagged_repository.dart`, `./lib/services/gpx_importer.dart`, `./test/services/peaks_bagged_repository_test.dart`
- **Assumptions/Gaps**: `startDateTime` present for imported tracks; keep legacy fallback if absent

## Plan

### Phase 1: Sydney date derivation

- **Goal**: derive bagged date from UTC `startDateTime` using AEST/AEDT rules
- [x] `./lib/services/peaks_bagged_repository.dart` - derive `PeaksBagged.date` from `track.startDateTime`; explicit Australia/Eastern offset; store UTC midnight of the resulting date; keep fallback for missing `startDateTime`
- [x] `./test/services/peaks_bagged_repository_test.dart` - TDD: winter UTC start -> next-day AEST date; summer UTC start -> next-day AEDT date; null `startDateTime` fallback; duplicate collapse still preserves derived date
- [x] Verify: `flutter test test/services/peaks_bagged_repository_test.dart && flutter analyze`

## Risks / Out of scope

- **Risks**: DST boundary mistakes; existing stored rows only change after rebuild/sync
- **Out of scope**: importer `trackDate` normalization; schema changes; UI formatting updates
