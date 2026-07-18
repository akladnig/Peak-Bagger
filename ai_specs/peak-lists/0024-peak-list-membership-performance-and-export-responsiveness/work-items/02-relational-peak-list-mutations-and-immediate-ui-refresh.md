---
type: Work Item
title: Relational Peak List Mutations And Immediate UI Refresh
parent: ../spec.md
---

## What to build
Move peak-list membership mutation flows onto relational batch membership writes, including single add, remove, and points-edit operations plus picker multi-add, while preserving the current peak-list UI behavior, labels, confirmations, and the existing partial-success picker experience. After each membership edit, refresh the initiating peak-list surface immediately, keep current selection state consistent, keep list-level derived metadata aligned with the relational memberships, and refresh `Map` immediately only when it is visible.

## Required context
- `lib/widgets/peak_list_peak_dialog.dart`, `lib/screens/peak_lists_screen.dart`, `lib/providers/peak_list_provider.dart`, `lib/providers/map_provider.dart`, and `lib/providers/peak_list_selection_provider.dart` are the current UI and state seams for add, remove, points-edit, selected-list refresh, and map refresh behavior.
- `lib/services/peak_list_repository.dart` and related peak-list mutation services currently decode and rewrite `PeakList.peakList` JSON; this item should reuse the repository-centered mutation architecture while replacing the active membership path with relational writes and direct membership queries.
- `lib/services/peak_repository.dart` and the list-derived metadata paths already participate in keeping peak-list region and bounds aligned with membership changes; keep those derived fields sourced from the current relational memberships after migration.
- Follow the existing mutation and UI test seams in `test/services/peak_list_repository_test.dart`, `test/providers/peak_list_mutation_provider_test.dart`, `test/widget/peak_list_peak_dialog_test.dart`, and related provider override patterns. Do not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [x] Behavior-first TDD drives the relational membership mutation logic before final refresh wiring, covering single add, remove, and points-edit operations plus picker multi-add with preserved per-peak points values.
- [x] Single-peak add, delete, and points-edit operations in a normal existing peak list complete through relational membership writes without whole-list JSON rewrite behavior for small changes and meet the about 1 second local-use contract.
- [x] Multi-add from the peak picker persists as one logical list update rather than one full save per selected peak, while preserving the per-peak points values chosen in the picker and the current partial-success UX: valid additions remain saved, failed additions remain selected, and the dialog reports the failed peaks without discarding successful adds.
- [x] After a peak-list membership edit, the initiating peak-list surface updates immediately, including current list details, visible member count, points values, and current add or delete affordances, while preserving existing labels, confirmations, and other user-visible peak-list behavior not explicitly changed by the Spec.
- [x] If the edited list is currently selected, the selection state remains consistent immediately.
- [x] If `Map` is visible when the membership edit completes, peak-list-dependent map rendering refreshes immediately. If `Map` is not visible, the mutation does not wait on a full map marker reload before returning success and the map-dependent peak-list state refreshes when `Map` next becomes active or resumes.
- [x] Peak-list-derived metadata such as region and stored bounds stays consistent with the current relational memberships after migration and later membership mutations.
- [x] Focused unit, service, provider, and widget coverage proves the batch mutation paths, immediate initiating-surface refresh, visible-map-only synchronous refresh, off-screen non-blocking behavior, and preserved partial-success UX using existing test seams only.

## Covers
- User Stories: 1-2
- Requirements: 1, 4-5, 8-9, 19
- Technical Decisions: 3-4
- Testing Strategy: 1, 3-4, 6, 8
- Interview Ledger: L1-L3

## Blocked by
- `01-relational-peak-list-membership-startup-migration-and-readiness.md`
