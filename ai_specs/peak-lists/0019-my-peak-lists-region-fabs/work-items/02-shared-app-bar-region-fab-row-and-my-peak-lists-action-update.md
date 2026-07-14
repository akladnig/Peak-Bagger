---
type: Work Item
title: Shared App-Bar Region FAB Row And My Peak Lists Action Update
parent: ../spec.md
---

## What to build

Add the permanent `/peaks` `region FAB` row through the shared shell app-bar seam so the `My Peak Lists` title stays on the left and the first `region FAB` sits immediately beside that title when the one-line layout fits. Reuse the existing Map screen peak-list control visual language and accent palette for these controls, expose exact manifest-backed short labels with full-name tooltip and accessibility semantics, keep the app bar on a single line with horizontal scrolling of the FAB row when width or text scale is constrained, remove the `Add New Peak List` action from `My Peak Lists`, and keep `Import Peak List` available and otherwise unchanged.

## Required context

- `lib/router.dart` owns the shared shell app bar, including `Key('shared-app-bar')` and `Key('app-bar-title')`. Supply the `/peaks` title-plus-controls lane through this seam rather than rendering the `region FAB` row inside the `PeakListsScreen` body.
- `lib/widgets/peak_list_selection_summary.dart` and `lib/widgets/peak_list_control_visual_style.dart` show the existing Map screen peak-list app-bar control language that this slice must match instead of inventing a new control family.
- The palette naming question is resolved for this workflow: rename `lib/services/peak_list_colour_resolver.dart` to `lib/services/fab_colour_resolver.dart` and rename `peakListDefaultPalette` to `defaultFABPalette`, preserving the repository's `colour` spelling while updating current imports and consumers.
- Current peak-list palette consumers live in `lib/services/peak_list_repository.dart`, `lib/providers/peak_list_selection_provider.dart`, and `lib/widgets/map_peak_lists_drawer.dart`. Keep their existing behavior while moving shared palette ownership to the resolved generic naming.
- Existing shell-app-bar widget coverage already uses `Key('shared-app-bar')` and `Key('app-bar-title')` in tests such as `test/widget/map_peak_list_selection_test.dart`, `test/widget/map_screen_appbar_search_test.dart`, and `test/widget/peak_lists_screen_test.dart`. Extend that shell-level pattern for `/peaks` instead of testing only a body-level widget subtree.

## Acceptance criteria

- [x] On the `/peaks` route, the permanent `region FAB` row renders in the shared app bar lane on the left with the `My Peak Lists` title rather than in the `PeakListsScreen` body.
- [x] When the one-line layout fits, the first `region FAB` sits immediately beside the `My Peak Lists` title.
- [x] The `/peaks` app bar stays on a single line. When the title plus `region FAB` row do not fit because of width or text scale, the title remains left-aligned and the `region FAB` row stays on the same line with horizontal scrolling rather than wrapping onto a second line.
- [x] Every `/peaks` `region FAB` remains reachable and tappable through that horizontal scroll behavior on constrained widths or larger text scales.
- [x] The `region FAB`s use the same control visual language as the existing Map screen peak-list app-bar controls and do not show pin or unpin icons.
- [x] Visible `/peaks` `region FAB` text uses the exact manifest-backed short labels `Tas`, `NSW`, `Italy NE`, `Italy NW`, `Slovenia`, and `Croatia`.
- [x] Tooltip text and accessibility semantics use the full manifest names `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia` rather than the abbreviated visible labels.
- [x] `/peaks` `region FAB` colours use the same accent palette language as the Map screen peak-list controls with a fixed manifest-order mapping: `Tas` -> palette entry 1, `NSW` -> entry 2, `Italy NE` -> entry 3, `Italy NW` -> entry 4, `Slovenia` -> entry 5, and `Croatia` -> entry 6, independent of which lists currently match the filter.
- [x] The shared palette utility is renamed to `lib/services/fab_colour_resolver.dart`, `peakListDefaultPalette` is renamed to `defaultFABPalette`, and existing palette consumers continue to resolve colours through the renamed shared seam without changing current colour behavior outside this slice.
- [x] `My Peak Lists` no longer shows the `Add New Peak List` action, `peak-lists-add-list-fab` no longer exists on that screen, `Import Peak List` remains available through `peak-lists-import-fab`, and no replacement create control appears elsewhere on `My Peak Lists`.
- [x] Stable selectors exist for the `/peaks` shared-app-bar content container, the horizontal `region FAB` scroller, and each `region FAB` toggle so widget coverage can assert layout and state deterministically.
- [x] Shell-level widget coverage verifies the left-aligned title-plus-controls layout, single-line fit behavior, constrained-width or larger-text-scale horizontal scrolling on the same line, no wrap onto a second line, exact visible labels, full-name tooltip and semantics contracts, `peak-lists-add-list-fab` removal, `peak-lists-import-fab` retention, and the fixed manifest-order colour mapping.
- [x] Testing stays widget-first for this slice. Add robot coverage only if shared app-bar behavior cannot be asserted reliably through existing keyed widgets and semantics.

## Covers

- User Stories: 1, 4
- Requirements: 2-3, 9-13
- Technical Decisions: 3-4
- Testing Strategy: 3-6, 8
- Interview Ledger: L1-L2, L7-L8, L12-L14

## Blocked by

- `01-manifest-backed-peaks-region-filter-state.md`
