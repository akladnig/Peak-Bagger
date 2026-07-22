---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What is the requested feature outcome for the downloaded MapTiler `Topo` and `Outdoor` styles?

Answer: Download the styles, advise what changes are needed in this repo, and allow selection of different styles through the preview.

Decision: The work should add project-managed Tasmania preview variants derived from MapTiler `Topo` and `Outdoor`, along with repo-aligned guidance for integrating and previewing them.

### L2

Status: current

Question: Should `Topo` and `Outdoor` be preview-only variants first, or immediate new user-facing basemaps in the app picker?

Recommended Answer:
- Keep `Local Topo` as the only current app-facing basemap term.
- Add separate preview style ids for the new variants.
- Keep the existing `/tasmania/local-topo/{z}/{x}/{y}.png` app contract unchanged.
- Defer the user-facing basemap picker entries to a second phase.

Answer: I would like to be able to have them as new user-facing basemaps in the app's basemap picker but that can be deferred to a second phase.

Decision: Phase 1 is preview-only and keeps `Local Topo` as the sole current app-facing basemap, while phase 2 may add separate user-facing basemap entries.

### L3

Status: current

Question: What should the canonical future user-visible labels and internal identities be for these deferred basemaps?

Recommended Answer:
- User-visible labels: `MapTiler Topo` and `MapTiler Outdoor`
- Internal basemap keys: `maptilerTopo` and `maptilerOutdoor`
- Preview style ids should stay aligned with those names.

Answer: agreed

Decision: The deferred app-facing basemap names are `MapTiler Topo` and `MapTiler Outdoor`, with future internal keys `maptilerTopo` and `maptilerOutdoor`.

### L4

Status: current

Question: Should phase 1 preview keep MapTiler-hosted assets, or should the downloaded style JSON be rewritten onto the repo's local Tasmania sources?

Answer: I was thinking of taking just the json style documents and rewriting them to the repo's local Tasmania sources so preview stays fully project-managed. Sprites and glyphs can be as the current Local Topo.

Decision: Phase 1 should use only the downloaded style JSON structure as source material, rewrite the styles onto the repo's local Tasmania sources, and reuse the current `Local Topo` glyph and sprite approach.

Negative Requirements:
- Phase 1 preview must not depend on MapTiler-hosted tiles.

### L5

Status: current

Question: Should the rewritten styles be loose inspirations or close visual ports of MapTiler `Topo` and `Outdoor`?

Recommended Answer:
- Treat the styles as close visual ports within the limits of the repo's local sources.
- Preserve the downloaded layer ordering, paint, and layout rules where they map cleanly.
- Allow source-name rewrites, missing-layer drops, and small label substitutions where the local data does not expose equivalent layers.

Answer: agreed

Decision: The rewritten styles should be close visual ports of MapTiler `Topo` and `Outdoor`, while allowing local-source remapping and selective layer or label substitutions where exact parity is impossible.

### L6

Status: current

Question: How should developers switch between the preview variants in phase 1?

Recommended Answer:
- Keep one logical preview route and one `Local Topo` capability contract.
- Register extra TileServer style ids such as `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor`.
- Choose the active preview variant only at stack startup with `LOCAL_TOPO_PREVIEW_STYLE_ID=... npm run stack:up:preview`.
- Do not add in-app runtime switching or multi-style capability output in phase 1.

Answer: agreed

Decision: Phase 1 preview switching happens only at stack startup through `LOCAL_TOPO_PREVIEW_STYLE_ID`, while the app-facing route and capability contract remain singular.
