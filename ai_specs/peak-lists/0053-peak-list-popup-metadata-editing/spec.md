---
type: Spec
title: Peak List Popup Metadata Editing
---

## Problem

The `PeakListPeakDialog` edit mode on the Peak Lists screen can update only the selected peak's list-specific points. Users cannot correct `Peak difficulty` or `Peak duration` in the same context, despite those shared fields driving the Peak Lists table and map metadata filters. This forces a separate maintenance flow and leaves the local list view stale after a metadata correction. [L1] [L3]

## Proposed Outcome

The existing Peak Lists edit popup edits points, `Difficulty`, and `Duration` together. Points remain a property of the selected Peak List membership; difficulty and duration are saved to the shared `Peak` record. The popup uses the app's existing duration format and validation rules, closes only after a successful save, and refreshes relevant Peak Lists and map metadata views immediately. [L1] [L2] [L3]

## User Stories

1. As a Peak Lists user, I can correct a peak's list-specific points and its shared difficulty and duration from the existing edit popup, without navigating to a separate admin screen. [L1]
2. As a user comparing peaks or applying map metadata filters, I see a completed metadata edit reflected immediately after saving. [L1] [L3]
3. As a user entering an estimated duration, I receive a clear error for an unsupported format without losing the values I entered. [L2] [L3]

## Requirements

1. Extend only the edit mode of `PeakListPeakDialog`, opened from the Peak Lists screen's existing peak edit action. Do not change the add-peak flow, delete flow, peak-list selection behavior, or navigation behavior. [L1]
2. Retain the existing `Points` selector and its current permitted values. Points must continue to update only the selected `PeakListItem` for the active Peak List. Editing a membership's points must not change its points in another list. [L1]
3. Add editable text fields labelled exactly `Difficulty` and `Duration` beneath the points control. Pre-fill both from the selected `Peak`: difficulty from `Peak.difficulty` and duration from the existing `peakDurationDisplayLabel` behavior. [L2]
4. Saving `Difficulty` updates the shared `Peak.difficulty` value. Difficulty is free text: retain the user's non-empty text and accept existing region-specific grades such as `Easy`, `EE`, and `T4`; an empty value clears the stored difficulty. Do not introduce a per-list difficulty value or a new global difficulty scale. [L1] [L2]
5. Saving `Duration` parses the entered value with the existing `parsePeakDuration` contract. Support `H:MM`, `N-N hour(s)`, `N-N day(s)`, `1 day`, and `N days`; persist its machine-readable minutes in `Peak.durationMinutes` and the entered label in `Peak.durationLabel`. An empty duration clears both stored duration values. [L2]
6. If the duration is invalid, show the existing parser error adjacent to the duration field and do not start persistence. Keep the popup open with the selected points and entered difficulty and duration intact so the user can correct the value. [L2] [L3]
7. Save the edited membership points and shared Peak metadata as one successful user action. Validate before writing and avoid reporting a successful save when either required update fails. On a persistence failure, keep the popup open, preserve all entered field values, and use the existing `Peak List Update Failed` feedback surface. [L3]
8. On a successful save, retain the current outcome: close the popup and return the selected peak outcome. Immediately invalidate or refresh the Peak Lists data that reads the edited peak and all active map metadata-dependent content, including an active difficulty or duration filter. The updated shared values must be visible without reopening the app or manually changing the selected list. [L1] [L3]
9. Preserve the popup's existing cancel, close icon, barrier-dismiss, Escape/back, draggable placement, responsive width, scrolling, and saving-state behavior. Cancel or dismiss without saving must not persist any edited field. [L3]

## Technical Decisions

1. Use the existing `Peak` fields as the sole source of truth for metadata: `difficulty`, `durationMinutes`, and `durationLabel`. Reuse the `PeakListItem.points` relation only for the active list's points. [L1] [L2]
2. Reuse `parsePeakDuration` and `peakDurationDisplayLabel` from `peak_metadata_rules.dart`; do not introduce a second parser, duration format, or metadata model. [L2]
3. Persist shared metadata through the existing `PeakRepository.save` path so ObjectBox remains the persistence boundary. Update the current list membership through `PeakListRepository.updatePeakItemPoints`. Coordinate writes so a failed save cannot be presented as a fully successful edit. [L1] [L3]
4. After success, notify both the existing peak revision state and the Peak List membership refresh path. Reuse their established map reconciliation and popup-content refresh behavior rather than adding screen-local copies of peak data. [L3]
5. Keep editing state inside the existing stateful dialog. Dispose any text controllers with the dialog and do not introduce new persistence, API, network, secret, or background-job dependencies.

## Testing Strategy

1. Extend the existing `test/widget/peak_list_peak_dialog_test.dart` widget seam, which uses `ProviderScope` overrides with `InMemoryPeakStorage`, `PeakListRepository.test`, and `TestMapNotifier`. No network calls, API keys, or real ObjectBox store are required. [L1] [L2] [L3]
2. Add focused widget coverage for a successful edit that changes points, difficulty, and duration: assert list-specific points changed only in the active list, shared Peak metadata persists as the correct difficulty, duration label, and duration minutes, the dialog returns its successful outcome, and the relevant revision/refresh behavior is triggered. [L1] [L2] [L3]
3. Add focused widget coverage for pre-filled values, blank difficulty and duration clearing, accepted duration formats, and invalid duration input. The invalid case must expose the parser error, keep the dialog open, retain all typed values, and make no persistence changes. [L2] [L3]
4. Add stable widget keys for the new difficulty and duration fields and any field-error widget needed for deterministic assertions, following the existing `peak-list-peak-*` selector convention. Existing widget tests are sufficient; no robot journey test is required for this contained dialog change.
5. Retain the existing service-level `peak_metadata_rules` parser tests as the duration-format source of truth. Add or adjust a focused unit test only if the feature needs a new clearing or persistence helper; otherwise avoid duplicating parser coverage in a new service.

## Out of Scope

1. Editing shared peak metadata from the add-peak flow. [L1]
2. Per-list difficulty or duration overrides. [L1]
3. A difficulty dropdown, a normalized global difficulty scale, or changes to region-specific difficulty filtering. [L2]
4. New duration syntax, automatic duration estimation, or changes to duration sorting and filtering rules. [L2]
5. Changes to popup navigation, deletion, membership management, persistence configuration, API integrations, or background jobs. [L3]
