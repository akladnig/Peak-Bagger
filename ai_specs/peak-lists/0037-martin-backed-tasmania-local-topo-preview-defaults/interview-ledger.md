---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which separate concepts should be canonical for this workflow when discussing style, zoom, and contours?

Recommended Answer:
- `Preview style`
- `Prerender zoom range`
- `Contour cartography`

Answer: agreed

Decision: The workflow must treat `Preview style`, `Prerender zoom range`, and `Contour cartography` as separate canonical concepts.

Constraints:
- Do not collapse style edits into static prerender scope.
- Do not treat contour styling as the same thing as contour data generation.

### L2

Status: current

Question: How should `z17` and `z18` be scoped?

Recommended Answer:
- Enable `z17` and `z18` for preview only.
- Make no changes to the prerender zoom range.
- Scope the change to the OSM-plus-contours preview path.

Answer: agreed

Decision: `z17` and `z18` are preview-only and do not change prerender behavior.

### L3

Status: current

Question: Should preview `z17` and `z18` use regenerated higher-zoom data or only overzoom existing tiles?

Answer: I want to regenerate the mbtiles for z17 & z18.

Decision: The target outcome is regenerated higher-zoom preview data, not overzoom-only rendering.

### L4

Status: current

Question: Which replacement path should be used for native higher-zoom preview OSM data?

Answer: I like 2. PostGIS + Martin for on-demand vector tiles

Decision: The preview OSM source should move to a `PostGIS + Martin` path.

### L5

Status: current

Question: What should become the default maintainer preview behavior?

Recommended Answer:
- `npm run stack:up` starts preview mode by default.
- The default preview style should move to the Martin-backed OSM-plus-contours variant.
- Keep an explicit static startup command.
- Fail fast if preview prerequisites are missing or unhealthy.
- Keep the app-facing raster route and capability contract unchanged.

Answer: agreed

Decision: Preview mode becomes the default maintainer stack behavior while preserving the existing raster app contract.

Negative Requirements:
- Do not silently fall back to static tiles or smoke fixtures from the default path.

### L6

Status: current

Question: How should the preview OSM data lifecycle be owned and refreshed?

Recommended Answer:
- Use the same selected Tasmania OSM extract already used by the rebuild workflow.
- Build or refresh preview OSM data during `refresh:manual` and `refresh:scheduled`.
- Keep `stack:up` serve-only.
- Treat Docker Compose-managed `PostGIS` as the canonical repo workflow.

Answer: agreed

Decision: Preview OSM data is maintainer-managed derived state built from the selected Tasmania extract during refresh commands, with Docker Compose-managed `PostGIS` as the canonical runtime.

Reason: The user accepted Docker Compose `PostGIS` as the canonical workflow even after asking why a local install was not preferred.

### L7

Status: current

Question: Must the Martin-backed preview preserve full OpenMapTiles compatibility?

Recommended Answer:
- Allow a smaller Martin/PostGIS-specific preview schema.
- Preserve current vector layer names where practical to minimize style churn.

Answer: agreed

Decision: The Martin-backed preview may use a smaller repo-owned schema, but should preserve current layer names where practical.

### L8

Status: current

Question: Which current OSM vector layers are required in the first Martin-backed preview schema?

Recommended Answer:
- Required: `landcover`, `landuse`, `water`, `water_name`, `waterway`, `transportation`, `transportation_name`, `building`, `place`, `park`, `boundary`
- Deferred: `aerodrome_label`, `aeroway`, `housenumber`, `mountain_peak`, `poi`

Answer: agreed

Decision: The first Martin-backed schema is limited to the agreed required layer subset and explicitly defers the remaining OSM layers.

### L9

Status: current

Question: Which OSM-to-PostGIS import approach should be canonical?

Recommended Answer:
- Use `osm2pgsql` with a repo-owned `flex` import for only the required preview layers and attributes.
- Do not use the full OpenMapTiles import pipeline.

Answer: agreed

Decision: The Martin-backed preview OSM database should be imported through repo-owned `osm2pgsql` `flex` configuration.

### L10

Status: current

Question: What should happen if contours and relief rebuild succeed but the preview OSM import fails?

Recommended Answer:
- Keep the last successful preview database in place.
- Fail the run clearly.
- Do not publish a partial replacement.

Answer: agreed

Decision: Failed preview OSM imports must preserve the last successful preview database while still failing the refresh run.

### L11

Status: current

Question: Should maintainers be able to switch between the legacy TileServer-backed OSM source and the new Martin-backed OSM source for comparison?

Recommended Answer:
- Yes, through an explicit startup-scoped preview OSM source selector.
- Keep the raster preview route and style-driven rendering path unchanged.

Answer: agreed

Decision: The preview stack must support explicit maintainer A/B switching between legacy TileServer-backed OSM and Martin-backed OSM.

### L12

Status: current

Question: How should the two comparison paths be represented in preview style ids and files?

Recommended Answer:
- Keep the legacy style id `tasmania-openstreetmap-contours` backed by `styles/local-topo/openstreetmap.json`.
- Add `tasmania-openstreetmap-contours-martin` backed by `styles/local-topo/openstreetmap-martin.json`.
- Initialize the Martin file as a direct copy of the legacy style file.
- Make the Martin-specific style the default preview style.

Answer: agreed

Decision: The comparison paths must use distinct committed style ids and files, with a Martin-specific copy becoming the default preview style.

### L13

Status: current

Question: How should maintainers select between the legacy and Martin preview OSM sources?

Recommended Answer:
- Use `LOCAL_TOPO_PREVIEW_OSM_SOURCE=martin|tileserver`.
- Default it to `martin`.
- Keep one-off command overrides for comparison runs.

Answer: agreed

Decision: Preview OSM source selection is a startup-scoped environment contract through `LOCAL_TOPO_PREVIEW_OSM_SOURCE`, defaulting to `martin`.

### L14

Status: current

Question: Is future in-app switching through the map screen basemap drawer allowed, and what should the user-facing labels be?

Recommended Answer:
- It is a possible future enhancement.
- Use `Local Topo` for the preferred path.
- Use `Local Topo Legacy` for the older comparison path.
- Keep that app-facing selector out of scope for this first Spec.

Answer: agreed

Decision: Future app-side comparison in the basemap drawer is allowed, but this first Spec must leave the app drawer unchanged and reserve `Local Topo` and `Local Topo Legacy` as the canonical future labels.
