# Canonical Style

`style.json` is the committed canonical Tasmania `Local Topo` style.

Use `Maputnik` as the developer-only authoring tool for this file.

- Open the style in `Maputnik`.
- Keep the committed source names aligned with `config/tileserver-config.json`.
- Commit the exported style JSON back into this directory.
- If you add symbol or icon layers later, commit the required sprite and glyph assets under `sprites/` and `fonts/` in the same change.

The current v1 style intentionally avoids symbol and icon layers so the stack can stay focused on the exact server contract first.
