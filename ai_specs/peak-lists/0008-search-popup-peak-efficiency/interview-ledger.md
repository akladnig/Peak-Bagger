---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this work be scoped to the map `Search popup` Peaks entity path only, with tracks/routes/maps behavior and unrelated peak-picking/search surfaces left unchanged?

Recommended Answer:
- Scope only the map `Search popup` Peaks path.
- Keep `Tracks/Routes`, `Maps`, disabled `Natural/Roads`, and other non-popup peak pickers unchanged.
- Keep the current visible UX contract: same entry points, filters, sort/group controls, result selection behavior, and empty/helper states.

Answer: agreed

Decision: The performance slice is scoped to the map `Search popup` and must not redesign unrelated search or picker surfaces. 

Reason: This isolates the slowest path first and avoids mixing popup performance work with broader search behavior changes.

### L2

Status: current

Question: In the `Search popup`, should peak results switch to incremental loading with an initial page and more results appended as the user scrolls?

Recommended Answer:
- Replace the hard final cap with incremental loading.
- Show the first `20` sorted results immediately.
- Append the next `20` when the user scrolls near the bottom.
- Reset paging to the first `20` whenever the query, entity filter, region filter, sort, or group changes, and when the popup closes.
- Keep the current helper and empty states unchanged.
- Show a small inline loading-more state at the bottom only while the next page is being prepared.

Answer: agreed

Decision: The `Search popup` must replace the hard final cap with incremental loading in pages of `20`, with paging reset on popup state changes and close.

### L3

Status: current

Question: In `All` mode, should lazy loading preserve one combined sorted result list across Peaks, Tracks/Routes, and Maps?

Recommended Answer:
- Preserve one combined globally sorted result list for the active query, entity filter, region filter, and sort.
- In `All` mode, the first and later pages may contain any mix of peaks, tracks, routes, and maps.
- Do not force peak rows into a separate trailing block.
- Keep current grouping semantics unchanged.

Answer: agreed

Decision: Lazy loading must preserve one combined globally sorted `Search popup` result list, including in `All` mode.

Reason: This keeps the user-facing meaning of `All` stable while allowing internal peak optimization.

### L4

Status: current

Question: For peak performance in the `Search popup`, should we optimize by limiting and paging peak candidates before expensive map/region enrichment, even if that means the repository/API adds a popup-specific peak search path instead of reusing the current generic `PeakRepository.searchPeaks()` method?

Recommended Answer:
- Yes: add a `Search popup`-specific peak lookup path that supports ordered paging before enrichment.
- Keep `PeakRepository.searchPeaks()` unchanged for other existing surfaces unless they are migrated later.
- The popup-specific path should find matching peak candidates, apply the active region filter as early as practical, sort candidates in the required popup order, and return only the requested page window for enrichment/rendering.
- Enrich only the current page of peak candidates.

Answer: agreed

Decision: The `Search popup` needs its own paged peak candidate path rather than routing through the current generic full-scan `PeakRepository.searchPeaks()` path.

Reason: The current shared path scans and enriches too broadly for popup use.

### L5

Status: current

Question: Should peak matching in the `Search popup` keep the current visible search semantics, or tighten to a faster but narrower rule such as prefix-only matching?

Recommended Answer:
- Keep the current visible peak-match behavior.
- Preserve case-insensitive substring matching on peak name.
- Preserve current elevation-text matching behavior if it already applies to peaks.
- Do not change what counts as a match in this slice.

Answer: agreed

Decision: The `Search popup` peak-efficiency slice must preserve current user-visible peak matching semantics.

Negative Requirements:
- Do not switch to prefix-only matching.
- Do not change result relevance rules or query syntax in this slice.

### L6

Status: current

Question: For the popup-specific peak path, should the `Search popup` use the existing storage-backed peak-name query as its source of truth instead of scanning every peak in memory, even if elevation-text matching needs a small separate fallback path?

Recommended Answer:
- Yes: make the popup-specific peak path storage-backed first.
- Use a popup-specific repository/storage API that can query peak names case-insensitively, return candidates in deterministic popup order, and support paging/windowing.
- Preserve visible search semantics by keeping any required elevation-text matching through a separate narrow fallback path rather than forcing the main path back to a full scan.
- Extend both `ObjectBoxPeakStorage` and `InMemoryPeakStorage` with the same popup-specific seam.

Answer: agreed

Decision: Popup peak candidate lookup must be storage-backed first, with deterministic paging seams in both ObjectBox and in-memory test storage.

Reason: The codebase already has a storage-backed name query, so popup performance should build on that rather than full in-memory scans.

### L7

Status: current

Question: Should the new popup-efficiency spec explicitly supersede the existing `Search popup` `20` total results contract and replace it with incremental loading for all active entity modes, including `All`?

Recommended Answer:
- Yes: explicitly replace the old fixed `20`-result cap contract with incremental loading.
- The first page shows `20` results and each later page appends `20` more.
- This applies to `Peaks`, `Tracks/Routes`, `Maps`, and `All`.
- Sorting and filtering semantics stay unchanged.
- Query, filter, sort, or group changes reset paging to page 1.
- Keep the under-threshold guard unchanged.

Answer: agreed

Decision: The new efficiency spec must explicitly supersede the older fixed `20`-result `Search popup` contract for all active entity modes.

Reason: Without an explicit supersession, the spec set would contradict itself and implementation/tests would drift.
