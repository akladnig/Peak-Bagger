---
type: Spec
title: My Peak Lists Region FAB Filters
---

## Problem

`My Peak Lists` currently exposes summary-header actions for `Add New Peak List` and `Import Peak List`, but it has no permanent manifest-region filter in the shared app bar. The request is to add permanent app-bar controls styled like the Map screen peak-list controls, use the region manifest rather than ad hoc country logic, remove the on-screen create action from `My Peak Lists`, and keep the layout usable beside the shared `My Peak Lists` title on both wide and constrained widths. [L1] [L2] [L7] [L8] [L13] [L14]

## Proposed Outcome

On the `/peaks` route, the shared app bar shows permanent `region FABs` for the manifest regions immediately beside the `My Peak Lists` title, using short manifest-backed labels, full-name tooltips and semantics, and the same accent palette language as the Map screen peak-list controls. These controls act as a persisted multi-select filter over `My Peak Lists`, keep mixed-region lists when any selected region applies, hide unsupported legacy-region lists, remove the `Add New Peak List` action from this screen, and preserve a deterministic selection state for the mini-map and details pane as filters change. [L1] [L2] [L3] [L5] [L6] [L7] [L8] [L9] [L10] [L11] [L12] [L13] [L14]

## User Stories

1. As a `My Peak Lists` user, I can toggle one or more manifest regions from the shared app bar so I only see peak lists applicable to those selected regions. [L1] [L2] [L3] [L5] [L9]
2. As a returning user, I reopen `My Peak Lists` and get the same region filter selection I last used, or all regions selected the first time I use the feature. [L4] [L10]
3. As a user reviewing list details and the `peak list mini-map`, I keep a valid selected list when filters change, or the selection clears cleanly when no matching lists remain. [L6] [L11]
4. As a user on narrower widths or larger text scales, I can still access every region control because the app bar stays on a single line, uses short labels first, and allows horizontal scrolling of the region FAB row when needed. [L8] [L13] [L14]

## Requirements

1. Use `region FAB` as the canonical term for this feature. On `My Peak Lists`, the permanent app-bar controls are backed by manifest regions, not countries. The visible `/peaks` region FAB set is every manifest region whose `showInPeakList` value is `true`, in manifest order. For this slice, that visible region set is `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia`. Do not collapse `Italy North East` and `Italy North West` into one `Italy` control. Regions whose `showInPeakList` value is `false` or missing do not appear in the FAB set. [L1]
2. On the `/peaks` route, render the region controls in the shared app bar lane on the left with the `My Peak Lists` title, not in the summary pane body. When the one-line layout fits, the first region FAB must sit immediately beside the `My Peak Lists` title. [L2]
3. Style the region FABs to match the existing Map screen peak-list app-bar controls rather than introducing a new control language. They are permanent controls for their manifest regions and must not show pin or unpin icons. [L1] [L2]
4. The region FABs are independent multi-select filters. Toggling one region must not clear other selected regions unless the user explicitly toggles them off. `My Peak Lists` must show the union of all peak lists applicable to the currently selected regions. [L3]
5. A peak list with a canonical manifest region is visible when its region matches any selected region. A `mixed-region peak list` is visible when at least one of its applicable regions is selected. Peak lists whose stored `region` is neither a manifest region nor `mixed` remain hidden in this slice. Do not add `Other` or `Unknown` region controls. [L5] [L9]
6. Persist the region filter locally across app restarts. When a saved selection exists, restore it when the user returns to `My Peak Lists`. When no saved selection exists yet, start with all six manifest regions selected. [L4] [L10]
7. All-off is a valid state. If the user turns every region FAB off, show no peak lists and do not silently restore all regions. Keep the empty state visible until the user re-enables at least one region. [L11]
8. When the current filter removes the currently selected peak list from the visible set, immediately select the first remaining visible peak list in the current filtered order. If no visible peak lists remain, clear the current selection. The summary pane, `peak list mini-map`, and details pane must update immediately to match the new selection state. [L6] [L11]
9. Remove the `Add New Peak List` action from `My Peak Lists` in this slice. Keep `Import Peak List` available and unchanged. Do not add a replacement create button, menu item, or app-bar action elsewhere on `My Peak Lists`. [L7]
10. Use manifest-backed region metadata fields `name`, `shortName`, and `showInPeakList` as the source of truth for `My Peak Lists` region FABs. Visible FAB text must come from `shortName`. For this slice, use these exact visible labels in the `My Peak Lists` app bar: `Tas`, `NSW`, `Italy NE`, `Italy NW`, `Slovenia`, and `Croatia`. Keep the full region names from `name` available for non-abbreviated uses. [L8]
11. Use the same accent palette language as the Map screen peak-list controls for the region FABs. Apply a fixed manifest-order mapping to the first six palette entries so the region colors stay stable: `Tas` -> palette entry 1, `NSW` -> entry 2, `Italy NE` -> entry 3, `Italy NW` -> entry 4, `Slovenia` -> entry 5, and `Croatia` -> entry 6. The visible region color must not depend on which peak lists currently match the filter. [L12]
12. Keep the `/peaks` app bar on a single line. When the title plus region FABs do not fit because of width or text scale, keep the `My Peak Lists` title left-aligned and allow horizontal scrolling of the region FAB row on the same line rather than wrapping onto a second line. Keep every region FAB reachable and tappable through that horizontal scroll behavior. [L2] [L13]
13. Use the short labels only for visible FAB text. Tooltip text and accessibility semantics must use the full manifest names `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia`. [L14]

## Technical Decisions

1. The region manifest is the source of truth for `My Peak Lists` region controls: control membership, full visible names, and short app-bar labels all come from manifest-backed region metadata rather than hard-coded route-local label tables. The exact manifest fields for this slice are `name`, `shortName`, and `showInPeakList`. The generated typed region catalog used by Flutter code must surface those fields so `/peaks` can derive the FAB set and labels without route-local exceptions. [L1] [L8] [L14]
2. Keep the `My Peak Lists` region filter as screen-specific UI state with local persistence, rather than reusing the Map screen's pinned or selected peak-list state. Persisted storage may reuse the project's existing local preference patterns, but the saved values are scoped to `My Peak Lists` region filtering only. [L3] [L4] [L10]
3. Reuse the existing peak-list control visual language and palette source for the new region FABs, but keep region selection semantics distinct from peak-list pinning and Map screen peak-list selection. [L3] [L12]
4. Responsive layout behavior for the `/peaks` shared app bar is route-specific: keep a single-line title-plus-controls layout, and when width or text scale is constrained, preserve the title on the left while the region FAB row remains on the same line with horizontal scrolling rather than wrapping. The `/peaks` region FAB content is supplied through the shared shell app-bar composition seam rather than being rendered inside the `PeakListsScreen` body. [L2] [L13]

## Testing Strategy

1. Extend `test/widget/peak_lists_screen_test.dart` with deterministic widget coverage for the persisted region filter contract: first-launch default to all regions, restore of previously saved selection through `SharedPreferences.setMockInitialValues`, independent toggling, all-off empty state, and visibility rules for canonical-region, mixed-region, and unsupported legacy-region peak lists. [L3] [L4] [L5] [L9] [L10] [L11]
2. Add widget coverage for filter-driven selection handoff on `My Peak Lists`: when the selected list is filtered out, the first remaining visible list becomes selected in filtered order; when no visible lists remain, selection clears and the mini-map/details state follows. [L6] [L11]
3. Extend shared-app-bar or `/peaks` route widget coverage to verify the new left-aligned title-plus-region-controls layout, including normal single-line fit behavior plus constrained-width or larger-text-scale horizontal scrolling of the region FAB row on the same line. Verify the layout does not wrap onto a second line and does not clip controls without a scroll path. Cover this at the shell-app-bar level, not only by pumping `PeakListsScreen` directly. Add stable selectors for the `/peaks` app-bar content container, the horizontal region FAB scroller, and each region FAB toggle. [L2] [L8] [L13]
4. Add widget assertions for visible label, tooltip, and semantics contracts: short visible labels, full-name tooltip text, and full-name accessibility semantics for each region FAB. [L8] [L14]
5. Extend widget coverage for the action changes on `My Peak Lists`: `peak-lists-add-list-fab` no longer exists, `peak-lists-import-fab` remains, and no replacement create control appears on that screen. [L7]
6. Add deterministic widget assertions for the fixed manifest-order color mapping so each region FAB resolves to the expected first-six palette entry regardless of which lists are visible. [L12]
7. Add deterministic catalog-level coverage for the manifest-backed contract in `test/unit/region_manifest_catalog_test.dart` or equivalent: `shortName` values are surfaced in the typed catalog, only regions with `showInPeakList == true` participate in the `/peaks` FAB set, regions with `showInPeakList` missing or `false` stay out of the FAB set, and the resulting FAB order follows manifest order.
8. Prefer existing fake repository seams plus mocked `SharedPreferences` over real network, real map services, or secrets. Widget coverage is expected to be sufficient for this slice; add robot coverage only if shared app bar behavior cannot be asserted reliably through existing keyed widgets and semantics.

## Out of Scope

1. Changing the Map screen peak-list selection, pinning, or app-bar summary behavior.
2. Adding an `All Regions`, `Other`, or `Unknown` app-bar control.
3. Adding a replacement create-peak-list entry point elsewhere on `My Peak Lists` in this slice.
4. Expanding legacy non-manifest region keys into new persisted region categories.

## Open Questions

1. If the shared palette utility is renamed now that both peak-list controls and region FABs use it, what exact generic symbol and file names should replace `peakListDefaultPalette` and `lib/services/peak_list_colour_resolver.dart` while still matching the repository's `colour` naming convention?

## Follow-Ups

1. During implementation, prefer a generic shared palette/resolver name if the existing peak-list-specific naming becomes misleading once region FABs also depend on the same palette source.

## Notes

1. The existing repository defines the current peak-list palette in `lib/services/peak_list_colour_resolver.dart`; this slice may reuse that source or rename it if the implementation chooses to resolve the shared naming question.
