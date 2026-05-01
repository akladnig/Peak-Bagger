## Overview

Add confirmation dialogs to "Reset Map Data" and "Recalculate Track Statistics" in SettingsScreen, matching existing pattern from "Refresh Peak Data" and "Reset Track Data".

## Context

- **Structure**: feature-first, screens in `lib/screens/`
- **State management**: Riverpod (flutter_riverpod ^3.2.1)
- **Reference implementations**: `lib/screens/settings_screen.dart:208` (`_confirmRefreshPeakData`), `:289` (`_confirmResetTrackData`)
- **Dialog helper**: `package:peak_bagger/widgets/dialog_helpers.dart` → `showDangerConfirmDialog`
- **Note**: "Reset Track Data" already has confirmation dialog; only two actions need adding

## Plan

### Phase 1: Add confirmation dialogs

- **Goal**: Wrap Reset Map Data and Recalculate Track Statistics with confirmation dialogs

- [x] `lib/screens/settings_screen.dart` - Rename `_resetMapData` → `_confirmResetMapData`, add `showDangerConfirmDialog` call (follow `_confirmResetTrackData` pattern, key `reset-map-data-confirm`, label "Reset")
- [x] `lib/screens/settings_screen.dart` - Rename `_recalculateTrackStatistics` → `_confirmRecalculateTrackStatistics`, add `showDangerConfirmDialog` call (key `recalculate-stats-confirm`, label "Recalculate")
- [x] `lib/screens/settings_screen.dart` - Update `onTap` for Reset Map Data tile (line 103) → `_confirmResetMapData`
- [x] `lib/screens/settings_screen.dart` - Update `onTap` for Recalculate Track Statistics tile (line 137) → `_confirmRecalculateTrackStatistics`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: None significant; follows established pattern exactly
- **Out of scope**: "Reset Track Data" (already has dialog), dialog styling changes, new widget extraction
