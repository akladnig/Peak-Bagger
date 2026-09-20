---
type: Work Item
title: Add Peak List Details Search And Filtering
parent: ../spec.md
---

## What to build

Build the selected Peak List details search-and-filter experience as a vertical Flutter slice through `PeakListsScreen`, the app-scoped metadata provider, the existing metadata popup, selected-list data, and deterministic widget tests. Present the selected title, always-visible Map-styled `Search peaks` field, moved `Filter` control, and existing Add Peak control in that exact left-to-right order on one header line.

Apply the trimmed, case-insensitive peak-name substring query and every active `Map metadata filter` criterion with AND logic to only the selected `_PeakListSummaryRow.peakRows`, before the existing `_PeakDetailsTableCard` sort behavior. Preserve current selection, table scrolling, peak-dialog, repository, and derived-summary behavior. Do not change the `Search popup`, add another search action, add filter rows or operators, introduce persistence beyond the current app session, change Add Peak behavior beyond placement, wrap or horizontally scroll the details header, or add network, service, persistence, credential, or API boundaries.

## Required context

- `lib/screens/peak_lists_screen.dart` owns the effective selected Peak List ID, direct selection, automatic region-filter handoff, route-provided `initialPeakListId`, peak-detail dialog, and Peak list mini-map. Keep the query screen-owned, dispose its `TextEditingController` and focus resources, and clear it whenever the effective selected Peak List ID changes.
- Apply filtering to `_PeakListSummaryRow.peakRows` before `_PeakDetailsTableCard` sorting. Preserve its selection, scrolling, peak-dialog, repository, and derived-summary behavior.
- Reuse `lib/widgets/map_metadata_filter_popup.dart` unchanged for its fixed rows, criterion-row selectors, and `Clear filters` selector. Its difficulty options must be built from the currently selected Peak List's member peaks; a stale selected difficulty must stay visible and active when unavailable in a newly selected list.
- Follow existing Riverpod provider overrides, in-memory repositories, direct `PeakListsScreen` pumping, and `TestMapNotifier` conventions in `test/widget/peak_lists_screen_test.dart`. Pump the constrained-layout coverage at 721 logical pixels wide and text scale 1.0 so the existing 360 px summary pane, 1 px divider, and 360 px details pane determine the constraint.
- Add exactly these stable selectors: `peak-lists-name-search`, `peak-lists-metadata-filter-trigger`, `peak-lists-metadata-filter-popup`, `peak-lists-metadata-filter-backdrop`, and `peak-lists-filtered-empty-message`. Retain the popup's existing criterion-row and `Clear filters` selectors. No `pubspec.yaml` dependency change or robot journey test is required.

## Acceptance criteria

- [x] The selected Peak List details header orders the selected Peak List title, always-visible outlined `Search peaks` text field, `Filter` control, and existing Add Peak control from left to right. The field uses the Map search control's visual language, has a search icon and exact `Search peaks` label/placeholder, is not a button, and never opens the `Search popup`.
- [x] At a details-pane width of at least 360 px, the header remains one line without wrapping, clipping, or horizontal scrolling. Long titles ellipsize and expose their full name through a tooltip, the search field retains at least 120 px, and `Filter` and Add Peak have fixed widths.
- [x] When no Peak List is selected, the title remains `Peak List Details`; `Search peaks` and `Filter` are disabled; Add Peak is omitted; and the existing no-list message remains. The filtered empty-result message is not shown until a Peak List is selected.
- [x] Editing `Search peaks` immediately matches a trimmed, case-insensitive substring against selected-list peak names. Empty or whitespace-only text shows every row otherwise allowed by active metadata criteria.
- [x] The name query and every active `Rating`, `Difficulty`, and `Duration` criterion are applied with AND logic before the table's existing sort order; a row appears only when it matches the query and every active metadata criterion.
- [x] The moved `Map metadata filter` remains the canonical, fixed three-row `Rating`, `Difficulty`, and `Duration` control, distinct from Peak List selection controls. Its options derive from the current selected Peak List's member peaks, its label retains `Filter`, `1 Filter`, `2 Filters`, and `3 Filters`, and `Clear filters` sets all three criteria to `Any` while leaving the popup open.
- [x] Metadata selections update the detail table immediately and remain for the app session across Peak List changes and Peak Lists route revisits. They clear only through `Clear filters`, are not persisted across app restart, and an unavailable selected difficulty remains visible and active until changed or cleared.
- [x] The metadata popup closes when the effective selected Peak List changes or Peak Lists loses the active route. Outside tap, `Esc`, and `Ctrl+C` dismissal preserve selections; `Esc` or `Ctrl+C` closes the metadata popup before a concurrently open Peak list mini-map popup; and the popup closes before a peak-detail dialog is shown.
- [x] The name query is scoped to the current selection and clears whenever the effective selected Peak List ID changes, including direct user selection, automatic region-filter handoff, and route-provided selection.
- [x] For a selected list with member rows where the active query and/or criteria remove every row, table headers and active controls remain visible and the body shows exactly `No peaks match the current search and filters.` without resetting the query or selections. A selected list with no member rows keeps the existing blank table body regardless of criteria.
- [x] Widget tests cover header order and Map-styled field, title ellipsis/tooltip, 120 px search minimum, one-line no-wrap/no-clip layout at the specified 721 logical-pixel test surface, immediate case-insensitive matching, trimmed-whitespace reset, AND filtering, retained sort behavior, selected-empty-list versus active-criteria zero results, and the exact zero-result message.
- [x] Widget tests cover query reset for direct selection, region-filter handoff, and route-provided selection; metadata retention across selection changes and route revisits; stale difficulty zero matches until cleared; popup close on selection change and route exit; Escape/Ctrl+C priority over an open Peak list mini-map popup; and popup exclusion before a peak-detail dialog.
- [x] Widget tests cover disabled no-selection controls, absent Add Peak, the existing no-list message, all named Peak Lists selectors, and the existing popup criterion-row and `Clear filters` selectors. Tests use existing in-memory repositories and Riverpod provider overrides only, with no robot journey, live map service, network request, API key, or secret.

## Covers

- User Stories: 1-3
- Requirements: 3-13
- Technical Decisions: 2-4
- Testing Strategy: 1-3, 5-6
- Interview Ledger: L1-L7

## Blocked by

01-decouple-map-metadata-filtering.md
