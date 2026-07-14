---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What should happen when the user taps a row in the dashboard `My Peak Lists` card?

Recommended Answer:
- Tapping a row in the dashboard `My Peak Lists` card should open the `Map` screen.
- The map should pan/zoom to the tapped list's coverage.
- That tapped list should become the active selected peak list on the map.
- Tasmania/Tasmanian should follow the same rule as every other region; no special-case navigation path.

Answer History:
- Initial answer: open `Map` and pan/zoom to the tapped list's canonical region.
- Revised answer: some lists may span multiple regions, so determine coverage from the locations of the peaks in the list and calculate bounds from those points.

Answer: The recommended behavior is correct, but list coverage must come from the member peak locations rather than one canonical region because some lists span multiple regions.

Decision: Tapping a `My Peak Lists` dashboard row must navigate to `Map`, activate the tapped list, and move the camera using bounds derived from the list's member peak coordinates rather than from one region key.

Constraints:
- Do not keep Tasmania as a special navigation case.
- Do not use one canonical region key as the geometry source for mixed-region lists.

### L2

Status: current

Question: What should `PeakList.region` mean for mixed-region lists once navigation bounds are derived from member peaks?

Recommended Answer:
- Keep `PeakList.region` as a single stored classification field, not a coverage field.
- Store `PeakList.region = mixed` when a list contains peaks from more than one canonical region.
- Derive navigation bounds from the member peak coordinates.
- If bounds are cached on `PeakList`, treat them as derived data that can be recalculated, not as the source of truth.

Answer: agreed

Decision: `PeakList.region` remains a stored classification field, uses `mixed` for mixed-region peak lists, and must not be treated as the source of truth for list geometry.

Reason: This preserves clear terminology and separates list classification from derived map coverage.

### L3

Status: current

Question: What stored shape should the derived peak-list coverage use on the `PeakList` entity?

Recommended Answer:
- Add derived nullable `PeakList` fields: `minLat`, `maxLat`, `minLng`, `maxLng`.
- Recompute them from member peak coordinates whenever list membership changes.
- Use those stored bounds for dashboard-to-map navigation.
- If a list has no valid member peak coordinates, leave all four fields null and fall back to the current non-navigation behavior.

Answer: agreed

Decision: Add nullable derived `PeakList` fields `minLat`, `maxLat`, `minLng`, and `maxLng` for persisted map-coverage bounds.

Reason: The codebase already uses min/max latitude-longitude conventions and `LatLngBounds` semantics.

### L4

Status: current

Question: What should happen for existing stored peak lists that do not yet have the new derived bounds fields populated?

Recommended Answer:
- Add a one-time backfill that computes and saves `minLat`, `maxLat`, `minLng`, and `maxLng` for all existing peak lists after the schema change.
- Recompute and resave those fields whenever list membership changes through create, import, edit, or delete flows.
- If a user taps a list before backfill has populated its bounds, compute the bounds on demand, persist them, then navigate.
- If a list has no resolvable member peak coordinates, do not navigate away; keep the user on the current screen and show a concise error message.

Answer: agreed

Decision: The slice must backfill derived peak-list bounds for existing data, recompute them on membership changes, compute them on demand before navigation if still missing, and fail in place with a concise error when no resolvable coordinates exist.

Reason: Existing data must not produce broken or inconsistent dashboard navigation.
