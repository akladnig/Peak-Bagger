---
type: Spec
title: Peak Ownership Ring Display
---

## Problem

Peak rendering on the map does not currently match the intended list-ownership display contract. The project expects a `Peak ownership ring` to make visible peak-list ownership understandable on map markers and clusters, but the current rendering does not provide that behavior. Separately, when the visible region changes, the map app bar does not restore the prior selected and unselected peak-list button state for that region, so list controls drift away from the user's earlier region-specific context. [L1] [L5] [L6]

## Proposed Outcome

Add a configurable individual-peak `Peak ownership ring` display to the main Flutter map route while keeping cluster rings always visible there. Individual peaks gain equal-segment ownership rings only when more than one currently selected app-bar list applies, single-list peaks remain plain triangles, and clusters use a hybrid ring that keeps the ticked share green while segmenting the unticked share by currently selected app-bar lists represented by unticked peaks in the cluster. Add a persisted Settings toggle for individual rings, preserve the agreed Tasmania fallback triangle precedence when individual rings are off, and restore exact visible-region-set app-bar peak-list state when the user returns to the same normalized visible-region set. [L1] [L2] [L3] [L5] [L6]

## User Stories

1. As a map user, I can tell when an individual peak belongs to multiple visible peak lists because it shows an equal-segment `Peak ownership ring`, while a single-list peak stays visually simple as the existing triangle. [L1] [L2]
2. As a map user, I can keep cluster-level ownership context at all times because cluster rings always remain visible and still preserve the existing green tick summary for the ticked share. [L1] [L3] [L5]
3. As a map user, I can turn off individual peak ownership rings in Settings and still get meaningful unticked triangle colouring, including the explicit Tasmania precedence contract. [L3]
4. As a map user who switches between visible-region sets, I see the app-bar peak-list buttons return to the same selected and unselected state that exact normalized visible-region set had before, instead of inheriting the last visible-region set's transient selection state. [L6]

## Requirements

1. Use `Peak ownership ring` as the canonical term for the segmented ring that shows visible peak-list ownership on both individual peak markers and peak clusters. [L1]
2. Preserve the current peak marker triangle shape, current white triangle outline, existing peak interactions, and the current green meaning for ticked individual peaks unless a narrower implementation seam requires additive rendering metadata only. [L2] [L5]
3. An individual peak may render a `Peak ownership ring` only when all of these are true: the individual-ring setting is enabled, the peak is visible on the main map route, and the peak belongs to more than one currently selected app-bar peak list. [L2] [L3]
4. An individual peak `Peak ownership ring` must split into equal segments, one segment per currently selected app-bar peak list that owns the peak. Do not size individual segments by peak counts, points, prominence, or list order. [L2]
5. If an individual peak belongs to exactly one visible owning peak list, show only the triangle and no individual ring. [L2]
6. If an individual peak belongs to no visible owning peak lists, show only the triangle and no individual ring. [L2]
7. Add a persisted Settings control on `SettingsScreen` for enabling and disabling the individual `Peak ownership ring` display on the main map route. The recommended visible label is `Show Peak Ownership Rings`. [L3]
8. The individual-ring setting affects only individual peak markers. Peak clusters must continue to show a ring even when the individual-ring setting is off. [L3] [L5]
9. When the individual-ring setting is off, unticked individual peaks in Tasmania must use this explicit peak-list precedence when more than one visible list applies: `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full`. The first matching visible list in that order wins the triangle colour. [L3]
10. When the individual-ring setting is off outside Tasmania, unticked individual peaks must use the visible matching list colour with the lowest `peakListId`, preserving the existing non-Tasmania visible-list precedence rule. [L3]
11. Ticked individual peaks remain green regardless of region or the individual-ring setting. When a ticked individual peak also has more than one visible owning list and the setting is enabled, the green triangle may still carry the equal-segment ownership ring around it. [L2] [L3]
12. Cluster `Peak ownership rings` on the main map route must use a hybrid contract:
    1. The ticked share remains one solid green aggregate arc sized by the number of ticked peaks in the cluster.
    2. Only the unticked remainder is segmented by currently selected app-bar peak lists represented by unticked peaks in the cluster.
    3. Unticked list segments are equal per contributing selected list, not proportional to unticked counts per list.
    4. If a cluster has no unticked peaks, the ring is fully green.
    5. If a cluster has no ticked peaks, the ring is fully list-segmented. [L5]
13. This slice must not try to preserve per-list ownership inside the green ticked cluster arc. Ticked cluster ownership is intentionally collapsed into one aggregate green share in this version. [L5]
14. Save and restore app-bar peak-list state by exact normalized visible-region `Set<String>` for visible specific peak lists. Returning to a visible-region set must restore that exact set's last remembered snapshot rather than reusing whichever visible-region set was visible most recently. [L6]
15. Keep pinning as a separate state machine from visible-region-set selection restore. Existing per-region pinned lists continue to behave as they do today, while selected and unselected state is restored independently for the re-entered normalized visible-region set. [L6]
16. Persist visible-region-set restore snapshots as either an exact `specificList` selection set or an explicit `none` mode chosen by the user. Do not treat `none` as an automatic fallback. When a normalized visible-region set has no remembered snapshot, fall back to `All Peaks`. [L6]
17. Zero-region views must render no app-bar peak-list buttons, but they must not erase remembered visible-region-set snapshots or per-region pins. [L6]
18. Preserve current drawer opening, drawer closing, map-route entry, back behavior, and peak-list filtering semantics. The change in this slice is the rendering contract plus region-specific restoration of app-bar specific-list state, not a redesign of selection or navigation flows. [L3] [L6]
19. The individual-ring setting and the restored region-specific app-bar state must remain readable and usable on desktop and mobile layouts and at large text scale, reusing the project's existing constrained-width app-bar and Settings patterns where possible.
20. If Settings preference load or save fails, keep the last in-memory value or default and do not block map rendering or visible-region-set restoration.
21. Build ring segments only from peak lists that are currently selected in the app bar for the active map state. Hidden, unselected, pinned-only, or otherwise inactive lists must not contribute ownership-ring segments. [L2] [L5] [L6]
22. For both individual peaks and cluster unticked segments, segment order must start at 12 o'clock and proceed clockwise. Apply the current app-owned list-priority contract to that clockwise ordering: Tasmania keeps the explicit precedence `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full`, and non-Tasmania ordering continues to fall back to ascending `peakListId` in this slice. Broader region-specific ordering remains a future requirement. [L3]
23. This slice applies the `Peak ownership ring` rendering contract to the main map route only. Peak-list mini-maps remain unchanged in this slice because they render a single selected peak list rather than multi-list visible ownership, and their cluster rings keep the prior proportional ticked and unticked split instead of adopting the main-map ownership-ring contract.
24. If persisted visible-region-set snapshot data is missing or malformed, default to no remembered visible-region-set snapshots without disturbing pins, camera preferences, or current in-memory map rendering. Prune stale snapshot ids only after a successful peak-list repository read confirms they are invalid or missing. [L6]
25. Persist visible-region-set snapshot state under one new versioned `SharedPreferences` key. Store snapshots as a deterministic JSON array of records. Each record must contain:
    1. `regions`: a sorted array of normalized visible-region keys representing one exact visible-region `Set<String>`
    2. `mode`: either `specificList` or `none`
    3. `ids`: a sorted array of unique `peakListId` values only when `mode == specificList`
   Records with duplicate regions, unsupported modes, non-integer ids, or otherwise invalid shape must be ignored during restore rather than blocking unrelated map state. Missing or malformed snapshot payloads must fall back to no remembered visible-region-set snapshots. [L6]

## Technical Decisions

1. Keep `Peak ownership ring` rendering behind a deterministic presentation seam that can describe individual marker rings, fallback triangle colours, segment membership, segment order, and cluster ring segments without requiring pixel-only assertions. Prefer extending the existing peak projection, cluster, and marker presentation model rather than duplicating painter-only logic in multiple widgets. [L1] [L2] [L5]
2. Reuse the existing map-owned peak-list state boundary in `mapProvider` for visible-region-set app-bar restore. Store the new normalized visible-region `Set<String>` snapshot state alongside the existing peak-list selection and per-region pin persistence lifecycle rather than introducing a second unrelated owner. Persist exact visible-region-set snapshots independently from per-region pins. [L6]
3. Implement the individual-ring toggle with the existing Riverpod plus `SharedPreferences` settings pattern already used elsewhere in the app. Keep the map rendering code dependent on provider state, not directly on preference IO. [L3]
4. Treat the Tasmania triangle precedence and ring-segment ordering precedence as app-owned configuration for this slice. Do not hard-code similar precedence rules for every region yet; instead, keep the current non-Tasmania lowest-`peakListId` fallback outside Tasmania and preserve room for a later data-driven mechanism. [L3]
5. Reuse the existing peak-list colour source of truth and selected-list membership rules from the current peak-list colour and selection features. This slice changes how ownership is presented on the main map and how visible-region-set app-bar state restores, not which lists are considered selected or how colours are authored. [L2] [L3] [L6]
6. Encode visible-region-set restore snapshots as deterministic JSON records rather than ad hoc joined-string keys. Normalize each snapshot by sorting region keys and sorting `peakListId` values before persistence so exact visible-region-set identity, restore behavior, and tests remain stable. [L6]

## Testing Strategy

1. Use behavior-first TDD for the new ownership-ring presentation rules, the Tasmania precedence fallback resolver, the individual-ring setting state, and the exact visible-region-set app-bar restore state.
2. Add unit or provider coverage for the marker and cluster presentation rules, including:
   1. no individual ring for zero currently selected owning lists
   2. no individual ring for exactly one currently selected owning list
   3. equal-segment individual ring generation for multi-list currently selected ownership
   4. ticked individual peak remaining green while still allowing multi-list ring overlay when enabled
   5. Tasmania precedence resolution when individual rings are off
   6. non-Tasmania lowest-`peakListId` fallback when individual rings are off
   7. cluster hybrid ring generation with green ticked share and equal unticked list segments derived only from currently selected lists represented by unticked cluster members
   8. deterministic segment ordering starting at 12 o'clock and proceeding clockwise under the current Tasmania and non-Tasmania priority rules [L2] [L3] [L5]
3. Add provider coverage for visible-region-set app-bar restore behavior, including:
   1. saving a snapshot for one normalized visible-region set without mutating another
   2. restoring exact selected and unselected state when returning to the same normalized visible-region set
   3. preserving pins as a separate state machine
   4. `All Peaks` acting as fallback only when no visible-region-set snapshot exists
   5. explicit `none` snapshots restoring only when the user chose `none`, not as automatic fallback
   6. zero-region views hiding app-bar buttons without erasing remembered visible-region-set state
   7. malformed or missing visible-region-set snapshot payloads falling back safely without disturbing pin persistence [L6]
4. Add widget coverage for:
   1. the `SettingsScreen` toggle and its persisted rebuild behavior
   2. the map app-bar peak-list row restoring exact visible-region-set state when visible bounds or visible region changes
   3. the main map peak presentation seam or widget path that shows no ring for single-list individual peaks, shows a ring for multi-list individual peaks, and keeps cluster rings visible when the setting is off [L2] [L3] [L4] [L5]
5. Extend adjacent robot or journey coverage for the critical map flow where practical: select or deselect lists in one region, switch to another region, return, and verify the app-bar state restores for the original region. Use stable app-owned selectors and deterministic region-change seams rather than gesture timing or pixel-diff assertions. [L6]
6. Prefer deterministic fakes, provider overrides, and presentation-model assertions over screenshot-only testing for ring segments. Add stable selectors only where current app-owned keys are insufficient for the new setting or restore flow.
7. Add persistence coverage for the visible-region-set snapshot payload shape, including deterministic region ordering, deterministic `peakListId` ordering, corrupt-record ignore behavior, missing-payload fallback, and stale-id pruning after a successful peak-list repository read. [L6]

## Out of Scope

1. Redesigning peak-list visibility rules, pin semantics, or drawer navigation beyond what is required to restore visible-region-set app-bar state. [L6]
2. Replacing the existing green tick meaning for individual peaks or removing cluster rings. [L3] [L5]
3. Generalizing the Tasmania precedence rule into a full cross-region precedence editor or user-facing configuration UI in this slice. [L3]
4. Preserving per-list ownership detail inside the green ticked portion of cluster rings. [L5]
5. Changing peak-list mini-map rendering to adopt the main-map ownership-ring contract in this slice. Peak-list mini-map clusters keep their prior proportional ticked and unticked ring display.

## Follow-Ups

1. Replace the Tasmania-only hard-coded individual triangle precedence with a more scalable app-owned mechanism as additional regional peak lists are added. [L3]

## Notes

1. This slice extends the existing peak-list colour and app-bar pin work already captured in `ai_specs/peak-lists/0001-peak-list-colours/spec.md` and `ai_specs/peak-lists/peak-list-pins-spec.md`.
2. `GLOSSARY.md` now defines `Peak ownership ring` as the canonical project term for this rendering concept. [L1]
3. Relevant code paths already identified during the interview include `lib/screens/map_screen_peak_layer.dart`, `lib/services/peak_cluster_engine.dart`, `lib/widgets/peak_list_selection_summary.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `lib/providers/map_provider.dart`, and `lib/providers/peak_list_selection_provider.dart`.
