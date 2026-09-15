---
type: Work Item
title: Add Track Date Query and Range-Qualified Search
parent: ../spec.md
---

## What to build

Add the app-owned deterministic Track date/date-range query model and parser, then carry the transient active range through `MapState`, `MapNotifier`, and `MapSearchService`. Date-qualified search must evaluate persisted `GpxTrack.trackDate` calendar components and return only the eligible Tracks and distinct bagged Peaks before existing region filtering, sorting, grouping, pagination, and result enrichment.

## Required context

- Read `GLOSSARY.md`: a `Track date` is `GpxTrack.trackDate`; `PeaksBagged` is the persisted association between a Peak and a Track.
- Follow the existing criteria, request-serial, first-page reset, and load-more patterns in `lib/providers/map_provider.dart` and `test/harness/test_map_notifier.dart`.
- Follow popup search paging and peak-enrichment conventions in `lib/services/map_search_service.dart` and `test/services/map_search_service_test.dart`.
- Use `PeaksBaggedRepository.test(InMemoryPeaksBaggedStorage(...))`, `GpxTrackRepository.test(InMemoryGpxTrackStorage(...))`, and `PeakRepository.test(InMemoryPeakStorage(...))` for deterministic tests. Do not introduce ObjectBox, network services, API keys, or external secrets.
- The existing `PeaksBaggedRepository` derives `PeaksBagged.date` in Australian Eastern time. It must not become a date-search source; the date criterion uses `GpxTrack.trackDate` components directly.

## Acceptance criteria

- [x] Behavior-first TDD covers the app-owned parser before implementation and keeps its grammar independent of locale-dependent or sliding-window parsing.
- [x] The parser classifies and parses only complete day-first Australian `d/M/yy`, `d/M/yyyy`, `d MMM yy`, and `d MMM yyyy` expressions, with ASCII `Jan` through `Dec` case-insensitive and one or more spaces in month expressions.
- [x] The parser maps two-digit years `00` through `49` to `2000` through `2049` and `50` through `99` to `1950` through `1999`; validates real calendar dates; accepts inclusive `-` and `..` ranges with optional surrounding whitespace; and preserves a single day as a one-day range.
- [x] The parser identifies date-like input exactly as specified: a trimmed value that begins with a digit and contains a slash or a supported range separator, or begins with a one- or two-digit numeric day followed by an alphabetic token. Invalid and partial date-like input is distinguishable from non-date-like name input; unsupported mixed name-and-date expressions are not valid date queries.
- [x] The single-date parser grammar is reusable by picker endpoint fields and rejects range expressions in that endpoint mode.
- [x] The active range is one transient Search popup criterion alongside query, entity filter, region filter, sort, group, pagination state, and request serial. Changing or clearing it resets the loaded page and invalidates outstanding load-more work; it is cleared when the Search popup closes and is never persisted across sessions.
- [x] `MapSearchService.searchPage` and the `MapNotifier` forwarding path accept the active range. A range with an empty or under-threshold optional name query executes and can load later pages; text-only search without an active range retains the existing three-character minimum.
- [x] Range-qualified Track eligibility compares only the persisted `GpxTrack.trackDate.year`, `.month`, and `.day` directly to endpoint components, ignores time-of-day, excludes Tracks without a Track date, does not convert timezones, and does not substitute GPX start or end timestamps.
- [x] Range-qualified Peaks are obtained only from `PeaksBagged` rows whose `gpxId` belongs to Track-date-matching Tracks. Resolve distinct `PeaksBagged.peakId` values as `Peak.osmId`, including negative synthetic IDs, never as ObjectBox `Peak.id`, and do not filter on `PeaksBagged.date` or alter its existing date-derivation behavior.
- [x] With an active range, `All` returns eligible Tracks plus distinct associated Peaks; `Peaks` returns those Peaks only; `Tracks/Routes` returns eligible Tracks only and excludes Routes; `Maps` returns no results. Optional non-empty text narrows Tracks by Track name and Peaks by Peak name; existing region, sort, group, pagination, result-selection, and ordinary text-only peak-search behavior are preserved.
- [x] Unit tests cover a single Track date and inclusive range, persisted device-local component comparison without timezone conversion, undated Track exclusion, distinct PeaksBagged membership, differing `GpxTrack.trackDate` and `PeaksBagged.date`, `Peak.osmId` resolution including a negative ID, entity filters, optional names, region filtering, sorting, grouping, pagination, and absence of Routes and Maps from range-qualified results.

## Covers

- User Stories: 2-4
- Requirements: 6-9, 11-15
- Technical Decisions: 1-5
- Testing Strategy: 1-3
- Interview Ledger: L1, L3-L6, L8, L10-L13

## Blocked by

None - ready to start
