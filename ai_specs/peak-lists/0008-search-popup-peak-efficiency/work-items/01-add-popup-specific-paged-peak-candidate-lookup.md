---
type: Work Item
title: Add Popup-Specific Paged Peak Candidate Lookup
parent: ../spec.md
---

## What to build

Extend `PeakRepository` / `PeakStorage`, `ObjectBoxPeakStorage`, and `InMemoryPeakStorage` with a `Search popup`-specific paged peak lookup seam. Preserve name substring matching, elevation substring fallback, merge/dedupe behavior, deterministic sort/tie-breaking, early region filtering where practical, and leave generic `PeakRepository.searchPeaks()` unchanged.

## Required context

Current popup peak search routes through `MapSearchService._peakResults(...)` into `PeakRepository.searchPeaks()`, which loads all peaks and matches both name and elevation text. `ObjectBoxPeakStorage.getByName(...)` already provides case-insensitive storage-backed name lookup, but it is not ordered or paged for the popup contract. Keep widgets away from direct ObjectBox access; add the seam at the repository/storage layer so tests can use `InMemoryPeakStorage` deterministically.

Relevant files include `lib/services/peak_repository.dart`, `lib/services/map_search_service.dart`, `lib/models/peak.dart`, `test/services/peak_repository_test.dart`, and `test/services/map_search_service_test.dart`.

## Acceptance criteria

- [x] A popup-specific repository/storage API exists for peak candidate lookup and supports page-window selection before expensive map-name, region, subtitle, or other per-result enrichment.
- [x] `ObjectBoxPeakStorage` uses storage-backed case-insensitive name search as the primary source of truth instead of loading all peaks and scanning names in Dart.
- [x] `InMemoryPeakStorage` implements the same popup-specific seam with deterministic behavior matching the ObjectBox-backed path.
- [x] The seam preserves current `Search popup` peak matching semantics: case-insensitive substring matching on peak name and current elevation substring matching performed by `PeakRepository.searchPeaks()`.
- [x] Elevation-only fallback candidates are merged with name candidates, deduplicated by peak identity, ordered, and paged after the merged ordering is established.
- [x] Popup peak candidate ordering compares normalized display title according to active popup sort direction, then uses stable result id string as the ascending tie-breaker.
- [x] Active popup region filtering is applied to peak candidates as early as practical without changing current region-match semantics.
- [x] Generic `PeakRepository.searchPeaks()` remains available for existing non-popup peak search surfaces and is not migrated in this Work Item.
- [x] Behavior-first tests cover name matching, elevation-only matching, merge/dedupe, sort/tie-breaking, page-window selection, region filtering, and ObjectBox/in-memory deterministic equivalence where existing ObjectBox unit seams allow it.

## Covers

- User Stories: 1, 4
- Requirements: 1, 9-16
- Technical Decisions: 3-6
- Testing Strategy: 1-3, 6
- Interview Ledger: L1, L4, L5, L6

## Blocked by

None - ready to start
