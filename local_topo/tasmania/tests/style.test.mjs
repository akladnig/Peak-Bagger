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

  const contourLayer = layers.get('contours');
  assert.equal(contourLayer?.minzoom, 12);

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
