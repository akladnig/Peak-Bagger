---
type: Work Item
title: Exact Visible Region Set Peak List Restore Persistence
parent: ../spec.md
---

## What to build

Implement exact normalized visible-region `Set<String>` save and restore for app-bar peak-list state inside the existing map-owned peak-list state boundary. Persist snapshots independently from per-region pins under one new versioned `SharedPreferences` key using a deterministic JSON array of records, restore exact selected and unselected specific-list state when the user returns to the same normalized visible-region set, preserve explicit `none` only when the user chose `none`, fall back to `All Peaks` only when no snapshot exists for that visible-region set, keep zero-region views from erasing snapshots or pins, and ignore missing or malformed snapshot payloads without disturbing current in-memory rendering, pins, or other map preferences.

## Required context

- `lib/providers/map_provider.dart` already owns peak-list selection mode, selected ids, previous specific ids, visible-region logic, and per-region pin persistence. Keep the new visible-region-set snapshot state alongside that lifecycle rather than introducing a second owner.
- `lib/widgets/peak_list_selection_summary.dart` renders the app-bar peak-list chips and already exposes stable `Key` selectors for selected, none, all-peaks, toggle, and pin actions that robot and widget tests can extend.
- `lib/widgets/map_peak_lists_drawer.dart` reflects visible-region filtering and pin behavior. Preserve existing drawer semantics and peak-list filtering while changing restore behavior only.
- `test/providers/map_peak_list_selection_persistence_test.dart` already covers v2 selection persistence and pinned ids by region, and is the right place to extend deterministic payload-shape, corruption, and restore coverage.
- Follow the existing robot conventions under `test/robot/`, using app-owned stable selectors and deterministic region-change seams rather than gesture timing, pixel diffs, or live map movement dependencies.

## Acceptance criteria

- [ ] Behavior-first TDD drives exact visible-region-set snapshot save, restore, fallback, malformed-payload handling, and pruning behavior before implementation is finalized.
- [ ] App-bar specific-list state is saved and restored by the exact normalized visible-region `Set<String>` for visible specific peak lists, and returning to a visible-region set restores that exact set's last remembered snapshot rather than reusing the most recently visible region set.
- [ ] Pinning remains a separate state machine from visible-region-set selection restore, and existing per-region pinned lists continue to behave as they do today.
- [ ] Snapshot state persists as either an exact `specificList` selection set or an explicit `none` mode chosen by the user, and `none` is restored only when the user explicitly chose `none` for that normalized visible-region set.
- [ ] When a normalized visible-region set has no remembered snapshot, the app falls back to `All Peaks`.
- [ ] Zero-region views render no app-bar peak-list buttons and do not erase remembered visible-region-set snapshots or per-region pins.
- [ ] Missing or malformed snapshot payloads fall back to no remembered visible-region-set snapshots without disturbing pins, camera preferences, or current in-memory map rendering.
- [ ] Snapshot state persists under one new versioned `SharedPreferences` key as a deterministic JSON array of records where each record contains `regions`, `mode`, and `ids` exactly as defined in the Spec, with sorted normalized region keys and sorted unique `peakListId` values when `mode == specificList`.
- [ ] Records with duplicate regions, unsupported modes, non-integer ids, or otherwise invalid shape are ignored during restore rather than blocking unrelated map state.
- [ ] Stale snapshot ids are pruned only after a successful peak-list repository read confirms they are invalid or missing.
- [ ] Provider tests cover saving one normalized visible-region-set snapshot without mutating another, restoring exact selected and unselected state for the same normalized visible-region set, preserving pins as a separate state machine, `All Peaks` fallback only when no snapshot exists, explicit `none` restore only when chosen by the user, zero-region button hiding without erasing remembered state, malformed or missing payload fallback, deterministic region ordering, deterministic `peakListId` ordering, corrupt-record ignore behavior, and stale-id pruning after a successful repository read.
- [ ] Widget tests cover the map app-bar peak-list row restoring exact visible-region-set state when visible bounds or visible region changes, while preserving existing drawer opening, drawer closing, map-route entry, back behavior, and peak-list filtering semantics.
- [ ] Robot or journey coverage extends the critical map flow where the user selects or deselects lists in one region, switches to another region, returns, and sees the app-bar state restore for the original region using stable app-owned selectors and deterministic region-change seams rather than gesture timing or pixel assertions.

## Covers

- User Stories: 4
- Requirements: 14-20, 24-25
- Technical Decisions: 2, 5-6
- Testing Strategy: 1, 3, 4.2, 5, 7
- Interview Ledger: L6

## Blocked by

None - ready to start
