---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What should `Tassy Full` mean going forward?

Recommended Answer:
- `Tassy Full` is a Tasmania-only peak list.
- It should no longer auto-refresh after edits, imports, deletes, or other changes to any other peak list.
- The existing Settings action should remain available, but when run it should rebuild `Tassy Full` from Tasmania-only source lists and exclude non-Tasmanian lists such as `FVG 500` and `FVG Lesser Peaks`.

Answer: agreed

Decision: `Tassy Full` becomes a Tasmania-only list, automatic refresh from other peak-list mutations is removed, and the Settings action remains as the explicit refresh path.

### L2

Status: current

Question: What should be the source of truth for deciding whether a peak belongs in `Tassy Full`?

Recommended Answer:
- Use each peak's stored `Peak.region` value.
- `Tassy Full` should contain only peaks whose `Peak.region` is `tasmania`.
- During a manual rebuild, exclude any peak whose stored region is not `tasmania`, even if it appears in another list.
- This means peaks from `FVG 500` and `FVG Lesser Peaks` are removed because their peaks are non-Tasmanian.

Answer: agreed

Decision: `Peak.region` is the source of truth for `Tassy Full` membership, and only peaks with region `tasmania` are eligible.

### L3

Status: current

Question: Should direct edits to `Tassy Full` still be allowed to add non-Tasmanian peaks, or should the app enforce the Tasmania-only rule there too?

Recommended Answer:
- Enforce the Tasmania-only rule everywhere.
- If the user tries to add a peak to `Tassy Full` and that peak's stored `Peak.region` is not `tasmania`, block the add and leave the list unchanged.
- Manual refresh should also remove any existing non-Tasmanian peaks from `Tassy Full`.

Answer: agreed

Decision: Direct edits must also enforce Tasmania-only membership, and manual refresh must remove any non-Tasmanian peaks already present in `Tassy Full`.

### L4

Status: current

Question: When the user runs the Settings refresh for `Tassy Full`, should it fully replace the list with the current Tasmania-only source set, or should it keep any existing Tasmanian peaks that are already in `Tassy Full`?

Recommended Answer:
- Fully replace `Tassy Full` with the current set of peaks whose `Peak.region` is `tasmania` and that are present in source peak lists.
- Remove any non-Tasmanian peaks.
- Remove any Tasmanian peaks that are no longer present in the source peak lists.
- Keep point values based on the refresh source data.

Answer: agreed except, keep any Tasmanian peaks that are not present in the source peak lists

Decision: Manual refresh removes non-Tasmanian peaks but preserves existing Tasmanian peaks already in `Tassy Full` even when they are absent from source peak lists.

Answer History:
- Initial recommendation: fully replace `Tassy Full` with the current Tasmania-only source set.
- Revised answer: keep Tasmanian peaks already in `Tassy Full` even if they are absent from source peak lists.

### L5

Status: current

Question: If a user directly removes a Tasmanian peak from `Tassy Full`, but that peak is still present in another source peak list, should the next manual `Tassy Full` refresh add it back?

Recommended Answer:
- Yes.
- Manual refresh should re-add any Tasmanian peak that is still present in source peak lists.
- Manual refresh should preserve Tasmanian peaks that exist only in `Tassy Full`.
- Manual refresh should remove only non-Tasmanian peaks.

Answer: agreed

Decision: Manual refresh re-adds source-backed Tasmanian peaks, preserves `Tassy Full`-only Tasmanian peaks, and removes only non-Tasmanian peaks.

### L6

Status: current

Question: The current Settings copy says `Updates the Tassy Full Peak List to include peaks from all other peak lists`, which now conflicts with the new meaning. What should the visible label and description be?

Recommended Answer:
- Keep the title as `Update Tassy Full Peak List`.
- Change the subtitle to `Updates the Tassy Full Peak List using Tasmanian peaks from other peak lists`.
- Change the confirmation body to `This will update Tassy Full using Tasmanian peaks from other peak lists and remove non-Tasmanian peaks. Do you wish to proceed?`

Answer: agreed

Decision: The Settings tile title stays the same, but the subtitle and confirmation copy must use the new Tasmania-only wording.

### L7

Status: current

Question: In the `Add New Peak` flow for `Tassy Full`, should non-Tasmanian peaks be hidden from search results, or remain visible and fail when the user saves?

Recommended Answer:
- Hide non-Tasmanian peaks from the `Tassy Full` add dialog results.
- Keep the rest of the add flow unchanged.
- As a safety net, if a non-Tasmanian peak somehow still reaches save, show `Peak List Update Failed` with `Tassy Full only accepts Tasmanian peaks.`

Answer: agreed

Decision: The `Tassy Full` add dialog hides non-Tasmanian peaks, and save-time validation remains as a safety net with the exact failure message.
