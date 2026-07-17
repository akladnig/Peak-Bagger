---
type: Work Item
title: Manifest-Driven Search Popup and Region Filters
parent: ../spec.md
---

## What to build
Remove the remaining hard-coded Italy north-east search-region layer and make Search popup region options, compact labels, and aggregate-child matching fully manifest-driven. This work should align the Flutter region-filter behavior with `showInPeakList`, `shortName`, and `peakListFilterAliases` so region selection behavior follows one manifest-backed contract across search and peak-list region filters.

## Required context
- `lib/services/map_search_region_filter.dart` is the current hard-coded northeast exception seam. Replace that special-case model with manifest-backed metadata instead of moving the hard-coded lists elsewhere.
- `lib/services/region_manifest_catalog.dart` and `lib/providers/peak_list_region_filter_provider.dart` already expose manifest-backed region metadata that this item should extend or reuse.
- Reuse existing Search popup seams and tests in `lib/widgets/map_search_popup.dart`, `test/services/map_search_service_test.dart`, and `test/widget/map_screen_peak_search_test.dart`.
- Follow `GLOSSARY.md` terminology. User-facing labels should stay tied to manifest display metadata rather than ad hoc abbreviations.

## Acceptance criteria
- [x] Search popup region options come from manifest-backed region metadata rather than hard-coded app lists. For this slice, option inclusion comes from `showInPeakList`.
- [x] Compact region labels come from manifest `shortName` when present and otherwise fall back to the manifest display name.
- [x] Aggregate-to-child and alias matching comes from `peakListFilterAliases` or an equivalent manifest-backed roll-up contract; the app no longer depends on a hard-coded northeast-only option array or match branch.
- [x] The aggregate filter for `italy-nord-est` includes matching child `Italy administrative region` peaks such as `fvg`, `veneto`, `trentino-alto-adige`, and `emilia-romagna` through manifest-backed roll-up metadata, while a specific child filter such as `fvg` still matches only that child region's stored peaks.
- [x] Visible region-filter behavior remains manifest-driven for other regions as well: regions without `showInPeakList` such as `italy` are excluded from visible options, and manifest-backed display names remain the user-facing labels.
- [x] Focused service or widget coverage proves manifest-backed option sourcing, manifest-backed compact labels, aggregate-child matching through roll-up metadata, and removal of the hard-coded northeast-only Search behavior.

## Covers
- User Stories: 1, 2
- Requirements: 5
- Technical Decisions: 2, 3
- Testing Strategy: 3, 10
- Interview Ledger: L1-L3

## Blocked by
- `01-manifest-backed-italy-administrative-regions-and-priority-metadata.md`
