---
type: Work Item
title: Persisted Peak Correlation Threshold Settings
parent: ../spec.md
---

## What to build

Extend the existing SharedPreferences-backed Peak Correlation settings boundary to persist and independently normalize both correlation thresholds. Retain `Distance threshold`; add the `Elevation threshold` integer dropdown with a 10 m default and exactly 10, 20, 30, ..., 100 m supported values.

Update the Peak Correlation Settings section to show both configured thresholds in metres. Saving either threshold must not rebuild existing tracks.

## Required context

- `lib/providers/peak_correlation_settings_provider.dart` currently exposes the SharedPreferences-backed distance threshold.
- `lib/core/constants.dart` contains existing correlation defaults and options.
- `lib/screens/settings_screen.dart` contains the Peak Correlation section and the `peak-correlation-settings-section` and `peak-correlation-distance-meters` widget keys.
- `test/widget/peak_correlation_settings_test.dart` and `test/services/gpx_filter_settings_provider_test.dart` demonstrate the existing SharedPreferences provider test seam.

## Acceptance criteria

- [x] Peak Correlation retains `Distance threshold` and adds an `Elevation threshold` integer dropdown.
- [x] `Elevation threshold` defaults to 10 m and supports exactly 10, 20, 30, ..., 100 m.
- [x] Invalid or unavailable stored elevation values resolve to the 10 m default independently of the stored distance value, using a distinct SharedPreferences key.
- [x] The Peak Correlation section summary shows both configured thresholds in metres.
- [x] Saving `Distance threshold` or `Elevation threshold` persists only the changed setting and does not rebuild existing Tracks.
- [x] Provider and widget coverage verifies defaults, every supported elevation value, invalid-value normalization, the new field, the two-threshold summary, and persistence through the established settings-provider seam.

## Covers

- User Stories: 2
- Requirements: 6-9
- Technical Decisions: 2
- Testing Strategy: 3-4
- Interview Ledger: L2, L4, L5

## Blocked by

None - ready to start
