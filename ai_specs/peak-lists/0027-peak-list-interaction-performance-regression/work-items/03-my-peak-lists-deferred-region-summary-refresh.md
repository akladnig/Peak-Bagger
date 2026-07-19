---
type: Work Item
title: My Peak Lists Deferred Region Summary Refresh
parent: ../spec.md
---

## What to build

Move `My Peak Lists` region-filter visibility checks and membership-derived summary-row recomputation out of repeated synchronous widget-build reads and behind an app-owned deferred refresh seam. `Region FAB` taps must acknowledge the latest accepted region selection immediately, while the summary pane, selected list handoff, and other membership-derived `My Peak Lists` content settle shortly after to the correct final state for the latest accepted filter without stale recomputation overwriting newer results.

## Required context

- `lib/screens/peak_lists_screen.dart` currently owns `My Peak Lists` summary-row derivation, selected-list handoff, and repeated synchronous visibility and item reads inside `build`. Keep this slice vertical through that screen and its existing state boundary unless a small reusable seam is clearly justified.
- `lib/providers/peak_list_region_filter_provider.dart` already owns persisted `Region FAB` state. Preserve its current manifest-backed selection semantics and use it as the immediate accepted control-state source.
- `lib/services/peak_list_visibility.dart` already contains canonical-region normalization and `mixed-region peak list` applicability logic. Reuse that seam rather than changing region-filter semantics.
- Existing deterministic coverage in `test/widget/peak_lists_screen_test.dart` already exercises `Region FAB` behavior, selection handoff, empty-state rendering, and `peak list mini-map` updates through fake repositories and mocked `SharedPreferences`.
- Keep automated verification local and deterministic with in-memory repositories, provider overrides, and test-controlled deferred completion seams only. Final signoff still requires real migrated local post-`0024` data verification.

## Acceptance criteria

- [x] Tapping a `My Peak Lists` app-bar `Region FAB` updates the newly accepted control state immediately without synchronously waiting for per-list membership reads or full summary derivation.
- [x] Membership-derived visible-list filtering, summary rows, selected-list handoff, and related `My Peak Lists` content refresh after the immediate control-state acknowledgment through an app-owned deferred seam.
- [x] The settled `My Peak Lists` screen preserves current region-filter semantics, labels, empty-state behavior, selected-list handoff behavior, `peak list mini-map` behavior, and details-pane behavior.
- [x] Rapid consecutive `Region FAB` changes follow `latest interaction wins`, and stale queued or in-flight summary recomputations cannot overwrite the latest accepted region selection or newer settled content.
- [x] The implementation does not add new spinner copy, progress copy, or disabled `Region FAB` behavior unless a temporary correctness guard is proven strictly necessary.
- [x] Deterministic widget or provider coverage proves rapid `Region FAB` changes keep controls responsive, supersede stale deferred completions, and settle to the correct latest screen state without relying on wall-clock latency assertions.
- [x] Automated coverage remains local and deterministic with fake repositories, provider overrides, mocked `SharedPreferences`, and existing `PeakListsScreen` seams only.
- [ ] Final manual verification for this slice is performed against the existing real migrated local post-`0024` data that reproduces the slowdown, confirming near-immediate `Region FAB` feedback and correct settled summaries on the normal development machine.

## Covers

- User Stories: 3, 4
- Requirements: 1-6, 9-12
- Technical Decisions: 1-2, 4-6
- Testing Strategy: 2-6
- Interview Ledger: L1-L3, L5-L8

## Blocked by

None - ready to start
