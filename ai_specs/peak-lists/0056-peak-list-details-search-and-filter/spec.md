---
type: Spec
title: Peak List Details Search And Filter
---

## Problem

The Peak List details table has sortable metadata columns but no direct way to narrow a selected list by peak name or metadata. The existing `Map metadata filter` lives in the Map app bar and filters map markers, separating the controls from the Peak List workflow where users compare a selected list's members. [L1] [L2]

## Proposed Outcome

The Peak List details header presents the selected list title, an always-visible Map-styled `Search ⌘F` text field with a `Search Peaks` tooltip, the moved `Map metadata filter` icon-and-label `Filter` control, and the existing Add Peak control on one line. Name and metadata criteria immediately narrow only the selected Peak List's detail table; map markers and the Map screen no longer expose or apply this filter. [L1] [L2] [L3] [L4] [L6] [L8]

## User Stories

1. As a Peak List user, I can search the selected list by a peak's name without leaving the details table. [L2] [L3]
2. As a Peak List user, I can narrow the table with `Rating`, `Difficulty`, and `Duration` criteria from the existing `Map metadata filter` popup. [L1] [L4]
3. As a user comparing a long-named list on a constrained desktop layout, I can keep the title and controls visible on one predictable header row. [L6]

## Requirements

1. Preserve `Map metadata filter` as the canonical term. It remains the three-criterion `Rating`, `Difficulty`, and `Duration` control, but moves from the Map app bar to the selected Peak List details header. It must remain distinct from peak-list selection controls. [L1]
2. Remove the Map app-bar `Filter` trigger and its trailing divider. The Map screen must no longer expose the metadata-filter popup or apply its selections to map markers. Do not change the separate Map `Search popup` behavior. [L1] [L3]
3. In the Peak List details header, order the controls from left to right as selected Peak List title, name-search field, `Filter` control, and the existing Add Peak control. [L1] [L6]
4. The name search must be an always-visible outlined text field styled with the Map search control's visual language, including a search icon, the exact `Search ⌘F` label, `Search Peaks` placeholder and tooltip. It must not act as a button or open the `Search popup`. [L3] [L8]
5. Update the detail table as the user edits the field. Match a trimmed, case-insensitive substring against each peak name. An empty or whitespace-only query must show all rows otherwise allowed by active metadata criteria. [L2]
6. Apply name-search and `Map metadata filter` criteria with AND logic before the table's existing sort order. A row must match the name query and every active metadata criterion to appear. [L2]
7. Reuse the existing fixed three-row metadata popup and its existing `Rating`, `Difficulty`, and `Duration` option and matching contracts. Its options must derive from the currently selected Peak List's member peaks. The `Filter` control must prefix the existing `Filter`, `1 Filter`, `2 Filters`, or `3 Filters` states with the Map search popup's filter icon. [L1] [L4] [L8]
8. Metadata selections must apply immediately to the detail table. Each `Rating`, `Difficulty`, and `Duration` popup menu option must invoke its criterion callback directly so selection works from the nested popup. Preserve the existing popup dismiss behavior: outside tap, `Esc`, or `Ctrl+C` dismissal keeps selections. When the metadata popup is open, `Esc` or `Ctrl+C` closes it before any concurrently open Peak list mini-map popup. The metadata popup must not coexist with a peak-detail dialog; close it before a dialog is shown. `Clear filters` resets all three criteria to `Any` and leaves the popup open. [L1] [L4] [L8]
9. Keep active metadata criteria for the app session, including when the user selects another Peak List or leaves and returns to the Peak Lists screen. Clear criteria only with `Clear filters`; do not add app-restart persistence. A difficulty selection unavailable in a newly selected list must remain visible and active until changed or cleared. Close the metadata popup when the effective selected Peak List changes or Peak Lists loses the active route; only the criteria persist across route revisits. [L4]
10. Keep the name-search query only for the current selection. Clear it whenever the effective selected Peak List ID changes, including direct user selection, automatic region-filter handoff, and route-provided selection. [L2] [L4]
11. When a selected Peak List has member rows and the current name query and/or metadata criteria remove every row, keep the headers, title, field, and filter controls visible and show exactly `No peaks match the current search and filters.` in the table body. Do not reset selections automatically. For a selected Peak List with no member rows, retain the existing blank table body regardless of the current criteria. [L5]
12. At a details-pane width of at least 360 px, the header must remain a single line. Long Peak List titles must ellipsize and expose their full name via tooltip. On wider panes, search and icon-and-label `Filter` use 160 px and 120 px widths respectively; at the 360 px details-pane constraint they compact to 132 px and 96 px so `Search ⌘F` remains visible alongside Add Peak. Do not wrap or horizontally scroll this header. [L6] [L8]
13. When no Peak List is selected, retain the `Peak List Details` title and show disabled `Search ⌘F` and `Filter` controls; omit Add Peak and retain the existing no-list message. Do not show the search-and-filter empty-result message until a Peak List is selected. [L5] [L8]

## Technical Decisions

1. Move metadata-filter ownership out of `MapState` into a dedicated app-scoped, non-persistent Riverpod Peak List details provider. The provider owns popup visibility and the three metadata selections, retains only the metadata selections across Peak Lists route revisits during the app session, and resets on app restart. Close the popup when the effective selected Peak List changes or Peak Lists loses the active route. Reuse the existing filter enums, matching rules, option builder, popup widget, and active-filter count rather than duplicating metadata rules. The new state must not synchronize selections back to map markers. [L1] [L4]
2. Keep the query as screen-owned UI state, clear it whenever the effective selected Peak List ID changes, and dispose any `TextEditingController` and focus resources with the screen. This keeps the query list-specific without introducing storage or asynchronous side effects. [L2] [L4]
3. Apply filtering to the selected `_PeakListSummaryRow.peakRows` before the existing `_PeakDetailsTableCard` sort logic. Preserve its current selection, table scrolling, peak-dialog, repository, and derived-summary behavior. [L1] [L2]
4. Reuse the current `MapMetadataFilterPopup` presentation and its criterion-row and `Clear filters` selectors. Anchor its open/dismiss lifecycle in `PeakListsScreen`; preserve the specified `Esc`/`Ctrl+C` dismissal priority and add no new network, service, persistence, credential, or API boundary. Add stable Peak Lists selectors: `peak-lists-name-search`, `peak-lists-metadata-filter-trigger`, `peak-lists-metadata-filter-popup`, `peak-lists-metadata-filter-backdrop`, and `peak-lists-filtered-empty-message`. [L1] [L7]

## Testing Strategy

1. Use behavior-first deterministic widget tests in `test/widget/peak_lists_screen_test.dart` for the one-line header order, `Search ⌘F` label with `Search Peaks` placeholder/tooltip, filter icon, title ellipsis/tooltip, compact 132 px search minimum, and absence of wrapping or clipping at a 360 px details-pane width. Pump `PeakListsScreen` directly on a 721 logical-pixel-wide, text-scale 1.0 test surface so its existing 360 px summary pane, 1 px divider, and 360 px details pane produce that constraint. [L3] [L6] [L7] [L8]
2. Add widget coverage for immediate case-insensitive substring matching, trimmed whitespace reset, direct rating, difficulty, and duration option selections that remove non-matching rows, AND-combined metadata criteria, retention of current sort behavior, the exact zero-result message, and preserving active controls when no rows match. Cover the selected empty-list blank-body state separately from an active-criteria zero-result state. [L2] [L5] [L7] [L8]
3. Add widget coverage proving a query resets whenever the effective selected Peak List changes, including direct selection, automatic region-filter handoff, and route-provided selection, while metadata selections persist across Peak List changes and Peak Lists route revisits. Prove the popup closes on a Peak List change or Peak Lists exit, including a stale selected difficulty that yields zero matches until cleared. Cover `Esc` or `Ctrl+C` closing the metadata popup before any concurrently open Peak list mini-map popup, and enforce that the popup cannot coexist with a peak-detail dialog. [L2] [L4] [L7]
4. Update Map metadata-filter and app-bar tests to prove the Map `Filter` trigger and divider are absent, the Map screen's markers do not react to Peak List details criteria, and the independent Map `Search popup` remains available. [L1] [L3] [L7]
5. Add widget coverage for the no-selected-list state: disabled `Search peaks` and `Filter` controls, no Add Peak control, and the existing no-list message rather than the filtered empty-result message. Assert the named Peak Lists selectors while retaining the popup's existing criterion-row and `Clear filters` selectors. [L5] [L7]
6. Reuse existing in-memory repositories and Riverpod provider overrides. No robot journey test, live map service, network request, API key, or secret is required. [L7]

## Out of Scope

1. Changing the `Search popup` or adding a second search action to Peak List details. [L3]
2. Adding metadata-filter rows, saved filters, boolean operators, nested filters, app-restart persistence, or a global normalized `Peak difficulty` scale. [L1] [L4]
3. Changing existing Add Peak behavior beyond placing its current control in the one-line header. [L6]
4. Wrapping or horizontally scrolling the Peak List details header. [L6]

## Notes

1. Relevant implementation surfaces are `lib/screens/peak_lists_screen.dart`, `lib/widgets/map_metadata_filter_popup.dart`, `lib/services/peak_metadata_rules.dart`, `lib/router.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/widget/map_screen_metadata_filter_test.dart`.
2. This Spec supersedes only the Map app-bar placement and map-marker application portions of the metadata-filter contract in `ai_specs/peak-lists/0020-peak-rating-difficulty-duration-sorting-and-filters/spec.md` and `ai_specs/peak-lists/0023-map-metadata-filter-refresh-and-hover-affordances/spec.md`. The fixed popup's criterion and option semantics remain intact.
