---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which recent changes should define the authoritative regression baseline for this follow-up?

Recommended Answer:
- Anchor the review on `#158`, `#159`, and the relevant `#160` map-state changes.
- Keep `#148` as background only.
- Preserve both the earlier responsiveness contract and the later corrected add-flow contract.

Answer: i meant 158 not 148

Decision: Treat `#158`, `#159`, and the relevant current `#160` map-state contract as the authoritative regression baseline for this follow-up, with `#148` treated as background only.

Reason: The follow-up needs the correct source-history boundary before requirements or verification can be written safely.

### L2

Status: current

Question: Should this follow-up stay narrowly scoped to `My Peak Lists` `Add New Peak`, or expand back to the broader responsiveness regression surfaces?

Recommended Answer:
- Expand the follow-up to cover both `My Peak Lists` `Add New Peak` correctness and restored broader responsiveness.
- Preserve the existing responsiveness contract for `Map` pan and zoom, `Map` `Peak Lists` drawer taps, and `My Peak Lists` `Region FAB` taps.
- Keep peak-list import and export unchanged.

Answer: agreed. The peak-list import & export is also working as expected.

Decision: Expand this follow-up to cover both `My Peak Lists` `Add New Peak` correctness and restored broader responsiveness, while keeping current peak-list import and export behavior unchanged.

### L3

Status: current

Question: After a successful `My Peak Lists` `Add New Peak` save, should the details pane wait for a full synchronous recompute before the dialog closes?

Recommended Answer:
- Close the `Add New Peak` dialog as soon as the in-place save succeeds.
- Keep the same selected `PeakList` identity and selected title immediately.
- Refresh the details pane through the existing deferred `My Peak Lists` summary path rather than forcing a synchronous full recompute.
- Do not add new loading copy, spinners, or disabled-state UI for this refresh.

Answer: agreed.

Decision: A successful `Add New Peak` save closes immediately, preserves the same selected list identity and title, and refreshes through the existing deferred `My Peak Lists` summary path rather than a synchronous full recompute.

Negative Requirements:
- Do not restore synchronous heavy recomputation before dialog close.
- Do not add new loading copy, spinners, or disabled-state UI for this refresh.

### L4

Status: current

Question: After a successful `Add New Peak` save, should `My Peak Lists` preserve the current peak-row selection or automatically switch selection to one of the newly added peaks?

Recommended Answer:
- Automatically switch selection to one of the newly added peaks.
- If multiple peaks were added, choose the first by alphabetical order.

Answer: it should automatically switch selection to one of the newly added peaks - If there are multiple, go the first peak by alphabetical order

Decision: After a successful `Add New Peak` save, `My Peak Lists` automatically switches selection to one of the newly added peaks, and if multiple were added, it chooses the first by alphabetical order.

### L5

Status: current

Question: If multiple newly added peaks share the same visible peak name, what exact tie-break should decide which one becomes the automatic post-save selection?

Recommended Answer:
- Use the stored peak `name` as the alphabetical sort key.
- Compare case-insensitively.
- If two added peaks have the same `name`, pick the one with the smaller `osmId`.

Answer: agreed

Decision: Automatic post-save peak selection uses case-insensitive alphabetical stored `Peak.name`, with smaller `osmId` as the deterministic tie-break when names match.

Reason: The visible ordering rule must stay deterministic for both app behavior and regression tests.

### L6

Status: current

Question: What regression-proof coverage should this follow-up require to prove the add-flow fix does not reintroduce the responsiveness regression?

Recommended Answer:
- Add deterministic automated coverage for repository-level membership preservation and rollback safety.
- Add widget-level coverage for add success, add failure, and deferred-refresh selection behavior.
- Reuse existing `0027` regressions for map and `Region FAB` responsiveness rather than rewriting that suite.
- Require final manual verification on real migrated local post-`0024` data, rechecking `Add New Peak`, `My Peak Lists` `Region FAB`, and map responsiveness.

Answer: agreed

Decision: This follow-up requires deterministic repository and widget regression coverage for the add-flow contract, reuses existing `0027` responsiveness regressions where the contract is unchanged, and requires final manual verification on real migrated local post-`0024` data.

### L7

Status: current

Question: Should this follow-up revert the last three commits wholesale and start over?

Recommended Answer:
- No.
- Preserve the repository-side membership-preservation fix.
- Rework the screen-level refresh behavior instead of reverting the corrected repository contract.

Answer: agreed.

Decision: Do not revert the last three commits wholesale; preserve the repository-side membership-preservation fix and rework the screen-level refresh behavior instead.

Reason: A wholesale revert would also remove the intended data-loss fix and likely restore the original `Add New Peak` bug.

### L8

Status: current

Question: With `Peak visibility mode` now in the app, which map pan and zoom scenarios should this expanded regression explicitly cover?

Recommended Answer:
- Cover all three `Peak visibility mode` states.
- `Show Peak Clusters` and `Show Peaks` must restore smooth pan and zoom while preserving the current deferred-settle correctness contract.
- `Hide Peaks` must remain the cheapest path and must not do the peak-processing work that visible modes require.
- If performance is still poor in `Hide Peaks`, treat that as an in-scope bug.

Answer: agreed

Decision: Map pan and zoom responsiveness coverage for this follow-up applies across all three `Peak visibility mode` states; visible modes must restore smooth motion with correct settle behavior, and `Hide Peaks` must remain the cheapest path by skipping visible-mode peak processing.
