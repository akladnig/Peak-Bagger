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
    contourMinzoomByLayerId: {
      Contours: 12,
      'Contours intermediate 50m': 11,
      'Contours index 100m': 11,
    },
  },
  {
    styleId: 'tasmania-openstreetmap-contours',
    stylePath: 'styles/local-topo/openstreetmap.json',
    openmaptilesSource: {
      type: 'vector',
      url: 'mbtiles://{tasmania-osm}',
    },
    contourMinzoomByLayerId: {
      Contours: 13,
      'Contours intermediate 50m': 12,
      'Contours index 100m': 12,
    },
  },
];
const martinLayerOverrides = new Map([
  ['Contours', { minzoom: 12 }],
  ['Contours intermediate 50m', { minzoom: 11 }],
  ['Contours index 100m', { minzoom: 11 }],
  ['Track road outline', {
    filter: [
      'all',
      ['!in', 'brunnel', 'bridge', 'tunnel'],
      [
        'any',
        ['in', 'class', 'track'],
        [
          'all',
          ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
          ['in', 'surface', 'gravel', 'fine_gravel', 'unpaved', 'dirt', 'earth'],
        ],
      ],
    ],
  }],
  ['Track road', {
    filter: [
      'all',
      ['!in', 'brunnel', 'bridge', 'tunnel'],
      [
        'any',
        ['in', 'class', 'track'],
        [
          'all',
          ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
          ['in', 'surface', 'gravel', 'fine_gravel', 'unpaved', 'dirt', 'earth'],
        ],
      ],
    ],
  }],
  ['Minor tunnel', {
    filter: [
      'all',
      ['==', 'brunnel', 'tunnel'],
      ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
    ],
  }],
  ['Minor road outline', {
    filter: [
      'all',
      ['==', '$type', 'LineString'],
      ['!in', 'brunnel', 'bridge', 'tunnel'],
      ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
      ['!=', 'ramp', '1'],
    ],
  }],
  ['Minor road', {
    filter: [
      'all',
      ['==', '$type', 'LineString'],
      ['!in', 'brunnel', 'bridge', 'tunnel'],
      ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
    ],
  }],
  ['Minor bridge', {
    filter: [
      'all',
      ['==', 'brunnel', 'bridge'],
      ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
    ],
  }],
]);
const martinRoadWidthOverrideLayerIds = new Set([
  'Service road outline',
  'Track road outline',
  'Tertiary road link outline',
  'Secondary road link outline',
  'Primary road link outline',
  'Trunk road link outline',
  'Highway link outline',
  'Minor road outline',
  'Tertiary road outline',
  'Secondary road outline',
  'Trunk road outline',
  'Primary road outline',
  'Highway road outline',
  'Service road under construction',
  'Minor road under construction',
  'Minor road under construction dash',
  'Tertiary road under construction',
  'Tertiary road under construction dash',
  'Secondary road under construction',
  'Secondary road under construction dash',
  'Primary road under construction',
  'Primary road under construction dash',
  'Trunk road under construction',
  'Trunk road under construction dash',
  'Highway road under construction',
  'Highway road under construction dash',
  'Tertiary road link',
  'Secondary road link',
  'Primary road link',
  'Trunk road link',
  'Highway road link',
  'Service road',
  'Track road',
  'Minor road',
  'Tertiary road',
  'Secondary road',
  'Primary road',
  'Trunk road',
  'Highway road',
  'Raceway road',
]);
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

function getStopPairs(value) {
  if (Array.isArray(value)) {
    assert.equal(value[0], 'interpolate');
    const stops = [];

    for (let index = 3; index < value.length; index += 2) {
      stops.push([value[index], value[index + 1]]);
    }

    return stops;
  }

  assert.equal(Array.isArray(value?.stops), true);
  return value.stops;
}

function assertStrongerSharedStops({ strongerLayer, weakerLayer, paintKey }) {
  const strongerStops = new Map(getStopPairs(strongerLayer?.paint?.[paintKey]));
  const weakerStops = new Map(getStopPairs(weakerLayer?.paint?.[paintKey]));
  const sharedZooms = [...strongerStops.keys()].filter((zoom) => weakerStops.has(zoom));

  assert.equal(sharedZooms.length > 0, true);

  for (const zoom of sharedZooms) {
    assert.equal(strongerStops.get(zoom) > weakerStops.get(zoom), true);
  }
}

function assertLayerOrder({ layerIndexes, lowerIds, higherIds }) {
  for (const lowerId of lowerIds) {
    assert.notEqual(layerIndexes.get(lowerId), undefined);

    for (const higherId of higherIds) {
      assert.notEqual(layerIndexes.get(higherId), undefined);
      assert.equal(layerIndexes.get(lowerId) < layerIndexes.get(higherId), true);
    }
  }
}

function withMartinLineWidthOverride(layerId, expectedLayer, martinLayer) {
  if (!martinRoadWidthOverrideLayerIds.has(layerId)) {
    return expectedLayer;
  }

  return {
    ...expectedLayer,
    paint: {
      ...expectedLayer.paint,
      'line-width': martinLayer?.paint?.['line-width'],
    },
  };
}

function assertStandingWaterMaskLayers({
  style,
  maskLayerIds,
  contourLineLayerIds,
  contourLabelLayerIds,
  waterLabelLayerIds,
  waterwayLineLayerIds,
  expectedLayers,
}) {
  const layers = new Map(style.layers.map((layer) => [layer.id, layer]));
  const layerIndexes = new Map(style.layers.map((layer, index) => [layer.id, index]));

  for (let index = 0; index < maskLayerIds.length; index += 1) {
    const layerId = maskLayerIds[index];
    const layer = layers.get(layerId);
    const expectedLayer = expectedLayers[index];

    assert.notEqual(layer, undefined);
    assert.equal(layer?.type, 'fill');
    assert.equal(layer?.source, expectedLayer.source);
    assert.equal(layer?.['source-layer'], 'water');
    assert.deepEqual(layer?.filter, expectedLayer.filter);
    assert.deepEqual(layer?.paint, expectedLayer.paint);
  }

  assertLayerOrder({
    layerIndexes,
    lowerIds: contourLineLayerIds,
    higherIds: maskLayerIds,
  });
  assertLayerOrder({
    layerIndexes,
    lowerIds: contourLabelLayerIds,
    higherIds: maskLayerIds,
  });
  assertLayerOrder({
    layerIndexes,
    lowerIds: maskLayerIds,
    higherIds: waterLabelLayerIds,
  });
  assertLayerOrder({
    layerIndexes,
    lowerIds: waterwayLineLayerIds,
    higherIds: contourLabelLayerIds,
  });
}

test('canonical richer Local Topo style includes relief, labels, and no mountain peak labels', async () => {
  const style = await loadJson('styles/local-topo/style.json');
  const contourModuloFilter = ['%', ['to-number', ['get', 'elev']], 100];

  assert.equal(style.glyphs, localGlyphsPath);
  assert.equal(style.sources['tasmania-relief']?.type, 'raster');

  const layers = new Map(style.layers.map((layer) => [layer.id, layer]));
  assert.ok(layers.has('terrain-relief-shading'));
  assert.ok(layers.has('place-labels'));
  assert.ok(layers.has('water-name-labels'));
  assert.ok(layers.has('waterway-labels'));
  assert.ok(layers.has('road-labels'));
  assert.ok(layers.has('path-labels'));
  assert.ok(layers.has('contours-intermediate-50m'));
  assert.ok(layers.has('contours-index-100m'));
  assert.ok(layers.has('contour-labels-50m'));
  assert.ok(layers.has('contour-labels-100m'));

  const contourLayer = layers.get('contours');
  assert.equal(contourLayer?.minzoom, 13);
  assert.deepEqual(contourLayer?.filter, [
    'all',
    ['!=', contourModuloFilter, 0],
    ['!=', contourModuloFilter, 50],
  ]);

  const contourIntermediateLayer = layers.get('contours-intermediate-50m');
  assert.equal(contourIntermediateLayer?.minzoom, 12);
  assert.deepEqual(contourIntermediateLayer?.filter, ['==', contourModuloFilter, 50]);

  const contourIndexLayer = layers.get('contours-index-100m');
  assert.equal(contourIndexLayer?.minzoom, 12);
  assert.deepEqual(contourIndexLayer?.filter, ['==', contourModuloFilter, 0]);
  assert.equal(contourIndexLayer?.paint?.['line-color'], '#6f4f2d');
  assert.equal(contourIntermediateLayer?.paint?.['line-color'], '#7d5c37');
  assertStrongerSharedStops({
    strongerLayer: contourIndexLayer,
    weakerLayer: contourIntermediateLayer,
    paintKey: 'line-opacity',
  });
  assertStrongerSharedStops({
    strongerLayer: contourIndexLayer,
    weakerLayer: contourIntermediateLayer,
    paintKey: 'line-width',
  });

  const contourIntermediateLabelLayer = layers.get('contour-labels-50m');
  assert.equal(contourIntermediateLabelLayer?.minzoom, 13);
  assert.equal(contourIntermediateLabelLayer?.layout?.['symbol-placement'], 'line');
  assert.equal(contourIntermediateLabelLayer?.layout?.['text-rotate'], 0);
  assert.equal(contourIntermediateLabelLayer?.layout?.['text-keep-upright'], true);
  assert.deepEqual(contourIntermediateLabelLayer?.filter, ['==', contourModuloFilter, 50]);
  assert.deepEqual(contourIntermediateLabelLayer?.layout?.['text-font'], ['Roboto Regular']);
  assert.deepEqual(contourIntermediateLabelLayer?.layout?.['text-field'], [
    'concat',
    ['to-string', ['get', 'elev']],
    ' m',
  ]);

  const contourLabelLayer = layers.get('contour-labels-100m');
  assert.equal(contourLabelLayer?.minzoom, 13);
  assert.equal(contourLabelLayer?.layout?.['symbol-placement'], 'line');
  assert.equal(contourLabelLayer?.layout?.['text-rotate'], 0);
  assert.equal(contourLabelLayer?.layout?.['text-keep-upright'], true);
  assert.deepEqual(contourLabelLayer?.filter, ['==', contourModuloFilter, 0]);
  assert.deepEqual(contourLabelLayer?.layout?.['text-font'], ['Roboto Regular']);
  assert.deepEqual(contourLabelLayer?.layout?.['text-field'], [
    'concat',
    ['to-string', ['get', 'elev']],
    ' m',
  ]);
  assert.equal(contourIntermediateLabelLayer?.paint?.['text-color'], '#7d5c37');
  assert.equal(contourLabelLayer?.paint?.['text-color'], '#6f4f2d');
  assertStandingWaterMaskLayers({
    style,
    maskLayerIds: ['standing-water-mask-intermittent', 'standing-water-mask'],
    contourLineLayerIds: ['contours', 'contours-intermediate-50m', 'contours-index-100m'],
    contourLabelLayerIds: ['contour-labels-50m', 'contour-labels-100m'],
    waterLabelLayerIds: ['water-name-labels'],
    waterwayLineLayerIds: ['waterway'],
    expectedLayers: [
      {
        source: 'tasmania-osm',
        filter: [
          'all',
          ['match', ['get', 'class'], ['lake', 'pond'], true, false],
          ['==', ['get', 'intermittent'], 1],
        ],
        paint: {
          'fill-color': '#9fd2f3',
          'fill-opacity': 0.9,
        },
      },
      {
        source: 'tasmania-osm',
        filter: [
          'all',
          ['match', ['get', 'class'], ['lake', 'pond'], true, false],
          ['!=', ['get', 'intermittent'], 1],
        ],
        paint: {
          'fill-color': '#9fd2f3',
          'fill-opacity': 0.9,
        },
      },
    ],
  });

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

  for (const styleId of ['tasmania-maptiler-topo', 'tasmania-maptiler-outdoor']) {
    const styleReview = styleReviews[styleId];

    assert.equal(typeof styleId, 'string');
    assert.notEqual(styleReview, undefined);
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

test('cartography review fixture includes the supported Martin contour review path at zooms 12 and 13', async () => {
  const fixture = await loadJson('fixtures/cartography-review.json');
  const styleReview = fixture.styleReviews['tasmania-openstreetmap-contours-martin'];

  assert.notEqual(styleReview, undefined);
  assert.equal(fixture.styleReviews['tasmania-openstreetmap-contours'], undefined);
  assert.equal(Array.isArray(styleReview.variantExpectations), true);
  assert.equal(styleReview.variantExpectations.length > 0, true);
  assert.deepEqual(
    styleReview.tiles.map((tile) => tile.z).sort((left, right) => left - right),
    [12, 13],
  );

  const expectations = styleReview.tiles.flatMap((tile) => tile.expectations);
  assert.equal(expectations.some((expectation) => expectation.includes('50 m contour')), true);
  assert.equal(expectations.some((expectation) => expectation.includes('100 m contour')), true);
  assert.equal(expectations.some((expectation) => expectation.includes('minor contour line')), true);
  assert.equal(expectations.some((expectation) => expectation.includes('rendering upside-down')), true);
  assert.equal(expectations.some((expectation) => expectation.includes('contour lines or contour labels inside')), true);
  assert.equal(expectations.some((expectation) => expectation.includes('shoreline')), true);
});

test('openstreetmap preview styles include aligned local contour overlays and are registered in tileserver config', async () => {
  const config = await loadJson('config/tileserver-config.json');
  const contourModuloFilter = ['%', ['to-number', ['get', 'elev']], 100];

  for (const variant of openStreetMapComparisonVariants) {
    const style = await loadJson(variant.stylePath);
    const layers = new Map(style.layers.map((layer) => [layer.id, layer]));

    assert.equal(style.sources['tasmania-contours']?.type, 'vector');
    assert.ok(layers.has('Contours'));
    assert.ok(layers.has('Contours intermediate 50m'));
    assert.ok(layers.has('Contours index 100m'));
    assert.ok(layers.has('Contour labels 50m'));
    assert.ok(layers.has('Contour labels 100m'));

    assert.equal(
      layers.get('Contours')?.minzoom,
      variant.contourMinzoomByLayerId['Contours'],
    );
    assert.deepEqual(layers.get('Contours')?.filter, [
      'all',
      ['!=', contourModuloFilter, 0],
      ['!=', contourModuloFilter, 50],
    ]);
    assert.equal(
      layers.get('Contours intermediate 50m')?.minzoom,
      variant.contourMinzoomByLayerId['Contours intermediate 50m'],
    );
    assert.deepEqual(layers.get('Contours intermediate 50m')?.filter, [
      '==',
      contourModuloFilter,
      50,
    ]);
    assert.equal(
      layers.get('Contours index 100m')?.minzoom,
      variant.contourMinzoomByLayerId['Contours index 100m'],
    );
    assert.deepEqual(layers.get('Contours index 100m')?.filter, ['==', contourModuloFilter, 0]);
    assert.equal(layers.get('Contours index 100m')?.paint?.['line-color'], '#6b5337');
    assert.equal(layers.get('Contours intermediate 50m')?.paint?.['line-color'], '#7c6547');
    assertStrongerSharedStops({
      strongerLayer: layers.get('Contours index 100m'),
      weakerLayer: layers.get('Contours intermediate 50m'),
      paintKey: 'line-opacity',
    });
    assertStrongerSharedStops({
      strongerLayer: layers.get('Contours index 100m'),
      weakerLayer: layers.get('Contours intermediate 50m'),
      paintKey: 'line-width',
    });

    assert.deepEqual(layers.get('Contour labels 50m')?.layout?.['text-font'], ['Roboto Regular']);
    assert.deepEqual(layers.get('Contour labels 50m')?.layout?.['text-field'], [
      'concat',
      ['to-string', ['get', 'elev']],
      ' m',
    ]);
    assert.equal(layers.get('Contour labels 50m')?.layout?.['symbol-placement'], 'line');
    assert.equal(layers.get('Contour labels 50m')?.layout?.['text-rotate'], 0);
    assert.equal(layers.get('Contour labels 50m')?.layout?.['text-keep-upright'], true);
    assert.equal(layers.get('Contour labels 50m')?.minzoom, 13);
    assert.deepEqual(layers.get('Contour labels 50m')?.filter, ['==', contourModuloFilter, 50]);

    assert.deepEqual(layers.get('Contour labels 100m')?.layout?.['text-font'], ['Roboto Regular']);
    assert.deepEqual(layers.get('Contour labels 100m')?.layout?.['text-field'], [
      'concat',
      ['to-string', ['get', 'elev']],
      ' m',
    ]);
    assert.equal(layers.get('Contour labels 100m')?.layout?.['symbol-placement'], 'line');
    assert.equal(layers.get('Contour labels 100m')?.layout?.['text-rotate'], 0);
    assert.equal(layers.get('Contour labels 100m')?.layout?.['text-keep-upright'], true);
    assert.equal(layers.get('Contour labels 100m')?.minzoom, 13);
    assert.deepEqual(layers.get('Contour labels 100m')?.filter, ['==', contourModuloFilter, 0]);
    assert.equal(layers.get('Contour labels 50m')?.paint?.['text-color'], '#7c6547');
    assert.equal(layers.get('Contour labels 100m')?.paint?.['text-color'], '#6b5337');
    assertStandingWaterMaskLayers({
      style,
      maskLayerIds: ['Standing water mask intermittent', 'Standing water mask'],
      contourLineLayerIds: ['Contours', 'Contours intermediate 50m', 'Contours index 100m'],
      contourLabelLayerIds: ['Contour labels 50m', 'Contour labels 100m'],
      waterLabelLayerIds: ['Lakeline labels', 'Water labels'],
      waterwayLineLayerIds: [
        'River tunnel',
        'River',
        'River intermittent',
        'Other waterway',
        'Other waterway intermittent',
      ],
      expectedLayers: [
        {
          source: variant.styleId === 'tasmania-openstreetmap-contours-martin'
            ? 'openmaptiles-water'
            : 'openmaptiles',
          filter: [
            'all',
            ['in', 'class', 'lake', 'pond'],
            ['==', 'intermittent', 1],
          ],
          paint: {
            'fill-color': 'hsl(205, 91%, 83%)',
            'fill-opacity': 0.85,
          },
        },
        {
          source: variant.styleId === 'tasmania-openstreetmap-contours-martin'
            ? 'openmaptiles-water'
            : 'openmaptiles',
          filter: [
            'all',
            ['in', 'class', 'lake', 'pond'],
            ['!=', 'intermittent', 1],
            ['!=', 'brunnel', 'tunnel'],
          ],
          paint: {
            'fill-color': 'hsl(194, 45%, 77%)',
          },
        },
      ],
    });
    if (variant.styleId === 'tasmania-openstreetmap-contours-martin') {
      const layerIndexes = new Map(style.layers.map((layer, index) => [layer.id, index]));
      assertLayerOrder({
        layerIndexes,
        lowerIds: [
          'River tunnel',
          'River',
          'River intermittent',
          'Other waterway',
          'Other waterway intermittent',
          'Standing water mask intermittent',
          'Standing water mask',
        ],
        higherIds: [
          'Service road outline',
          'Track road',
          'Minor road',
          'Primary road',
          'Highway road',
          'Highway bridge',
        ],
      });
    }
    assert.equal(
      config.styles[variant.styleId]?.style,
      variant.stylePath.replace('styles/', ''),
    );
  }
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
    assert.equal(layers.get('River tunnel')?.paint?.['line-color'], 'hsl(200, 78%, 78%)');
    assert.equal(layers.get('River')?.paint?.['line-color'], 'hsl(200, 78%, 78%)');
    assert.equal(layers.get('River intermittent')?.paint?.['line-color'], 'hsl(200, 78%, 78%)');
    assert.equal(layers.get('Other waterway')?.paint?.['line-color'], 'hsl(200, 78%, 78%)');
    assert.equal(
      layers.get('Other waterway intermittent')?.paint?.['line-color'],
      'hsl(200, 78%, 78%)',
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
      variant.styleId === 'tasmania-openstreetmap-contours-martin' ? 'scrub_coarse' : 'scrub',
    );
    assert.deepEqual(landcoverPatterns?.paint?.['fill-pattern']?.[1], landcoverClassFallback);

    if (variant.styleId === 'tasmania-openstreetmap-contours-martin') {
      assert.deepEqual(layers.get('Track road outline')?.filter, [
        'all',
        ['!in', 'brunnel', 'bridge', 'tunnel'],
        [
          'any',
          ['in', 'class', 'track'],
          [
            'all',
            ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
            ['in', 'surface', 'gravel', 'fine_gravel', 'unpaved', 'dirt', 'earth'],
          ],
        ],
      ]);
      assert.deepEqual(layers.get('Track road')?.filter, [
        'all',
        ['!in', 'brunnel', 'bridge', 'tunnel'],
        [
          'any',
          ['in', 'class', 'track'],
          [
            'all',
            ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
            ['in', 'surface', 'gravel', 'fine_gravel', 'unpaved', 'dirt', 'earth'],
          ],
        ],
      ]);
      assert.deepEqual(layers.get('Minor road outline')?.filter, [
        'all',
        ['==', '$type', 'LineString'],
        ['!in', 'brunnel', 'bridge', 'tunnel'],
        ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
        ['!=', 'ramp', '1'],
      ]);
      assert.deepEqual(layers.get('Minor road')?.filter, [
        'all',
        ['==', '$type', 'LineString'],
        ['!in', 'brunnel', 'bridge', 'tunnel'],
        ['in', 'class', 'minor', 'unclassified', 'street', 'street_limited'],
      ]);
      assert.equal(layers.get('Minor road outline')?.paint?.['line-color'], 'hsl(32, 22%, 52%)');
      assert.deepEqual(layers.get('Minor road')?.paint?.['line-color'], {
        stops: [
          [12, 'hsl(0, 100%, 100%)'],
          [13, 'hsl(0, 100%, 100%)'],
        ],
      });
      assert.equal(layers.get('Footway path outline')?.minzoom, 12);
      assert.deepEqual(layers.get('Footway path outline')?.paint?.['line-color'], 'rgba(255, 255, 255, 1)');
      assert.deepEqual(layers.get('Footway path outline')?.paint?.['line-width'], [
        'interpolate',
        ['exponential', 1.1],
        ['zoom'],
        12,
        4.4,
        13,
        4.9,
        14,
        5.4,
        15,
        5.6,
        16,
        6.1,
        17,
        6.6,
        18,
        7.2,
      ]);
      assert.deepEqual(layers.get('Footway path')?.paint?.['line-width'], [
        'interpolate',
        ['exponential', 1.1],
        ['zoom'],
        12,
        0.4,
        13,
        0.6,
        14,
        1,
        15,
        1.3,
        16,
        1.3,
        17,
        1.3,
        18,
        1.6,
      ]);
    }
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
    const martinLayerOverride = martinLayerOverrides.get(layerId) ?? {};

    if (martinDeferredSourceLayers.has(legacyLayer['source-layer'])) {
      assert.equal(martinLayers.has(layerId), false);
      continue;
    }

    if (martinLandcoverExceptionSourceLayers.includes(legacyLayer['source-layer'])) {
      if (layerId === 'Landcover patterns') {
        const expectedMartinLayer = withMartinLineWidthOverride(layerId, {
          ...legacyLayer,
          source: 'openmaptiles-landcover',
          ...martinLayerOverride,
        }, martinLayers.get(layerId));
        expectedMartinLayer.paint = {
          ...expectedMartinLayer.paint,
          'fill-pattern': [...expectedMartinLayer.paint['fill-pattern']],
        };

        for (
          let index = 2;
          index < expectedMartinLayer.paint['fill-pattern'].length - 1;
          index += 2
        ) {
          if (expectedMartinLayer.paint['fill-pattern'][index] === 'scrub') {
            expectedMartinLayer.paint['fill-pattern'][index + 1] = 'scrub_coarse';
            break;
          }
        }

        assert.deepEqual(martinLayers.get(layerId), expectedMartinLayer);
        continue;
      }

      assert.deepEqual(martinLayers.get(layerId), withMartinLineWidthOverride(layerId, {
        ...legacyLayer,
        source: 'openmaptiles-landcover',
        ...martinLayerOverride,
      }, martinLayers.get(layerId)));
      continue;
    }

    if (martinWaterExceptionSourceLayers.includes(legacyLayer['source-layer'])) {
      assert.deepEqual(martinLayers.get(layerId), withMartinLineWidthOverride(layerId, {
        ...legacyLayer,
        source: 'openmaptiles-water',
        ...martinLayerOverride,
      }, martinLayers.get(layerId)));
      continue;
    }

    assert.deepEqual(martinLayers.get(layerId), withMartinLineWidthOverride(layerId, {
      ...legacyLayer,
      ...martinLayerOverride,
    }, martinLayers.get(layerId)));
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
