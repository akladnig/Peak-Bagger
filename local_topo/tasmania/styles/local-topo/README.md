# Canonical Style

`style.json` is the committed canonical Tasmania `Local Topo` style.

Use `Maputnik` as the developer-only authoring tool for this file.

## Modify The Style

- Open `style.json` in `Maputnik`.
- Keep the committed source names aligned with `../../config/tileserver-config.json`.
- Export the updated style back into this directory as `style.json`.
- Commit the exported JSON with any related asset changes.
- If you add symbol or icon layers later, commit the required sprite and glyph assets under `sprites/` and `fonts/` in the same change.

The richer Tasmania style now uses committed `fonts/Roboto Regular/*.pbf` glyph assets and still avoids sprite-backed icons so `Local Topo` remains the sole basemap presentation layer.

## Download MapTiler Styles

If you want a MapTiler style such as `Outdoor` or `Topo` as a starting point, download the style JSON from the MapTiler Maps API.

```bash
export MAPTILER_KEY="your_key_here"

curl -L \
  "https://api.maptiler.com/maps/{mapId}/style.json?key=${MAPTILER_KEY}" \
  -o downloaded-style.json
```

- Replace `{mapId}` with the exact style id shown in your MapTiler account under `Maps`.
- Common ids are often similar to `outdoor-v2` or `topo-v2`, but check the account instead of guessing.

Example:

```bash
curl -L \
  "https://api.maptiler.com/maps/outdoor-v2/style.json?key=${MAPTILER_KEY}" \
  -o outdoor.json

curl -L \
  "https://api.maptiler.com/maps/topo-v2/style.json?key=${MAPTILER_KEY}" \
  -o topo.json
```

If you also need the sprite assets referenced by the style:

```bash
curl -L \
  "https://api.maptiler.com/maps/{mapId}/sprite.json?key=${MAPTILER_KEY}" \
  -o sprite.json

curl -L \
  "https://api.maptiler.com/maps/{mapId}/sprite.png?key=${MAPTILER_KEY}" \
  -o sprite.png
```

Notes:

- Downloading `style.json` alone does not make the style fully local.
- Downloaded MapTiler styles usually still reference remote vector tiles, sprites, and glyphs.
- To use one in this repo, save it under `styles/local-topo/`, rewrite its sources onto the committed `tasmania-osm`, `tasmania-contours`, and `tasmania-relief` sources, localize `sprite` to the committed `sprite` base, and keep `glyphs` on `{fontstack}/{range}.pbf`.
- The committed preview rewrites are `maptiler-topo.json` and `maptiler-outdoor.json`, registered as `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor`.
- After the rewrite is committed, the repo no longer needs a MapTiler API key to preview those variants.

## Preview Style Changes

Preview mode renders the committed style on demand from the existing rebuilt MBTiles inputs.

From `local_topo/tasmania/` run:

```bash
npm run stack:up:preview
```

Then open the local stack at `http://127.0.0.1:8090` through the normal app or tile endpoints.

To preview the OpenStreetMap-based style variant with local contour overlays instead, run:

```bash
LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-openstreetmap-contours npm run stack:up:preview
```

To preview the localized MapTiler Topo variant, run:

```bash
LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-topo npm run stack:up:preview
```

To preview the localized MapTiler Outdoor variant, run:

```bash
LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-outdoor npm run stack:up:preview
```

To capture the committed representative cartography review tiles for either localized MapTiler preview variant without overwriting the other variant's output, run the matching review command after preview startup:

```bash
npm run review:cartography -- --style-id=tasmania-maptiler-topo
npm run review:cartography -- --style-id=tasmania-maptiler-outdoor
```

Notes:

- Preview mode requires `output/tasmania-osm.mbtiles`, `output/tasmania-relief.mbtiles`, and `output/tasmania-contours.mbtiles` to already exist.
- Phase 1 preview switching stays startup-scoped through `LOCAL_TOPO_PREVIEW_STYLE_ID`; the app-facing `Local Topo` route and capabilities contract stay unchanged.
- If preview is already running, restart it after changing `style.json`:

```bash
npm run stack:down
npm run stack:up:preview
```

- Style-only preview does not require `npm run refresh:manual` as long as the MBTiles inputs already exist.

## Update The Static Stack

The default stack serves pre-rendered PNG tiles from `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png`.

Changing `style.json` does not update those static PNGs by itself. To bake a new style into the static stack, rerun the manual refresh from `local_topo/tasmania/`:

```bash
npm run refresh:manual
```

That rebuild path also prerenders the static tile tree used by the default stack.

After the refresh completes, start or restart the default static stack:

```bash
npm run stack:down
npm run stack:up
```

## Practical Rule

- Use `npm run stack:up:preview` while iterating on style changes.
- Use `npm run refresh:manual` when you want the normal static stack to serve the new style.
