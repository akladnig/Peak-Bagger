---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What canonical term should the Spec use for the segmented ring that shows peak-list ownership on the map?

Recommended Answer:
- Define the ring as a `Peak ownership ring`.
- Use that term for both individual peak markers and peak clusters.

Answer: agreed through follow-up clarification that the ring applies to both peak clusters and individual peaks.

Decision: Use `Peak ownership ring` as the canonical project term for the segmented map ring that shows visible peak-list ownership on individual peaks and clusters.

### L2

Status: current

Question: What is the user-visible contract for individual peak ownership rings?

Recommended Answer:
- Show the ring for individual peaks only when ring display is enabled and the peak belongs to more than one visible list.
- Split the individual ring into equal segments, one per visible owning list.
- If an individual peak belongs to exactly one visible list, show only the triangle.
- If an individual peak belongs to no visible lists, show no ring.

Answer: agreed except: If an individual peak belongs to exactly one visible list, do not show a full single-colour ring when the individual-ring setting is enabled only show the triangle

Decision: Individual peaks use a `Peak ownership ring` only for multi-list visible ownership. Segment sizes are equal per visible owning list. Single-list and zero-list individual peaks show only the triangle with no ring.

Answer History:
- Initial recommendation: a single visible list would show a full single-colour ring.
- Final answer: a single visible list shows no individual ring, only the triangle.

### L3

Status: current

Question: How should the settings toggle and triangle fallback behave when individual peak ownership rings are disabled?

Recommended Answer:
- Add a Settings toggle that enables or disables the individual `Peak ownership ring` display.
- Keep cluster rings visible regardless of that toggle.
- When the toggle is off, Tasmania unticked individual peaks use the precedence `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full`.
- Outside Tasmania, unticked individual peaks use the visible matching list colour with the lowest `peakListId`.

Answer: agreed. as other regional list are added a mechanism will be required to more efficiently manage this

Decision: Add a Settings-controlled on or off state for individual `Peak ownership ring` display only. Cluster rings always remain visible. When individual rings are off, unticked Tasmania peaks use the explicit precedence `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full`, while other regions use the visible matching list colour with the lowest `peakListId`.

Reason: The Tasmania precedence is intentionally explicit for this slice, but future regional growth will need a more scalable mechanism.

### L4

Status: superseded

Question: How should app-bar peak-list button selected or unselected state behave when the visible region changes?

Recommended Answer:
- Keep pinning per region as it already works.
- Add a per-region remembered selected-state snapshot for visible specific peak lists.
- Restore the region's last selected specific lists exactly when returning to that region.
- Preserve deselected state for that region.
- Use `All Peaks` or `None` as global fallback only when no region-specific snapshot exists.
- Zero-region views must not erase remembered region snapshots.

Answer: agreed

Decision: Save and restore exact per-region selected and unselected app-bar specific-list state alongside existing per-region pin behavior. `All Peaks` and `None` act as fallback only when no region-specific specific-list snapshot exists for the re-entered region. Zero-region views hide buttons without erasing stored region state.

Superseded by:
- L6, which refines this contract to exact normalized visible-region `Set<String>` snapshots with deterministic persistence and `All Peaks` as the only automatic fallback.

### L6

Status: current

Question: After refinement, how should app-bar peak-list restore behave for multi-region views and how should that remembered state persist?

Recommended Answer:
- Key remembered app-bar state by the exact normalized visible-region `Set<String>`, not by a single region.
- Restore that exact visible-region-set snapshot when the user returns to the same visible-region set.
- Keep pinning as a separate per-region state machine.
- If no remembered visible-region-set snapshot exists, fall back to `All Peaks`.
- Restore `none` only when the user explicitly chose `none` for that visible-region set.
- Persist remembered visible-region-set snapshots as deterministic JSON records using sorted normalized region keys and sorted `peakListId` arrays.

Answer: agreed

Decision: Save and restore app-bar peak-list state by exact normalized visible-region `Set<String>`. `All Peaks` is the fallback only when no snapshot exists for the visible-region set, while `none` restores only when explicitly chosen by the user. Persist snapshots as deterministic JSON records keyed by sorted normalized region arrays, independent from per-region pin persistence.

### L5

Status: current

Question: What exact cluster ring contract should the Spec use now that clusters must retain a ring while also showing ticked state?

Recommended Answer:
- Keep one solid green arc sized by the number of ticked peaks in the cluster.
- Split only the unticked remainder into equal visible-list segments.
- Do not preserve per-list ownership inside the green ticked arc in this slice.
- If a cluster has no unticked peaks, the ring is fully green.
- If a cluster has no ticked peaks, the ring is fully list-segmented.

Answer: agreed

Decision: Cluster `Peak ownership rings` use a hybrid display: the ticked share remains one green aggregate arc proportional to ticked peak count, and the unticked share is split into equal segments by visible owning list count.

Answer History:
- Earlier direction: cluster ring segments should be proportional by the number of peaks per list.
- Final answer: keep the ticked share as a green aggregate arc and segment only the unticked remainder equally by visible list.
