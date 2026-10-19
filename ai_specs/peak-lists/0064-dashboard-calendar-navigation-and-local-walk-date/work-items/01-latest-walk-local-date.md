---
type: Work Item
title: Correct Latest Walk's Mac-local date display
parent: ../spec.md
---

## What to build

Correct Latest Walk's timestamp-to-display conversion, including walks reached through its previous/next controls. Preserve the timestamp/calendar-day distinction, selection algorithm, card states, and existing map navigation. This is an independent display slice with its unit/widget regressions.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide only, macOS-only, maximised launch; shared formatting and accessibility contracts).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 1–2 and 20; Technical Decisions 1–2; Testing Strategy 1–2 and 8; R4. Read sibling `interview-ledger.md`, especially L1–L2, and `GLOSSARY.md`.
- `lib/services/latest_walk_summary.dart`, `lib/core/date_formatters.dart`, `lib/widgets/dashboard/latest_walk_card.dart`, `lib/screens/dashboard_screen.dart`, and `lib/router.dart` for the actual display and navigation boundaries.
- `test/services/latest_walk_summary_test.dart`, `test/widget/latest_walk_card_test.dart`, and `test/robot/dashboard/dashboard_robot.dart` for selectors and existing tile/provider overrides.
- `ai_specs/peak-lists/0057-dashboard-ui-updates/spec.md` for retained short-month text and pointing-cursor behavior. The new parent Spec owns the corrected timestamp conversion.

## Acceptance criteria

- [x] Latest Walk selection remains descending `startDateTime`, then descending `gpxTrackId` on equal timestamps; null start timestamps remain excluded. Preserve geometry/empty handling, including `No walks yet`, rather than choosing a different Track to conceal empty geometry.
- [x] Convert the selected `startDateTime` to the Mac's local timezone immediately before shared display formatting. Apply the same conversion to every walk reached through `latest-walk-prev-track` / `latest-walk-next-track`. Do not substitute `trackDate`.
- [x] Preserve `formatTrackDateShortMonth`'s visible format and direct absent-value result `Unknown`. In `Australia/Hobart`, `2026-10-14T23:30:00Z` displays exactly `Thu, 15 Oct 2026`; include a separate UTC/local year-rollover assertion with an independently known expected local date.
- [x] Date-only Track formatting remains component-preserving. This display operation changes no `trackDate`, stored start/end timestamp, or GPX content. Unit/widget assertions capture values before rendering/navigation and prove they remain unchanged.
- [x] Preserve Dashboard entry/exit and the selected Track's existing map-opening callback/destination (`/map`), existing dependency-failure reporting, metric text, and previous/next availability. Introduce no route, runtime network request, credentials, persisted Dashboard metric summary, or navigation preference.
- [x] Preserve macOS keyboard/pointer operation, accessible action descriptions, focus and enabled/disabled feedback; preserve selected-profile layout and existing semantic light/dark styling.
- [x] Extend the named unit/widget tests for local conversion, midnight/year rollover, latest selection, tie-break, null/Unknown, geometry-empty, visible format, and previous/next walk navigation. Expected rollover dates must not merely repeat the production conversion/formatter expression.
- [x] Use behavior-first regressions; no extra strict one-test-at-a-time TDD mandate is added. Replace live tile access using `latestWalkTileProviderFactoryProvider`, use existing Riverpod/mapping fixtures, and dispose test resources. Automated tests use no external services, live tiles, API keys, or user database.

### Verification

Run from the project root. Assert the expected Hobart offsets in timezone-sensitive tests so a runner ignoring `TZ` fails visibly. Complete the parent Spec's Testing Strategy 8 focused run in addition to these changed-slice tests and the full suite.

```sh
TZ=Australia/Hobart flutter test \
  test/services/latest_walk_summary_test.dart \
  test/widget/latest_walk_card_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

### Completion evidence — 2026-10-16

- `LatestWalkSummary.fromTrack` converts `startDateTime` with nullable `toLocal()` immediately before `formatTrackDateShortMonth`; all card selections use this boundary. Shared date-only formatters remain component-preserving.
- Behavior-first regressions failed with the original UTC-day output, then passed with independently specified `Thu, 15 Oct 2026` and `Fri, 1 Jan 2027` expectations. Tests assert Hobart's UTC+11 daylight and UTC+10 standard offsets.
- Unit and light/dark widget tests snapshot `GpxTrack.toMap()` before summary/rendering and after previous/next navigation, including deliberately different Track dates, start/end timestamps, and GPX content. Keyboard Enter activates the focused Previous control; selected-Track title/mini-map callbacks, metric text, bounds, tooltips, cursors, and empty-newest-geometry behavior are verified.
- Latest Walk widget tests override `latestWalkTileProviderFactoryProvider` with an in-memory image provider and retain the existing mapping catalog fixture; no live tile access is needed.
- Dashboard/router source review confirms the existing selected-Track `showTrack(trackId)` → `/map` path. Existing Dashboard entry/exit and dependency-readiness/failure tests passed in the full suite. This display-only slice depends on none of the profile's Pending window/layout decisions; no exception is proposed.
- Changed-slice command above: **22 passed**. Parent Testing Strategy 8's exact nine-file focused command: **74 passed**. `flutter analyze`: **no issues**. Complete `TZ=Australia/Hobart flutter test`: **2,298 passed, 5 skipped**. An earlier full-suite attempt exceeded the shell's ten-minute limit; the successful complete rerun used a longer command timeout.
- Verification covers service/widget/routed regression behavior on the macOS host; no native-app visual session was performed for this display-only slice.

## Covers

- User Stories: 1.
- Requirements: 1–2; 20 (Latest Walk display/application boundary).
- Technical Decisions: 1–2.
- Testing Strategy: 1–2; 8.
- Interview Ledger: L1–L2.
- Approved refinement decisions: R4; preserve R1's separation of location-derived Track dates from Mac-local timestamp display.

## Blocked by

None - ready to start
