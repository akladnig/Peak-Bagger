# Implementation and verification

## Outcome

Implemented and visually verified on 2026-10-19. The Mac Mini preview was used
with explicit user permission for SSH inspection, bounded deployment, prepared
label publication and service restarts. No Flutter application files, window
contracts, domain database, DEM products or excluded styles were changed.

## Source diagnosis

Inspected the actual active PostGIS water records and the MBTiles label data:

| Lake | Whole OSM identity | Imported class | Geography area | Interior anchor (lon, lat) |
| --- | --- | --- | ---: | --- |
| Lake Perry | way/230064997 | `water` | 35,069.586 m² | 146.754523608, -43.213331951 |
| Hartz Lake | way/186551719 | `lake` | 167,321.259 m² | 146.757093141, -43.239263014 |
| Lake St Clair | relation/2893412 | `lake` | 28,675,440.073 m² | 146.175166070, -42.065780851 |

- Perry had both an MBTiles `water_name` point (`class=lake`) and the Martin
  polygon label (`class=water`). The baseline zoom-15 neighbourhood visibly
  reproduced two names. These were independent source paths, not a changed name.
- Hartz's `class=lake` failed the polygon-label layer's `class=water` filter.
  Its MBTiles `water_name` was absent at vector zooms 12 and 13 but present at 14.
  The installed TileServer GL uses MapLibre style zoom `z - 1` for native 256px
  XYZ requests, including `@2x`; native zooms 13/14 therefore lacked that name.
  This was a source/property/zoom problem, not merely font size.

## Production implementation

- PostGIS exports complete, identity-grouped source polygons, preserving holes
  and relation components. Geography area establishes the inclusive 1 km²
  threshold; `ST_PointOnSurface` supplies the stable interior anchor.
- `scripts/lake_labels.mjs` is the shared production/test placement boundary.
  Small lakes keep one anchor. Large lakes use an anchor-relative lattice with
  at least 258 logical pixels of separation (256 plus MVT rounding margin).
  Conservative text bounds can increase spacing or suppress colliding names.
  Competing lakes prefer larger ground area with source identity breaking ties.
  Placement contains no example-lake names/IDs or viewport/tile-fragment inputs.
- Six zoom-scoped point-label layers replace competing lake paths at native
  13–18, account for the renderer's zoom offset, retain collision handling and
  put lake names ahead of contour/road labels. Legacy line naming is retained
  for rivers/streams; the lower-zoom lake paths are unchanged.
- Full OSM imports prepare labels before existing staged validation/promotion.
  `npm run refresh:lake-labels` derives only label data from the already-imported
  selected OSM source. It validates staged geometry/counts/spacing and Martin
  readability, swaps only the label table transactionally and restarts Martin
  and TileServer GL. Restart failures restore prior label data.
- Statewide preparation published **125,622 candidate labels from 659 lakes**.
  Live-scale review prompted scanline reuse during placement and indexed,
  subdivided geometry checks during validation. Subdivision is validation-only;
  area classification and placement still use complete lake geometry. An early
  slow validation was cancelled before publication; active data was preserved.

## Automated checks

`npm test` in `local_topo/tasmania`: **66 passed, 0 failed**.

Coverage includes exact threshold boundaries, zoom-independent classification,
stable small-lake anchors, holes and disconnected relations, large-lake spacing,
insufficient-room cases, separate same-named identities, adjacent tile ownership,
normal/retina spacing units, deterministic collision priority, SQL source and
staging seams, bounded-refresh selection, preparation/validation/promotion/restart
failures, style priority/filtering and retained unrelated parity/masking checks.

The shell-command fixtures now exercise the shell worker with controlled resolved
inputs rather than accidentally entering the newer Dart Mapping manifest resolver.
The parity assertions also explicitly account for existing Martin cartography
differences that predated this work. No unrelated production styles were altered
to make those tests pass. `bash -n` and Node syntax checks passed for affected
scripts. No Flutter/widget/robot/build verification applies to this server slice.

## Inspected live rendering

Used the existing Martin-backed Mini preview at `http://mac-mini.local:8090`,
after publication/restart, and `npm run review:cartography --
--style-id=tasmania-openstreetmap-contours-martin` with an explicit review base
URL and separate before/after output roots. These are fresh server captures,
not app-cached imagery. Inspected the actual PNG neighbourhoods and pan windows;
downloads alone were not treated as acceptance.

| Check | Native centre tile | Inspected result |
| --- | --- | --- |
| Perry 15 | 29741/20754 | One interior name across the 3×3 neighbourhood; prior two-name defect gone. |
| Perry 16 | 59483/41508 | One name, same geographic anchor. |
| Perry 17 | 118967/83016 | One name, no zoom-dependent repetition. |
| Perry 18 | 237935/166032 | One name, including near-seam text; no independent duplicate. |
| Hartz 13 | 7435/5189 | Readable `Hartz Lake`; nearby Esperance/Emily names do not overlap it. |
| Hartz 14 | 14871/10378 | Readable name; paths/contours retained without obscuring the lake name. |
| St Clair 15 | 29689/20612 | Interior, non-overlapping repeats across adjacent tiles. |

The St Clair 3×3 neighbourhood contained five full names plus clipped edge names.
Rendered full-name centres were **258 PNG pixels apart at normal scale** and
**516 PNG pixels apart at @2x**, both 258 logical pixels. The normal image was
visually inspected; OCR assisted normal-scale centre measurement and blue-glyph
bounds assisted retina measurement. Inspected overlapping left/right pan windows
offset by 256 logical pixels: names stayed at the same geographic positions,
with no seam-generated duplicate. This was tile-based pan review, not a claim
of an interactive Flutter UI test. SQL also validated the whole prepared dataset's
interior anchors, small-lake counts and repeat separation before publication.

Perry/Hartz neighbourhoods retain terrain relief, water masking and adjacent land
contours. Arve River and the zoom-12 Little Navarre River naming remain readable.
The contour source/tier/masking contracts are retained by the structural tests.

### Preservation comparisons

- An isolated temporary TileServer GL instance loaded the backed-up original and
  changed Martin styles with identical inputs and request sequences. Native
  `10/930/647`, `11/1855/1288` and `12/3711/2577` were **pixel-identical**.
- Ordinary reused production renderer pools initially showed low-zoom label
  selection/raster differences between capture runs. Isolation was used to
  control renderer history rather than misreport those first captures as equal.
- River/path sample `14/14893/10356` had unchanged readable content; isolated
  comparison differed by five raster pixels, not removed/renamed waterway labels.
- Canonical/static-bake style, legacy preview, MapTiler Topo and MapTiler Outdoor
  `12/3711/2577@2x` samples were pixel-identical before/after. Their source files,
  DEM artifacts and static tile outputs were not modified or regenerated.
- App label, raster route, capabilities, base-URL settings, basemap controls,
  native zoom limits and prerender zoom ranges remain unchanged.

Local captures are intentionally untracked under
`local_topo/tasmania/runtime/review/lake-labels-before/`, `lake-labels-after/`
and `isolated-comparison/`. The Mini retains its deployment backup under
`runtime/review/0068-deployment/source-before.tar`. The temporary isolated review
container was stopped/removed; the existing preview services remain running with
the accepted style/data. Maintainer instructions and portable review fixtures are
committed; production mapping data and machine-specific SSH adapters are not.
