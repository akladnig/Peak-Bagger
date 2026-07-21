# Canonical Style

`style.json` is the committed canonical Tasmania `Local Topo` style.

Use `Maputnik` as the developer-only authoring tool for this file.

- Open the style in `Maputnik`.
- Keep the committed source names aligned with `config/tileserver-config.json`.
- Commit the exported style JSON back into this directory.
- If you add symbol or icon layers later, commit the required sprite and glyph assets under `sprites/` and `fonts/` in the same change.

The richer Tasmania style now uses committed `fonts/Roboto Regular/*.pbf` glyph assets and still avoids sprite-backed icons so `Local Topo` remains the sole basemap presentation layer.
