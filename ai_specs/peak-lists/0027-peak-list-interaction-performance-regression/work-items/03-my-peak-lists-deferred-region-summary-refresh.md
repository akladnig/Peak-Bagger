---
type: Work Item
title: Restore My Peak Lists Region-Filter Responsiveness
parent: ../spec.md
---

## What to build

Restore responsive `My Peak Lists` region-filter interaction by keeping `Region FAB` taps on the immediate accepted-state path while moving membership-derived visible-list filtering and summary-row recomputation behind the existing app-owned deferred refresh seam. The summary pane, selected list handoff, and related `My Peak Lists` content may settle shortly after, but they must converge to the correct final state for the latest accepted region selection without stale recomputation overwriting newer results.

## Required context

- `lib/screens/peak_lists_screen.dart` currently owns `My Peak Lists` summary-row derivation, selected-list handoff, and the deferred summary-refresh seam. Keep this slice vertical through that screen and its existing state boundary unless a small reusable seam is clearly justified.
- `lib/providers/peak_list_region_filter_provider.dart` already owns persisted `Region FAB` state. Preserve its current manifest-backed selection semantics and use it as the immediate accepted control-state source.
- `lib/services/peak_list_visibility.dart` already contains canonical-region normalization and `mixed-region peak list` applicability logic. Reuse that seam rather than changing region-filter semantics.
- Existing deterministic coverage in `test/widget/peak_lists_screen_test.dart` already exercises `Region FAB` behavior, selection handoff, empty-state rendering, `Peak list mini-map` updates, and stale-work supersession through fake repositories and mocked `SharedPreferences`.
- Keep automated verification local and deterministic with in-memory repositories, provider overrides, and test-controlled deferred completion seams only. Final signoff still requires real migrated local post-`0024` data verification.

## Acceptance criteria

- [ ] Tapping a `My Peak Lists` app-bar `Region FAB` updates the newly accepted control state immediately without synchronously waiting for per-list membership reads or full summary derivation.
- [ ] Membership-derived visible-list filtering, summary rows, selected-list handoff, and related `My Peak Lists` content refresh after the immediate control-state acknowledgment through an app-owned deferred seam.
- [ ] The settled `My Peak Lists` screen preserves current region-filter semantics, labels, empty-state behavior, selected-list handoff behavior, `Peak list mini-map` behavior, and details-pane behavior.
- [ ] During the deferred refresh window, the accepted `Region FAB` state updates immediately while previously settled summary content may remain visible until the latest refresh finishes; no new placeholder, spinner copy, or disabled-control contract is introduced unless correctness proves it necessary.
- [ ] Rapid consecutive `Region FAB` changes follow `latest interaction wins`, and stale queued or in-flight summary recomputations cannot overwrite the latest accepted region selection or newer settled content.
- [ ] Deterministic widget or provider coverage proves rapid `Region FAB` changes keep controls responsive, supersede stale deferred completions, and settle to the correct latest screen state without relying on wall-clock latency assertions.
- [ ] Final manual verification is performed against the existing real migrated local post-`0024` data that reproduces the slowdown, confirming near-immediate `Region FAB` feedback and correct settled summaries on the normal development machine.

## Covers

- User Stories: 3, 4
- Requirements: 1-6, 9-12
- Technical Decisions: 1-2, 4-6
- Testing Strategy: 1, 3-8
- Interview Ledger: L1-L3, L5-L8

## Blocked by

None - ready to start
