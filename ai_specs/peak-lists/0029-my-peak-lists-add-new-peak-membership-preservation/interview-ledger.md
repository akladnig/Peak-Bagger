---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: For `My Peak Lists`, should `Add New Peak` update the currently selected existing peak list in place, or can it recreate or replace the list row?

Recommended Answer:
- Treat `Add New Peak` as an in-place update to the selected existing peak list.
- Preserve the same `peakListId`, list name, colour, and current selection.
- Recompute derived bounds and derived region from the combined membership set after the add.
- Append only the newly chosen peak memberships.
- Keep all existing peaks in that list unchanged.
- Do not create a new peak-list row, reset any prior `peakListId` to `0`, or clear existing memberships as part of this flow.

Answer: agreed

Decision: `My Peak Lists` `Add New Peak` must mutate the selected existing `PeakList` in place, preserve its identity and existing memberships, append only the newly chosen memberships, and recompute derived bounds and derived region from the combined membership set after the add.

Negative Requirements:
- Do not create a replacement `PeakList` row for this flow.
- Do not reset the prior list identity to `0`.
- Do not clear or rewrite existing memberships as a side effect of adding peaks.

### L2

Status: current

Question: If `Add New Peak` hits a repository or persistence failure while saving, should the selected peak list keep its original members unchanged, or is partial mutation acceptable?

Recommended Answer:
- Make the add operation atomic for existing membership data when repository or persistence failure occurs.
- On any repository or persistence failure, keep the selected peak list exactly as it was before the add started.
- Keep the same `peakListId` and current list selection.
- Show an error dialog, keep the current add session available for retry or cancel, and do not silently drop existing peaks.

Answer: agreed

Decision: Repository or persistence failures during `Add New Peak` must preserve the selected list exactly as it existed before save, keep the same selected list identity, keep the current add session available for retry or cancel, and surface the existing failure UI instead of partially mutating or silently dropping memberships.

Reason: The reported bug is a data-loss regression, so failure behavior must explicitly protect the existing list contents.

### L3

Status: current

Question: Which current `Add New Peak` behavior is canonical given the stale single-select doc and the live multi-select implementation?

Recommended Answer:
- Keep the current multi-select UI exactly as it is today.
- Treat `011-pl-add-edit.md` as stale for this point.
- Do not change what is currently visible in the multi-select list.
- Treat any existing duplicate-prevention behavior in the current flow as out of scope for this bug.
- Scope this slice to the regression only: saving added peaks must preserve all existing memberships on the selected list and keep the same `peakListId`.

Answer: agreed

Decision: The current multi-select `Add New Peak` behavior is canonical, `011-pl-add-edit.md` is stale for this flow, and this slice should fix the membership-loss regression without changing the current picker behavior or visible results.

Answer History:
- Initial answer: duplication is not possible.
- Revised answer: multi-select is already functional and working as expected.
- Final answer: keep the current multi-select behavior unchanged and scope the work to preserving existing memberships and list identity.

Negative Requirements:
- Do not change the current multi-select list behavior.
- Do not change what is currently visible in the picker as part of this bug fix.
