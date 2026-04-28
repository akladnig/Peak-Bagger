## Overview

Fix peak markers not updating after track import from map screen. Root cause: `importGpxFiles()` doesn't call `_refreshCorrelatedPeakIds()`.

## Context

- **Structure**: feature-first, providers in `lib/providers/`
- **State management**: Riverpod (flutter_riverpod ^3.2.1)
- **Bug location**: `lib/providers/map_provider.dart:602` (`importGpxFiles`)
- **Root cause**: `_refreshCorrelatedPeakIds()` not called after import, so `_correlatedPeakIds` set is stale
- **Reference**: `_importTracks()` at line 474 correctly calls `_refreshCorrelatedPeakIds()` at line 555

## Plan

### Phase 1: Fix peak marker update after import

- **Goal**: Call `_refreshCorrelatedPeakIds()` after `importGpxFiles()` completes

- [x] `lib/providers/map_provider.dart` - Add `_refreshCorrelatedPeakIds(allTracks)` after line 691 (`final allTracks = _gpxTrackRepository.getAllTracks()`) in `importGpxFiles()`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: None significant; follows existing pattern from `_importTracks()`
- **Out of scope**: Peak correlation logic changes, UI changes, new features
