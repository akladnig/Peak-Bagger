---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the Roads filter search only motor-vehicle roads or every named route-graph way?

Answer: Search every named route-graph way.

Decision: Roads search includes all named route-graph ways, including paths, tracks, and footways.

### L2

Status: current

Question: Should named route-graph ways appear under the All filter?

Answer: Yes.

Decision: All search results include named route-graph ways alongside the existing enabled entity types.

### L3

Status: current

Question: What should happen when a Roads result is selected?

Recommended Answer:
- Close the search popup.
- Center the map on the way midpoint at the current zoom.
- Set that midpoint as the selected location.
- Do not add a persistent road highlight or details popup.

Answer: Agreed.

Decision: Selecting a Roads result closes the search popup and centers the current-zoom map on the way midpoint as the selected location, without adding a persistent highlight or details popup.

### L4

Status: current

Question: What metadata should a Roads result display below its name?

Recommended Answer:
- Display the OSM highway value and, when present, the surface value in title case.
- Join the values with ` · `, for example `Track · Gravel` or `Footway`.

Answer: Agreed.

Decision: Roads result subtitles display title-cased highway and optional surface metadata joined by ` · `.

### L5

Status: current

Question: How should duplicate occurrences across chunks or active routing coverages be presented?

Recommended Answer:
- Show one result per OSM way ID.
- Keep distinct OSM ways with the same displayed name as separate results.

Answer: Agreed.

Decision: Roads search de-duplicates matching occurrences by OSM way ID while retaining separate ways that share a name.

### L6

Status: current

Question: What should the Roads filter show when no active route-graph coverage is available?

Recommended Answer:
- Keep Roads enabled.
- Return no road results through the existing `No results found` empty state.
- Do not add a dedicated loading or error surface and do not trigger an import from search.

Answer: Agreed.

Decision: Roads remains enabled without active coverage and uses the existing empty state without initiating import work or showing a feature-specific error.

### L7

Status: current

Question: Should the existing Region filter apply to Roads results?

Recommended Answer:
- Resolve a road midpoint.
- Include it only when that point belongs to the selected region.
- Exclude roads outside manifest regions while a region filter is active.

Answer: Agreed.

Decision: Region filtering applies to Roads results using the resolved way midpoint.

### L8

Status: current

Question: Which road-name matching semantics are supported?

Recommended Answer:
- Match only the indexed OSM `name` tag.
- Use case-insensitive substring matching.
- Do not support `ref`, `alt_name`, fuzzy search, or raw-tag fallback.

Answer: Agreed.

Decision: Roads search supports case-insensitive substring matching of indexed OSM names only.

### L9

Status: current

Question: What happens when an indexed named way cannot resolve a midpoint from its authoritative chunk payload?

Recommended Answer:
- Omit that way from the results.
- Do not fail the whole search.
- Use the normal empty state if no results remain.

Answer: Agreed.

Decision: A named way with unresolvable geometry is omitted without interrupting search.

### L10

Status: current

Question: What automated verification is required?

Recommended Answer:
- Unit-test road matching, duplicate collapse, region filtering, subtitle formatting, unavailable coverage, and midpoint-resolution failure.
- Add widget or robot coverage for the enabled Roads filter and tap-to-center behavior.
- Use a fake RouteGraphQueryService seam rather than real route-graph imports or network activity.

Answer: Yes.

Decision: The feature requires deterministic unit plus widget or robot journey coverage using a fake route-graph query seam and no real network activity.

### L11

Status: current

Question: Should malformed geometry skipped from results be logged?

Recommended Answer:
- Emit a `dart:developer` diagnostic log containing the OSM way ID and chunk key.
- Keep the search popup uninterrupted.

Answer: Agreed.

Decision: Geometry-resolution failures skipped from Roads results must be logged with the way ID and chunk key while preserving uninterrupted search.
