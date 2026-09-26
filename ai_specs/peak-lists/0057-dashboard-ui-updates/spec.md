---
type: Spec
title: Dashboard UI Updates
---

## Problem

Several Dashboard surfaces are inconsistent with the project's compact date format and sentence-case copy. My Year to Date reports a distinct-peak total rather than the user's recorded climbs, and Dashboard header metrics reserve a fixed-width, right-justified value field that visually separates their labels from values. The relevant interactive controls also do not consistently indicate clickability with a pointing mouse cursor. [L1] [L2] [L3] [L4]

## Proposed Outcome

The Dashboard presents recorded walks, ascents, summary metrics, and list progress with the requested copy and compact dates. Yearly climb totals consistently represent recorded `PeaksBagged` associations, and selectable Dashboard controls visibly communicate their enabled state with a pointing cursor. [L1] [L2] [L4]

## User Stories

1. As a walker, I can read My Ascents and Latest Walk dates in the compact short-month format.
2. As a walker, I can see how many recorded peak climbs I completed in each My Ascents year and in the selected My Year to Date year.
3. As a Dashboard user, I can read card-header summary metrics as naturally spaced `label: value` pairs and identify enabled controls that can be selected.
4. As a peak-list user, I can read the completion percentage column as `Climbed %`.

## Requirements

1. My Ascents row dates and Latest Walk's date summary must use the existing `formatTrackDateShortMonth` output, including its existing `Unknown` fallback for an absent date. Other track-information surfaces keep their current date formatter. [L1]
2. Each My Ascents year heading must append the number of displayed recorded climbs in that year in the form `<year> - <count> peaks climbed`, for example `2026 - 74 peaks climbed`. The count follows the same dated `PeaksBagged` records and year grouping as the rows, so excluded undated records are not counted. [L1] [L2]
3. My Year to Date's `Peaks climbed` value must count persisted `PeaksBagged` rows whose `date` falls in the selected calendar year. A peak climbed on separate recorded walks counts once per association; it must not collapse to a distinct-peak total. `New peaks climbed` retains its existing first-ever-climb meaning. [L1] [L2]
4. My Year to Date metric labels must use sentence case: `Kilometers walked`, `Metres climbed`, `Total walks`, `Peaks climbed`, and `New peaks climbed`. [L1]
5. The Distance, Elevation, and Peaks Bagged card-header summary metrics must render each label and value with exactly one space, for example `Total: 74`. Remove only the fixed-width, right-justified value field; keep the metric group right-aligned within the header and preserve responsive truncation/scaling behavior. [L1] [L3]
6. The My Lists percentage column heading must be `Climbed %`. Its data, order, and numeric alignment remain unchanged. [L1]
7. Enabled Dashboard Summary controls use `SystemMouseCursors.click`: the period dropdown trigger and menu entries, previous/next controls, and line/column view control. This applies to all Summary-card users: Distance, Elevation, and Peaks Bagged. [L1] [L4]
8. Enabled Latest Walk previous/next controls, enabled My Year to Date previous/next controls, and the My Ascents sort button use `SystemMouseCursors.click`. Disabled controls retain the default cursor. [L1] [L4]
9. The changes must preserve existing Dashboard navigation, card layout/reordering, loading and empty states, keyboard semantics/tooltips, data persistence, and error behavior. No new network call, API key, background work, or persistence setting is introduced. [L1] [L4]

## Technical Decisions

1. Reuse `formatTrackDateShortMonth` from `lib/core/date_formatters.dart`; do not add a parallel formatter. [L1]
2. Extend the existing `YearToDateSummaryService` input boundary to receive persisted `PeaksBagged` rows alongside tracks. Count rows whose `PeaksBagged.date` falls in the selected year rather than a cross-year set of unique peak IDs; preserve the existing local-year handling and `newPeaksClimbed` calculation. [L2]
3. Derive each My Ascents heading count from its existing `MyAscentsYearSection.rows`, keeping the header and visible row source of truth identical. [L1] [L2]
4. Update the reusable Summary-card/header implementation so the three existing card types receive consistent cursor and header-spacing behavior without duplicating it per card. Apply the remaining cursor updates directly to their existing card controls. [L3] [L4]
5. Keep the existing Riverpod providers, state ownership, navigation routes, keys, and dashboard robot seams. The changes are local formatting, presentation, and deterministic summary calculations; only the Year to Date summary input gains the existing persisted `PeaksBagged` rows. No controller lifecycle change is required.

## Testing Strategy

1. Use behavior-first TDD for the Year to Date summary calculation. Extend `year_to_date_summary_service_test.dart` with persisted `PeaksBagged` rows whose selected-year dates include repeated climbs of one peak on separate walks, while unrelated years and missing dates do not contribute. Confirm `New peaks climbed` remains unchanged. [L2]
2. Extend focused My Ascents and Latest Walk service/widget tests to assert the existing short-month formatter is displayed. Cover yearly header counts alongside their grouped displayed rows and preserve the empty-state behavior. [L1] [L2]
3. Extend My Year to Date and My Lists widget tests to assert the corrected climb total, exact sentence-case labels, and `Climbed %` header. [L1] [L2]
4. Extend Dashboard and Summary-card widget tests to assert one-space header metrics, preserved right-side grouping, and click cursors for every enabled scoped control. At a constrained card width and enlarged text scale, assert the right-aligned metric group remains visible without overflow. Assert disabled previous/next controls retain the default cursor; use existing keys rather than adding selectors. [L3] [L4]
5. Keep existing Dashboard robot journeys passing to guard card scoping and navigation. No new robot journey, live network service, API key, or external fake is needed for this deterministic presentation and summary work.
6. Run `flutter analyze`, the focused service/widget/robot tests, and `flutter test` before completion.

## Out of Scope

1. Changing date formatting on map panels or other non-Dashboard track views.
2. Applying cursor changes to controls outside the named Dashboard scope.
3. Changing My Ascents or My Lists table-column layout/alignment, list data, sort semantics, Dashboard navigation, or card reordering.
4. Redefining `New peaks climbed`, adding data migrations, or altering persisted `PeaksBagged` records.
