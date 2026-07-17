---
type: Work Item
title: Mixed-Region Peak List Visibility Selection and Pinning
parent: ../spec.md
---

## What to build
Apply the persisted `mixed` list semantics across the existing Flutter peak-list visibility, selection, and pinning seams so a `Mixed-region peak list` appears in every visible canonical member region where it has member peaks, remains one selectable and pinnable list entry in the UI, and persists its pinned state across every represented canonical member region instead of behaving like a single stored-region list.

## Required context
- `lib/services/peak_list_visibility.dart`, `lib/providers/peak_list_selection_provider.dart`, and `lib/providers/map_provider.dart` already contain mixed-list handling seams. Extend those seams instead of adding a new top-level Flutter feature surface.
- `lib/models/peak_list.dart` defines the persisted sentinel `PeakList.mixedRegion`. `lib/services/peak_list_derived_data.dart` already derives mixed classification from member peaks and is a useful reference for canonical-member-region behavior.
- Reuse existing fake repositories and state seams in `test/providers/map_peak_list_selection_state_test.dart`, `test/providers/peak_list_selection_provider_test.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/map/peak_list_pins_journey_test.dart` where applicable.
- Follow `GLOSSARY.md` terminology, especially `Mixed-region peak list`.

## Acceptance criteria
- [x] A persisted `PeakList.region = mixed` list appears in every visible region where at least one member peak belongs. Visibility comes from canonical member-peak regions rather than one stored `PeakList.region` value alone.
- [x] Selection behavior for persisted `mixed` lists derives from member peaks and existing visibility seams such as `peak_list_visibility.dart` and `peak_list_selection_provider.dart`, not from treating `mixed` as a visible region choice.
- [x] Pinning a persisted `mixed` list persists that pin for every canonical member region represented by peaks in the list, and unpinning removes the pin for every canonical member region represented by peaks in the list.
- [x] The UI still presents one selectable and pinnable list entry for a persisted `mixed` list rather than duplicating the same list once per region.
- [x] Existing single-region behavior remains unchanged for peak lists whose persisted region is not `mixed`.
- [x] Behavior-first TDD drives this item. Provider or widget coverage proves mixed-list visibility, selection, and pinning across visible canonical regions using fake repositories and deterministic member-peak fixtures. Add robot coverage only where it exercises an existing stable selector path without broad UI rewrites.

## Covers
- User Stories: 4
- Requirements: 16-20
- Technical Decisions: 5, 6
- Testing Strategy: 1, 8, 10
- Interview Ledger: L5, L9-L10

## Blocked by
None - ready to start
