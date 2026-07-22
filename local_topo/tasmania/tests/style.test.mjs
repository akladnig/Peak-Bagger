import assert from 'node:assert/strict';
import { access, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import test from 'node:test';

const stackRoot = new URL('..', import.meta.url).pathname;
const localGlyphsPath = '{fontstack}/{range}.pbf';
const localSpriteBase = 'sprite';
const localSpriteFiles = [
  'sprites/sprite.json',
  'sprites/sprite.png',
  'sprites/sprite@2x.json',
  'sprites/sprite@2x.png',
];
const previewStyleVariants = [
  {
    styleId: 'tasmania-maptiler-topo',
    stylePath: 'styles/local-topo/maptiler-topo.json',
    decisionsPath: 'styles/local-topo/maptiler-topo.port-decisions.json',
  },
  {
    styleId: 'tasmania-maptiler-outdoor',
    stylePath: 'styles/local-topo/maptiler-outdoor.json',
    decisionsPath: 'styles/local-topo/maptiler-outdoor.port-decisions.json',
  },
];
const localPreviewSourceUrls = new Set([
  'mbtiles://{tasmania-osm}',
  'mbtiles://{tasmania-contours}',
  'mbtiles://{tasmania-relief}',
]);
const allowedPortDecisionIssueTypes = new Set([
  'source_remap',
  'font_rewrite',
  'text_only',
  'dropped',
  'unsupported_layer',
  'other',
]);

async function loadJson(relativePath) {
  return JSON.parse(await readFile(join(stackRoot, relativePath), 'utf8'));
}

async function assertLocalSpriteBundleExists() {
  await Promise.all(
    localSpriteFiles.map((relativePath) => access(join(stackRoot, relativePath))),
  );
}

test('canonical richer Local Topo style includes relief, labels, and no mountain peak labels', async () => {
  const style = await loadJson('styles/local-topo/style.json');

  assert.equal(style.glyphs, localGlyphsPath);
  assert.equal(style.sources['tasmania-relief']?.type, 'raster');

  const layers = new Map(style.layers.map((layer) => [layer.id, layer]));
  assert.ok(layers.has('terrain-relief-shading'));
  assert.ok(layers.has('place-labels'));
  assert.ok(layers.has('water-name-labels'));
  assert.ok(layers.has('waterway-labels'));
  assert.ok(layers.has('road-labels'));
  assert.ok(layers.has('path-labels'));
  assert.ok(layers.has('contours-index-100m'));
  assert.ok(layers.has('contour-labels-100m'));

  const contourLayer = layers.get('contours');
  assert.equal(contourLayer?.minzoom, 12);

  const contourIndexLayer = layers.get('contours-index-100m');
  assert.equal(contourIndexLayer?.paint?.['line-color'], '#6f4f2d');

  const contourLabelLayer = layers.get('contour-labels-100m');
  assert.equal(contourLabelLayer?.layout?.['symbol-placement'], 'line');
  assert.deepEqual(contourLabelLayer?.layout?.['text-font'], ['Roboto Regular']);

  const sourceLayers = style.layers
    .map((layer) => layer['source-layer'])
    .filter((value) => typeof value === 'string');
  assert.equal(sourceLayers.includes('mountain_peak'), false);
});

test('MapTiler preview variants stay on local sprite, glyph, and source contracts', async () => {
  const config = await loadJson('config/tileserver-config.json');
  await assertLocalSpriteBundleExists();

  for (const variant of previewStyleVariants) {
    const style = await loadJson(variant.stylePath);
    const decisions = await loadJson(variant.decisionsPath);
    const layers = new Map(style.layers.map((layer) => [layer.id, layer]));

    assert.equal(config.styles[variant.styleId]?.style, variant.stylePath.replace('styles/', ''));
    assert.equal(style.glyphs, localGlyphsPath);
    assert.equal(style.sprite, localSpriteBase);
    assert.deepEqual(
      Object.keys(style.sources).sort(),
      ['tasmania-contours', 'tasmania-osm', 'tasmania-relief'],
    );

    for (const source of Object.values(style.sources)) {
      assert.equal(source.url.startsWith('http'), false);
      assert.equal(localPreviewSourceUrls.has(source.url), true);
    }

    for (const layer of style.layers) {
      if (layer.source != null) {
        assert.equal(
          ['tasmania-contours', 'tasmania-osm', 'tasmania-relief'].includes(layer.source),
          true,
        );
      }

      const textFont = layer.layout?.['text-font'];
      if (textFont != null) {
        assert.deepEqual(textFont, ['Roboto Regular']);
      }
    }

    assert.equal(Array.isArray(decisions), true);
    assert.equal(decisions.length > 0, true);

    for (const decision of decisions) {
      assert.equal(typeof decision.upstreamLayerId, 'string');
      assert.equal(allowedPortDecisionIssueTypes.has(decision.issueType), true);
      assert.equal(typeof decision.action, 'string');
      assert.equal(typeof decision.reason, 'string');

      const layer = layers.get(decision.upstreamLayerId);
      if (decision.issueType === 'dropped') {
        assert.equal(layer, undefined);
        continue;
      }

      assert.notEqual(layer, undefined);

      if (decision.issueType === 'font_rewrite') {
        assert.deepEqual(layer.layout?.['text-font'], ['Roboto Regular']);
      }

      if (decision.issueType === 'source_remap') {
        assert.equal(
          ['tasmania-contours', 'tasmania-osm', 'tasmania-relief'].includes(layer.source),
          true,
        );
      }

      if (decision.issueType === 'unsupported_layer') {
        assert.equal(layer.type, 'raster');
        assert.equal(layer.source, 'tasmania-relief');
      }
    }
  }
});

test('cartography review fixture covers low, mid, and high representative tiles for both MapTiler preview variants', async () => {
  const fixture = await loadJson('fixtures/cartography-review.json');
  const styleReviews = fixture.styleReviews;

  assert.deepEqual(
    Object.keys(styleReviews).sort(),
    ['tasmania-maptiler-outdoor', 'tasmania-maptiler-topo'],
  );

  for (const [styleId, styleReview] of Object.entries(styleReviews)) {
    assert.equal(typeof styleId, 'string');
    assert.equal(Array.isArray(styleReview.variantExpectations), true);
    assert.equal(styleReview.variantExpectations.length > 0, true);

    const zooms = styleReview.tiles.map((tile) => tile.z).sort((left, right) => left - right);
    assert.deepEqual(zooms, [10, 12, 14]);

    for (const tile of styleReview.tiles) {
      assert.equal(Array.isArray(tile.expectations), true);
      assert.equal(tile.expectations.length > 0, true);
    }
  }
});

test('openstreetmap preview style includes local contour overlays and is registered in tileserver config', async () => {
  const style = await loadJson('styles/local-topo/openstreetmap.json');
  const config = await loadJson('config/tileserver-config.json');

  assert.equal(style.sources['tasmania-contours']?.type, 'vector');

  const layers = new Map(style.layers.map((layer) => [layer.id, layer]));
  assert.ok(layers.has('Contours'));
  assert.ok(layers.has('Contours intermediate 50m'));
  assert.ok(layers.has('Contours index 100m'));
  assert.ok(layers.has('Contour labels 100m'));
  assert.equal(layers.get('Contours index 100m')?.paint?.['line-color'], '#6b5337');
  assert.deepEqual(
    layers.get('Contour labels 100m')?.layout?.['text-font'],
    ['Roboto Regular'],
  );

  assert.equal(
    config.styles['tasmania-openstreetmap-contours']?.style,
    'local-topo/openstreetmap.json',
  );
});
