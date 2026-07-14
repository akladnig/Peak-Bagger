---
type: Work Item
title: Manifest-Backed /peaks Region Filter State
parent: ../spec.md
---

## What to build

Extend the typed region manifest catalog so `/peaks` can derive its permanent `region FAB` set from manifest-backed metadata rather than route-local label tables, then add a `My Peak Lists`-scoped persisted multi-select region-filter state that defaults to all six visible manifest regions on first launch, restores the previously saved selection on later visits, keeps all-off as a valid persisted state, and applies the exact visibility contract for canonical manifest-region lists, `mixed-region peak lists`, and unsupported legacy-region lists. This slice owns the manifest-backed visible region list, local persistence contract, and filter-state semantics, but not the shared app-bar UI layout or the summary/details selection handoff.

## Required context

- `lib/services/region_manifest_catalog.dart` and `lib/generated/region_manifest_catalog.g.dart` are the typed manifest seam already consumed by Flutter code. Surface `name`, `shortName`, and `showInPeakList` here so `/peaks` can derive the FAB set in manifest order without route-local exceptions.
- `lib/services/peak_region_asset_import_service.dart` already reads the raw region manifest. Reuse the existing manifest source of truth rather than introducing a second parser or a hard-coded `/peaks` region table.
- `lib/services/peak_list_visibility.dart` already contains canonical-region normalization plus `mixed-region peak list` applicability logic. Extend or reuse that seam for `/peaks` filtering instead of duplicating region matching inside widgets.
- Follow the existing local-preference patterns used by providers such as `lib/providers/peak_list_mini_map_cluster_display_settings_provider.dart` for `SharedPreferences` loading and deterministic test injection.
- Extend `test/unit/region_manifest_catalog_test.dart` for typed-catalog coverage and `test/widget/peak_lists_screen_test.dart` for persisted filter-state and visibility coverage. Reuse `SharedPreferences.setMockInitialValues` and existing fake repository seams.

## Acceptance criteria

- [x] The typed region manifest catalog surfaces `name`, `shortName`, and `showInPeakList` for Flutter code, and `/peaks` derives its visible `region FAB` set exclusively from manifest regions whose `showInPeakList == true`, in manifest order.
- [x] For this slice, the derived `/peaks` visible region set is exactly `Tasmania`, `New South Wales`, `Italy North East`, `Italy North West`, `Slovenia`, and `Croatia`, and `Italy North East` plus `Italy North West` remain separate manifest-backed regions rather than one `Italy` control.
- [x] Regions whose `showInPeakList` value is `false` or missing do not participate in the `/peaks` visible `region FAB` set.
- [x] `My Peak Lists` owns a screen-specific persisted multi-select region-filter state that is scoped only to `/peaks` and does not reuse the Map screen's pinned or selected peak-list state.
- [x] When no saved `/peaks` region-filter selection exists yet, the initial selection is all six visible manifest regions selected. When a saved selection exists, `/peaks` restores that exact selection when the user returns to `My Peak Lists`.
- [x] Each `region FAB` toggles independently, toggling one region does not silently clear other selected regions, and the filter semantics represent the union of all currently selected regions.
- [x] All-off is a valid persisted state. If the user turns every region off, `/peaks` shows no peak lists and does not silently restore all regions until the user explicitly re-enables one or more regions.
- [x] A peak list with a canonical manifest region is visible when its region matches any selected region, a `mixed-region peak list` is visible when at least one of its applicable regions is selected, and peak lists whose stored `region` is neither a manifest region nor `mixed` remain hidden in this slice.
- [x] The `/peaks` region-filter implementation does not add `Other`, `Unknown`, or any other non-manifest control.
- [x] Unit coverage in `test/unit/region_manifest_catalog_test.dart` verifies that `shortName` values are surfaced in the typed catalog, only regions with `showInPeakList == true` participate in the `/peaks` `region FAB` set, regions with `showInPeakList` missing or `false` stay out of that set, and the resulting `/peaks` `region FAB` order follows manifest order.
- [x] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies first-launch default to all regions, restore of a previously saved selection through `SharedPreferences.setMockInitialValues`, independent toggling, all-off empty state, and visibility rules for canonical-region, `mixed-region peak list`, and unsupported legacy-region peak lists.

## Covers

- User Stories: 1-2
- Requirements: 1, 4-7, 10
- Technical Decisions: 1-2
- Testing Strategy: 1, 7-8
- Interview Ledger: L1, L3-L5, L8-L11

## Blocked by

None - ready to start
