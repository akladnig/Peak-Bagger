---
type: Spec
title: Dashboard My Peak Lists Map Navigation
---

## Problem

The dashboard `My Peak Lists` card currently routes a tapped row to `My Peak Lists` with `selectedPeakListId`, which only selects the list in the peak-lists screen. It does not navigate the user to the map coverage they expect, and it cannot represent mixed-region lists by geometry because the current flow relies on one stored `PeakList.region` string. [L1] [L2]

## Proposed Outcome

Tapping a row in the dashboard `My Peak Lists` card opens `Map`, selects that peak list, and moves the map camera to bounds derived from the list's member peak coordinates. `PeakList.region` remains a classification field, using `mixed` for mixed-region peak lists, while new derived ObjectBox fields cache nullable min/max latitude and longitude for navigation and related map coverage behavior. Mixed-region lists remain renderable in region-aware map flows rather than being dropped for lacking one canonical region key. Existing peak lists are backfilled so the new dashboard-to-map flow works against current data rather than only future writes. [L1] [L2] [L3] [L4]

## User Stories

1. As a dashboard user, I want tapping a `My Peak Lists` row to open `Map` focused on that list so I can immediately explore its peaks spatially instead of manually opening `My Peak Lists` first. [L1]
2. As a user with mixed-region peak lists, I want dashboard navigation to use the actual member-peak spread rather than one stored region label so the map lands on the full list coverage. [L1] [L2]
3. As a user with older stored data, I want existing peak lists to keep working with the new dashboard navigation without manual repair or reimport. [L4]

## Requirements

1. Tapping a dashboard `My Peak Lists` row must navigate to `Map` instead of `My Peak Lists`. The tapped list must become the active selected peak list in existing map provider state rather than through a new `/map` route argument or query parameter. [L1]
2. The dashboard tap flow must move the map camera using bounds derived from the tapped list's member peak coordinates rather than from one canonical `PeakList.region` value. Because `/map` is an existing shell branch without route arguments, the selection and camera intent must still apply when the map branch is not currently visible. [L1] [L2]
3. Mixed-region peak lists must follow the same dashboard navigation flow as Tasmania-only and single-region lists. Do not preserve a Tasmania-only navigation exception. [L1]
4. Keep `PeakList.region` as a stored classification field, not a geometry or coverage field. [L2]
5. Persist `PeakList.region = mixed` when a peak list is classified as spanning more than one canonical region. [L2]
6. Region-aware peak-list renderability and reconciliation logic touched by this slice must not drop a selected list solely because `PeakList.region == mixed`. Mixed-region lists must remain selectable and renderable on the map when their cached bounds or current member peaks intersect the currently visible region set. [L1] [L2]
7. Add nullable derived `PeakList` ObjectBox fields `minLat`, `maxLat`, `minLng`, and `maxLng`. These fields represent cached list coverage bounds. [L3]
8. The derived bounds fields must be computed from resolvable member peak coordinates and stored on the owning `PeakList`. [L1] [L3]
9. Recompute and resave the derived bounds fields whenever peak-list membership changes through create, import, add, remove, or whole-list delete flows. Point-value edits that do not change membership do not need bounds recomputation. [L3] [L4]
10. If this slice changes coordinates for a `Peak` referenced by one or more peak lists through existing import or correction write paths, it must also recompute and resave derived bounds for the affected lists before those caches are used for navigation again. [L2] [L3] [L4]
11. Run a one-time backfill after the schema change to compute and save derived bounds for existing stored peak lists and to normalize `PeakList.region` classification from current member peaks, including rewriting mixed-region lists to `mixed`. [L2] [L4]
12. If a user taps a dashboard row before a list's derived bounds have been populated or if the cached bounds cannot be used, the app must compute the bounds from current member peak rows on demand, persist them, then continue the map navigation. [L4]
13. If the tapped list has no resolvable member peak coordinates, the app must keep the user on the dashboard and show a concise `SnackBar` message that the list has no mappable peaks instead of navigating to `Map`. [L4]
14. If the derived bounds collapse to one coordinate, the map navigation flow may use the app's existing single-point camera-fit fallback rather than a zero-area bounds fit.
15. Persisted derived bounds are cache data. Member peak coordinates remain the source of truth for recomputation. [L2] [L4]
16. This slice must preserve the existing `My Lists` dashboard card layout, summary math, and stable row keys such as `my-lists-row-<peakListId>` so existing dashboard tests and selectors remain usable. [L1]
17. If new `PeakList` ObjectBox fields are added, regenerate the ObjectBox artifacts and keep ObjectBox Admin `PeakList` row mapping aligned so the new persisted values remain inspectable in the existing admin tooling. [L3]

## Technical Decisions

1. Store derived coverage on `PeakList` as four nullable scalar fields `minLat`, `maxLat`, `minLng`, and `maxLng` rather than as corner objects. This matches existing ObjectBox scalar conventions and the app's `LatLngBounds` style. [L3]
2. Treat `PeakList.region` and derived bounds as different concerns: `PeakList.region` is the list classification string, while `minLat`/`maxLat`/`minLng`/`maxLng` are a recalculable geometry cache. [L2] [L3]
3. Keep `/map` free of new route arguments. Reuse the existing map-route selection flow, and extend the pending camera-intent seam so the dashboard can queue a bounds-fit request while the map shell branch is inactive instead of forcing an immediate visible-map controller call.
4. Use the existing one-time startup backfill pattern for local data, with a migration marker, rather than tying the schema backfill to a dashboard-only code path. [L4]
5. Any write path that constructs or clones `PeakList` values must preserve the new derived fields unless it is intentionally recomputing them.

## Testing Strategy

1. Use behavior-first TDD for the derived-bounds calculation and persistence logic. Prefer focused unit or provider/service tests over widget plumbing when verifying bounds math, null-bounds cases, and backfill behavior.
2. Add repository or provider coverage for the one-time backfill, migration-marker behavior, and recomputation after list-membership mutations so existing and future data both receive persisted bounds updates. [L3] [L4]
3. Add coverage for affected peak-coordinate write paths if this slice updates them, proving referenced peak lists receive refreshed cached bounds before dashboard navigation relies on stale geometry. [L2] [L3] [L4]
4. Add focused coverage for mixed-region renderability and reconciliation so a selected list with `PeakList.region = mixed` is not dropped by visible-region filtering when its cached bounds or member peaks intersect the current map region set. [L1] [L2]
5. Add widget or app-shell tests for the primary dashboard tap journey: tap `my-lists-row-<peakListId>`, verify the app navigates to `Map`, verify the tapped list becomes active, and verify the map route receives and consumes the expected queued camera-fit intent for the derived bounds.
6. Reuse existing deterministic seams where possible: in-memory repositories for `PeakList` and `Peak`, the existing dashboard row keys, the existing shell navigation keys such as `nav-map`, and `TestMapNotifier` or equivalent pending-camera assertions instead of live map gestures.
7. Add failure-path coverage proving that a list with no resolvable member peak coordinates stays on the dashboard and surfaces the concise `SnackBar` message rather than navigating away. [L4]
8. Add coverage proving `PeakList.region = mixed` is persisted when one list spans multiple canonical regions, that single-region lists keep or regain their canonical classification, and that the one-time backfill normalizes older stored rows the same way. [L2] [L4]
9. Add schema-alignment coverage or targeted regression checks proving the new `PeakList` fields are visible through ObjectBox Admin row mapping after ObjectBox regeneration. [L3]
10. Use fake or in-memory data only. Do not depend on live ObjectBox app data, external services, or real map networking in automated tests.

## Out of Scope

1. Redesigning the `My Lists` dashboard card table, summary ordering, or card placement.
2. Changing other dashboard cards or unrelated map-entry flows.
3. General map-selection or peak-list-visibility refactors beyond the behavior needed to support dashboard row navigation.
4. Adding a new coverage polygon model or storing list geometry as anything richer than persisted bounds.

## Open Questions

None currently.

## Notes

1. `GLOSSARY.md` now defines `Mixed-region peak list` as a `PeakList` whose member peaks span more than one canonical region and clarifies that `PeakList.region` should not be treated as the list's geometric coverage.
