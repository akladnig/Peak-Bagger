import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { join } from 'node:path';
import test from 'node:test';

const stackRoot = new URL('..', import.meta.url).pathname;

async function loadJson(relativePath) {
  return JSON.parse(await readFile(join(stackRoot, relativePath), 'utf8'));
}

test('canonical richer Local Topo style includes relief, labels, and no mountain peak labels', async () => {
  const style = await loadJson('styles/local-topo/style.json');

  assert.equal(style.glyphs, '{fontstack}/{range}.pbf');
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

test('cartography review fixture covers low, mid, and high representative tiles', async () => {
  const fixture = await loadJson('fixtures/cartography-review.json');
  const zooms = fixture.tiles.map((tile) => tile.z).sort((left, right) => left - right);

  assert.deepEqual(zooms, [10, 12, 14]);
  for (const tile of fixture.tiles) {
    assert.equal(Array.isArray(tile.expectations), true);
    assert.equal(tile.expectations.length > 0, true);
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
