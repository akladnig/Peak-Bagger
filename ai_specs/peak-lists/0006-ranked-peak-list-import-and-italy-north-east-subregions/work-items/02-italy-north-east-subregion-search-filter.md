---
type: Work Item
title: Italy North East Subregion Search Filter
parent: ../spec.md
---

## What to build
Extend the existing Search popup `Filter` control and peak-search behavior so the app adds the exact `FVG`, `Veneto`, `Trentino Alto Adige`, and `Emilia Romagna` options alongside the current broader manifest-driven region options, filters peak results by stored `Peak.region` using the new northeast subregion keys `fvg`, `veneto`, `trentino-alto-adige`, and `emilia-romagna`, keeps non-peak entities on the broader existing region model in `All` mode, preserves the current single horizontally scrollable control row and active-filter label behavior, keeps the new options available even when results are empty, and adds focused service and widget coverage for the new visible behavior.

## Required context
- `lib/services/map_search_service.dart` currently resolves regions through `regionManifestCatalog` and is the right place to add the peak-specific subregion filtering behavior without forcing tracks, routes, or maps into the new subregion model.
- `lib/widgets/map_search_popup.dart` and `lib/screens/map_screen.dart` already provide the single `Filter` menu, active-label behavior, and horizontally scrollable control row. This item should compose app-owned northeast subregion options with `regionManifestCatalog.allRegions()` rather than requiring top-level manifest entries.
- Preserve the canonical terminology in `GLOSSARY.md`, especially `Italy North East subregion`.
- Follow existing test conventions in `test/services/map_search_service_test.dart` and `test/widget/map_screen_peak_search_test.dart`, including stable app-owned selectors such as `map-search-filter-button`, `map-search-filter-trigger`, and `map-search-region-...`.
- `lib/services/peak_list_visibility.dart` and other broader region utilities still rely on the current manifest region model. This slice does not introduce a reusable parent-region hierarchy or require tracks, routes, maps, or peak-list visibility logic to resolve into the new subregions.

## Acceptance criteria
- [ ] The existing Search popup keeps one `Filter` menu and adds these exact user-facing options to that same menu: `FVG`, `Veneto`, `Trentino Alto Adige`, and `Emilia Romagna`, while keeping broader existing options such as `Italy North East` in the same menu.
- [ ] The Search popup continues to use the current horizontally scrollable control row, does not add a second filter control, keeps the subregion options available even when current results are empty, and remains usable on desktop and narrower/mobile widths with current text scaling without hiding the active filter label.
- [ ] When a northeast subregion is selected, the filter button label shows that exact selected label; `None` continues to clear the filter.
- [ ] In `Peaks` search mode, selecting `fvg`, `veneto`, `trentino-alto-adige`, or `emilia-romagna` filters peak results by stored `Peak.region` exactly.
- [ ] In `All` search mode, selecting one of the northeast subregions narrows peak results by stored `Peak.region` while non-peak results continue to follow the broader existing region model instead of being forced into the new subregions.
- [ ] The slice introduces the stored/search northeast subregion keys `fvg`, `veneto`, `trentino-alto-adige`, and `emilia-romagna` under the broader `italy-nord-est` umbrella for peak-focused search behavior only; it does not back-classify existing `italy-nord-est` peaks and does not require `PeakList.region`, tracks, routes, maps, polygons, or manifest entries to move to the new subregions.
- [ ] Behavior-first TDD drives this item. Focused service coverage proves the new subregion keys, peak-only filtering in `Peaks` mode, peak-only narrowing in `All` mode, preservation of broader non-peak region behavior, and the decision not to back-classify existing `italy-nord-est` peak data.
- [ ] Widget coverage proves the Search popup shows the exact new menu entries, updates the filter button label to the selected subregion label, and keeps the subregion filter options available even when search results are empty.

## Covers
- User Stories: 3-4
- Requirements: 14-18, 20
- Technical Decisions: 4-5
- Testing Strategy: 1, 3-4
- Interview Ledger: L12-L14

## Blocked by
None - ready to start
