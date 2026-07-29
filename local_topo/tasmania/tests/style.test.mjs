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
const martinRequiredSourceLayers = [
  'boundary',
  'building',
  'landuse',
  'park',
  'place',
  'transportation',
  'transportation_name',
];
const martinWaterExceptionSourceLayers = ['water', 'water_name', 'waterway'];
const martinLandcoverExceptionSourceLayers = ['landcover'];
const martinDeferredSourceLayers = new Set([
  'aerodrome_label',
  'aeroway',
  'housenumber',
  'mountain_peak',
  'poi',
]);
const localPreviewSourceUrls = new Set([
  'mbtiles://{tasmania-osm}',
  'mbtiles://{tasmania-contours}',
  'mbtiles://{tasmania-relief}',
]);
const martinOpenmaptilesSourceUrl =
  'http://martin:3000/boundary,building,landcover,landuse,park,place,transportation,transportation_name,water,water_name,waterway';
const legacyOpenmaptilesSourceUrl = 'mbtiles://{tasmania-osm}';
const openStreetMapComparisonVariants = [
  {
    styleId: 'tasmania-openstreetmap-contours-martin',
    stylePath: 'styles/local-topo/openstreetmap-martin.json',
    openmaptilesSource: {
      type: 'vector',
      url: martinOpenmaptilesSourceUrl,
    },
  },
  {
    styleId: 'tasmania-openstreetmap-contours',
    stylePath: 'styles/local-topo/openstreetmap.json',
    openmaptilesSource: {
      type: 'vector',
      url: 'mbtiles://{tasmania-osm}',
    },
  },
];
const landcoverClassFallback = [
  'coalesce',
  ['get', 'subclass'],
  ['get', 'class'],
];
const landcoverPatternClasses = [
  'allotments',
  'bare_rock',
  'beach',
  'bog',
  'dune',
  'scrub',
  'farm',
  'farmland',
  'forest',
  'grass',
  'grassland',
  'golf_course',
  'heath',
  'mangrove',
  'marsh',
  'meadow',
  'orchard',
  'park',
  'plant_nursery',
  'recreation_ground',
  'reedbed',
  'saltern',
  'saltmarsh',
  'sand',
  'scree',
  'swamp',
  'village_green',
  'vineyard',
  'wet_meadow',
  'wetland',
  'wood',
];
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

function getMatchExpressionValue(expression, input) {
  assert.equal(Array.isArray(expression), true);
  assert.equal(expression[0], 'match');

  for (let index = 2; index < expression.length - 1; index += 2) {
    if (expression[index] === input) {
      return expression[index + 1];
    }
  }

  return expression.at(-1);
}

function getInExpressionValues(expression) {
  assert.equal(Array.isArray(expression), true);
  assert.equal(expression[0], 'in');
  return expression[2]?.[1];
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

test('OpenStreetMap comparison preview styles keep local sprite contract and targeted water and scrub wiring', async () => {
  const config = await loadJson('config/tileserver-config.json');
  await assertLocalSpriteBundleExists();

  for (const variant of openStreetMapComparisonVariants) {
    const style = await loadJson(variant.stylePath);
    const layers = new Map(style.layers.map((layer) => [layer.id, layer]));

    assert.equal(config.styles[variant.styleId]?.style, variant.stylePath.replace('styles/', ''));
    assert.equal(style.sprite, localSpriteBase);
    assert.equal(style.glyphs, localGlyphsPath);
    assert.deepEqual(style.sources.openmaptiles, variant.openmaptilesSource);

    const expectedWaterSource =
      variant.styleId === 'tasmania-openstreetmap-contours-martin'
        ? 'openmaptiles-water'
        : 'openmaptiles';
    const expectedLandcoverSource =
      variant.styleId === 'tasmania-openstreetmap-contours-martin'
        ? 'openmaptiles-landcover'
        : 'openmaptiles';
    if (variant.styleId === 'tasmania-openstreetmap-contours-martin') {
      assert.deepEqual(style.sources['openmaptiles-water'], {
        type: 'vector',
        url: legacyOpenmaptilesSourceUrl,
      });
      assert.deepEqual(style.sources['openmaptiles-landcover'], {
        type: 'vector',
        url: legacyOpenmaptilesSourceUrl,
      });
    }

    assert.deepEqual(layers.get('Scrub')?.paint, {
      'fill-antialias': true,
      'fill-color': 'hsl(80, 35%, 76%)',
    });
    assert.equal(layers.get('Scrub')?.source, expectedLandcoverSource);
    assert.deepEqual(layers.get('Scrub')?.filter?.[1], ['==', landcoverClassFallback, 'scrub']);
    assert.equal(layers.get('Wood')?.source, expectedLandcoverSource);
    assert.deepEqual(layers.get('Wood')?.filter?.[1], ['==', landcoverClassFallback, 'wood']);
    assert.equal(layers.get('Scree')?.source, expectedLandcoverSource);
    assert.deepEqual(layers.get('Scree')?.filter?.[1], ['==', landcoverClassFallback, 'scree']);
    assert.equal(layers.get('Bare rock')?.source, expectedLandcoverSource);
    assert.deepEqual(layers.get('Bare rock')?.filter?.[1], [
      '==',
      landcoverClassFallback,
      'bare_rock',
    ]);
    assert.deepEqual(layers.get('Water intermittent')?.paint, {
      'fill-color': 'hsl(205, 91%, 83%)',
      'fill-opacity': 0.85,
    });
    assert.equal(layers.get('River tunnel')?.source, expectedWaterSource);
    assert.equal(layers.get('River')?.source, expectedWaterSource);
    assert.equal(layers.get('River intermittent')?.source, expectedWaterSource);
    assert.equal(layers.get('Other waterway')?.source, expectedWaterSource);
    assert.equal(layers.get('Other waterway intermittent')?.source, expectedWaterSource);
    assert.equal(layers.get('Water intermittent')?.source, expectedWaterSource);
    assert.equal(layers.get('Water')?.source, expectedWaterSource);
    assert.deepEqual(layers.get('Water')?.paint, {
      'fill-color': 'hsl(194, 45%, 77%)',
    });
    assert.equal(layers.get('River tunnel')?.paint?.['line-color'], 'hsl(210, 73%, 78%)');
    assert.equal(layers.get('River')?.paint?.['line-color'], 'hsl(210, 73%, 78%)');
    assert.equal(layers.get('River intermittent')?.paint?.['line-color'], 'hsl(210, 73%, 78%)');
    assert.equal(layers.get('Other waterway')?.paint?.['line-color'], 'hsl(210, 73%, 78%)');
    assert.equal(
      layers.get('Other waterway intermittent')?.paint?.['line-color'],
      'hsl(210, 73%, 78%)',
    );

    const landcoverPatterns = layers.get('Landcover patterns');
    assert.equal(landcoverPatterns?.source, expectedLandcoverSource);
    assert.deepEqual(landcoverPatterns?.filter?.[1]?.[1], landcoverClassFallback);
    assert.deepEqual(getInExpressionValues(landcoverPatterns?.filter?.[1]), landcoverPatternClasses);
    assert.equal(
      getMatchExpressionValue(landcoverPatterns?.paint?.['fill-opacity'], 'scrub'),
      0.6,
    );
    assert.deepEqual(landcoverPatterns?.paint?.['fill-opacity']?.[1], landcoverClassFallback);
    assert.equal(
      getMatchExpressionValue(landcoverPatterns?.paint?.['fill-pattern'], 'scrub'),
      'scrub',
    );
    assert.deepEqual(landcoverPatterns?.paint?.['fill-pattern']?.[1], landcoverClassFallback);
  }
});

test('all supported LOCAL_TOPO_STYLE preview ids are registered in tileserver config', async () => {
  const config = await loadJson('config/tileserver-config.json');

  assert.deepEqual(
    {
      'tasmania-openstreetmap-contours-martin': config.styles['tasmania-openstreetmap-contours-martin']?.style,
      'tasmania-openstreetmap-contours': config.styles['tasmania-openstreetmap-contours']?.style,
      'tasmania-maptiler-topo': config.styles['tasmania-maptiler-topo']?.style,
      'tasmania-maptiler-outdoor': config.styles['tasmania-maptiler-outdoor']?.style,
    },
    {
      'tasmania-openstreetmap-contours-martin': 'local-topo/openstreetmap-martin.json',
      'tasmania-openstreetmap-contours': 'local-topo/openstreetmap.json',
      'tasmania-maptiler-topo': 'local-topo/maptiler-topo.json',
      'tasmania-maptiler-outdoor': 'local-topo/maptiler-outdoor.json',
    },
  );
});

test('Martin openstreetmap preview style stays within the first-slice compatibility boundary', async () => {
  const legacyStyle = await loadJson('styles/local-topo/openstreetmap.json');
  const martinStyle = await loadJson('styles/local-topo/openstreetmap-martin.json');
  const config = await loadJson('config/tileserver-config.json');

  assert.equal(
    config.styles['tasmania-openstreetmap-contours-martin']?.style,
    'local-topo/openstreetmap-martin.json',
  );

  const legacyLayers = new Map(legacyStyle.layers.map((layer) => [layer.id, layer]));
  const martinLayers = new Map(martinStyle.layers.map((layer) => [layer.id, layer]));

  assert.deepEqual(Object.keys(martinStyle.sources).sort(), [
    ...Object.keys(legacyStyle.sources),
    'openmaptiles-landcover',
    'openmaptiles-water',
  ].sort());
  assert.deepEqual(martinStyle.sources['openmaptiles'], {
    type: 'vector',
    url: martinOpenmaptilesSourceUrl,
  });
  assert.deepEqual(martinStyle.sources['openmaptiles-water'], {
    type: 'vector',
    url: legacyOpenmaptilesSourceUrl,
  });
  assert.deepEqual(martinStyle.sources['openmaptiles-landcover'], {
    type: 'vector',
    url: legacyOpenmaptilesSourceUrl,
  });
  assert.deepEqual(legacyStyle.sources['openmaptiles'], {
    type: 'vector',
    url: legacyOpenmaptilesSourceUrl,
  });
  assert.deepEqual(martinStyle.sources['tasmania-contours'], legacyStyle.sources['tasmania-contours']);
  assert.deepEqual(martinStyle.sources['tasmania-relief'], legacyStyle.sources['tasmania-relief']);

  for (const [layerId, legacyLayer] of legacyLayers) {
    if (martinDeferredSourceLayers.has(legacyLayer['source-layer'])) {
      assert.equal(martinLayers.has(layerId), false);
      continue;
    }

    if (martinLandcoverExceptionSourceLayers.includes(legacyLayer['source-layer'])) {
      assert.deepEqual(martinLayers.get(layerId), {
        ...legacyLayer,
        source: 'openmaptiles-landcover',
      });
      continue;
    }

    if (martinWaterExceptionSourceLayers.includes(legacyLayer['source-layer'])) {
      assert.deepEqual(martinLayers.get(layerId), {
        ...legacyLayer,
        source: 'openmaptiles-water',
      });
      continue;
    }

    assert.deepEqual(martinLayers.get(layerId), legacyLayer);
  }

  const martinOpenmaptilesSourceLayers = [...new Set(
    martinStyle.layers
      .filter((layer) => layer.source === 'openmaptiles')
      .map((layer) => layer['source-layer'])
      .filter((value) => typeof value === 'string'),
  )].sort();
  assert.deepEqual(martinOpenmaptilesSourceLayers, martinRequiredSourceLayers);

  const martinLegacyWaterSourceLayers = [...new Set(
    martinStyle.layers
      .filter((layer) => layer.source === 'openmaptiles-water')
      .map((layer) => layer['source-layer'])
      .filter((value) => typeof value === 'string'),
  )].sort();
  assert.deepEqual(martinLegacyWaterSourceLayers, martinWaterExceptionSourceLayers);

  const martinLegacyLandcoverSourceLayers = [...new Set(
    martinStyle.layers
      .filter((layer) => layer.source === 'openmaptiles-landcover')
      .map((layer) => layer['source-layer'])
      .filter((value) => typeof value === 'string'),
  )].sort();
  assert.deepEqual(martinLegacyLandcoverSourceLayers, martinLandcoverExceptionSourceLayers);

  const metadataLayerIds = martinStyle.metadata.maptiler.groups.flatMap((group) => group.layers);
  for (const layerId of metadataLayerIds) {
    assert.equal(martinLayers.has(layerId), true);
  }
});
