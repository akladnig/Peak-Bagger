---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should route graphs be scoped to individual regions or allowed to combine regions for cross-border routes?

Recommended Answer:
- Define a routing coverage as one or more source regions, persist its source-region keys on the route-graph manifest, and avoid repeating a region field on every graph row.

Answer: Agreed.

Decision: Route graphs are imported and selected by routing coverage. A coverage can combine source regions for cross-border routing.

### L2

Status: current

Question: Which source regions belong to the initial routing coverages?

Recommended Answer:
- Tasmania is its own coverage.
- FVG, Veneto, and Slovenia form Northeast Alps.
- Routes spanning coverages are unavailable.

Answer: Agreed.

Decision: The initial coverages are `tasmania` and `northeast-alps`; Northeast Alps contains `fvg`, `veneto`, and `slovenia`.

### L3

Status: current

Question: Can the obsolete single-file `assets/highway.json` importer input be removed?

Answer: Yes.

Decision: Route-graph import no longer reads a single `assets/highway.json`; it resolves all inputs from routing-coverage membership and manifest highway declarations.

### L4

Status: current

Question: Should driving time use the local graph or OpenRouteService?

Recommended Answer:
- Retain OpenRouteService for driving distance and duration.
- Use local graph data for road-target selection and walking-route planning.

Answer: Agreed.

Decision: OpenRouteService remains the online source of driving distance and duration; the local graph is not a car-routing engine.

### L5

Status: current

Question: When should bundled routing coverages be imported?

Recommended Answer:
- Import all bundled coverages sequentially in the background on first launch and when inputs change.
- A failed coverage must not disable ready coverages.
- Refresh all bundled coverages through Refresh Route Graph.

Answer: Agreed.

Decision: Bootstrap and refresh process all coverages sequentially with independent readiness and failure isolation.

### L6

Status: current

Question: Should the region manifest be the sole configuration source for coverage membership and highway assets?

Recommended Answer:
- Add `routingCoverage` to source regions.
- Import only regions with that key.
- Exclude composite and legacy entries without it.

Answer: Agreed.

Decision: `assets/region_manifest.json` is authoritative for routing-coverage membership and highway paths. `routingCoverage` maps `tasmania` to `tasmania` and `fvg`, `veneto`, and `slovenia` to `northeast-alps`.

### L7

Status: current

Question: Should coverage matching use imported graph chunks rather than manifest polygons?

Recommended Answer:
- A point belongs to a coverage when it falls in a stored graph chunk.
- Both endpoints must match exactly one coverage.

Answer: Agreed.

Decision: Coverage selection uses the persisted route-graph chunk footprint. Routing is unavailable unless both endpoints match exactly one coverage.

### L8

Status: current

Question: What happens when a matched coverage is loading or failed?

Recommended Answer:
- Preserve a route draft and show `Routing data for <coverage> is still loading.` with retry once ready.
- Do not offer driving-time actions for loading or failed coverage targets.
- Show `Routing data for <coverage> is unavailable. Use Refresh Route Graph to retry.` after failure.

Answer: Agreed.

Decision: Coverage readiness is visible and recoverable without clearing a route draft or affecting other coverages.

### L9

Status: current

Question: What happens when a multi-coverage refresh partially fails?

Recommended Answer:
- Replace each coverage atomically.
- Keep the prior valid generation for a failed refresh.
- Commit successful coverage refreshes and report successes and failures together.

Answer: Agreed.

Decision: Refresh is atomic per coverage and reports partial success; a failed refresh never replaces a valid coverage with partial data.

### L10

Status: current

Question: How should ObjectBox distinguish simultaneous coverage generations without storing a region on every row?

Recommended Answer:
- Store one manifest per routing coverage with an indexed unique coverage key.
- Allocate generation IDs globally.
- Scope child rows by unique generation only.

Answer: Agreed.

Decision: Each Route-graph manifest represents one coverage; globally unique generation IDs scope chunks, way indexes, and trail-display chunks without a repeated child region field.
