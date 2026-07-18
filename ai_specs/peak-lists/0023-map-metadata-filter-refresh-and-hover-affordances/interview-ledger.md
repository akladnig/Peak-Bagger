---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which canonical term should this bugfix use for the difficulty, rating, and duration dropdowns on `MapScreen`?

Recommended Answer:
- Use `map metadata filter` as the canonical term.
- Scope it to the `MapScreen` `Rating`, `Difficulty`, and `Duration` controls.
- Do not use `peak list filter` for this bug because that refers to a different map feature.

Answer: agreed

Decision: This bugfix uses `map metadata filter` as the canonical term for the `MapScreen` rating, difficulty, and duration controls.

Answer History:
- Initial wording: `peak list filter on map screen`.
- Final wording: `map metadata filter` for the rating, difficulty, and duration dropdowns.

### L2

Status: current

Question: When peak-list import or update changes the data behind the map metadata filter, how should `MapScreen` refresh?

Recommended Answer:
- Refresh the map metadata filter immediately after any peak-list import or update that changes peak membership in the current map scope or peak metadata used by rating, difficulty, or duration.
- Apply that refresh in both `All Peaks` mode and specific peak-list selection mode.
- Keep any already-selected filter value visible and active even if it becomes stale after the refresh, until the user changes or clears it.

Answer: agreed

Decision: Peak-list import or update must immediately refresh map metadata-filter options and filtered map results in both `All Peaks` mode and specific peak-list selection mode.

### L3

Status: current

Question: Should the same immediate refresh behavior apply when `ObjectBox Admin` updates peak metadata?

Recommended Answer:
- Yes.
- Any `ObjectBox Admin` peak save that changes rating, difficulty, or duration must update the map metadata filter immediately.

Answer: agreed. Also any updates in ObjectBox admin should update immediately

Decision: `ObjectBox Admin` peak saves that change rating, difficulty, or duration must immediately refresh map metadata-filter options and filtered map results.

### L4

Status: current

Question: If the map metadata-filter popup is already open when peak-list import, peak-list update, or `ObjectBox Admin` edits change the underlying data, how should the popup behave?

Recommended Answer:
- Refresh the open popup in place immediately.
- Keep the popup open.
- Keep any active selection visible even if it becomes stale.
- Recompute the filtered map results immediately from the updated data.
- Do not show a toast, dialog, or auto-reset just because the available options changed.

Answer: agreed

Decision: An open map metadata-filter popup refreshes in place immediately after relevant peak-list or `ObjectBox Admin` data changes, while preserving active selections and keeping the popup open.

Negative Requirements:
- Do not close the popup because of the refresh.
- Do not auto-clear active selections.
- Do not show extra confirmation or notification UI for the refresh.

### L5

Status: current

Question: Which `MapScreen` controls should show the pointing-finger cursor for this hover bugfix?

Recommended Answer:
- Show `SystemMouseCursors.click` on the app-bar `Filter` button.
- Show it on the `Rating`, `Difficulty`, and `Duration` dropdown triggers.
- Show it on the `Clear filters` action and popup close button.
- Do not change cursor behavior for non-interactive labels or the backdrop.

Answer: agreed

Decision: The pointing-finger cursor applies only to the interactive map metadata-filter controls: the app-bar `Filter` trigger, the three dropdown triggers, the `Clear filters` action, and the popup close button.

### L6

Status: current

Question: How should the `Clear filters` control look and align?

Recommended Answer:
- Keep the label `Clear filters`.
- Right-align the control within the popup.
- Use the same filled, high-emphasis treatment as the `Create Route` cancel control.
- Keep it enabled while the popup is open.

Answer: agreed

Decision: `Clear filters` stays labeled `Clear filters`, is right-aligned in the popup, and uses the same filled, high-emphasis styling as the `Create Route` cancel control.

Reason: The user explicitly rejected the lower-emphasis themed `TextButton` treatment and anchored the desired styling to an existing app control.
