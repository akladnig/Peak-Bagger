import assert from 'node:assert/strict';
import test from 'node:test';
import {
  classifyLake,
  prepareLabels,
  containsPoint,
  metresPerPixel,
} from '../scripts/lake_labels.mjs';
import {
  preparePreviewLakeLabels,
  exportSql,
} from '../scripts/prepare_preview_lake_labels.mjs';

const ring = (x, y, w, h) => [
  [x, y],
  [x + w, y],
  [x + w, y + h],
  [x, y + h],
  [x, y],
];
const lake = (
  id,
  area,
  rings = [ring(0, 0, 10000, 10000)],
  anchor = [100, 100],
) => ({
  id,
  name: 'Same lake name',
  area_m2: area,
  geometry: { type: 'MultiPolygon', coordinates: [rings] },
  anchor,
});

test('physical area has an inclusive 1 km² threshold independent of zoom', () => {
  assert.equal(classifyLake(999999.999), 'small');
  assert.equal(classifyLake(1000000), 'large');
  assert.equal(classifyLake(1000000.001), 'large');
  for (const area of [-1, NaN, Infinity])
    assert.throws(() => classifyLake(area));
});

test('a small whole lake has one stable interior anchor at every native zoom', () => {
  const input = lake('way/1', 999999.999);
  const labels = prepareLabels([input]);
  for (let z = 13; z <= 18; z++) {
    const atZoom = labels.filter((p) => p.zoom === z);
    assert.equal(atZoom.length, 1);
    assert.deepEqual(atZoom[0].point, input.anchor);
    assert.equal(atZoom[0].lake_id, 'way/1');
  }
});

test('large-lake positions respect holes, native display spacing and whole geometry', () => {
  const input = lake('relation/2', 2000000, [
    ring(0, 0, 10000, 10000),
    ring(2000, 2000, 5000, 5000),
  ]);
  const labels = prepareLabels([input]);
  for (let z = 13; z <= 18; z++) {
    const atZoom = labels.filter((p) => p.zoom === z);
    assert.ok(atZoom.length > 1);
    for (let i = 0; i < atZoom.length; i++) {
      assert.ok(containsPoint(input.geometry, atZoom[i].point));
      for (let j = 0; j < i; j++) {
        const a = atZoom[i].point,
          b = atZoom[j].point;
        const displayDistance =
          Math.hypot(a[0] - b[0], a[1] - b[1]) / metresPerPixel(z);
        assert.ok(displayDistance >= 512, `${z}: ${displayDistance}`);
        // @2x changes PNG pixels, not map-display pixels or classification.
        assert.ok(displayDistance * 2 >= 1024);
      }
    }
  }
});

test('large classification does not force a second anchor where spacing cannot fit', () => {
  const labels = prepareLabels([
    lake('way/3', 1000000, [ring(0, 0, 10, 10)], [5, 5]),
  ]);
  for (let z = 13; z <= 18; z++)
    assert.equal(labels.filter((p) => p.zoom === z).length, 1);
});

test('separate same-named lakes keep identities; adjacent tiles partition stable positions', () => {
  const inputs = [
    lake('way/4', 10),
    lake('relation/4', 10, [ring(20000, 0, 100, 100)], [20050, 50]),
  ];
  const labels = prepareLabels(inputs);
  for (let z = 13; z <= 18; z++) {
    const atZoom = labels.filter((p) => p.zoom === z);
    assert.deepEqual(
      new Set(atZoom.map((p) => p.lake_id)),
      new Set(['way/4', 'relation/4']),
    );
    const tileWidth = metresPerPixel(z) * 256;
    const tileIds = atZoom.map((p) => Math.floor(p.point[0] / tileWidth));
    const combined = [...new Set(tileIds)].flatMap((tile) =>
      atZoom.filter((p) => Math.floor(p.point[0] / tileWidth) === tile),
    );
    assert.deepEqual(combined, atZoom);
    assert.equal(new Set(combined.map((p) => p.id)).size, 2);
  }
});

test('holes and disconnected relation components never become independent small lakes', () => {
  const input = lake(
    'relation/9',
    900000,
    [ring(0, 0, 100, 100), ring(20, 20, 60, 60)],
    [10, 10],
  );
  input.geometry.coordinates.push([ring(200, 0, 100, 100)]);
  assert.equal(containsPoint(input.geometry, [50, 50]), false);
  assert.equal(containsPoint(input.geometry, [250, 50]), true);
  assert.equal(prepareLabels([input]).length, 6);
});

test('global lake-name collision preparation is deterministic and retains source text', () => {
  const a = lake('way/10', 100, [ring(0, 0, 100, 100)], [50, 50]);
  a.name = 'A lake with a very very long name';
  const b = { ...a, id: 'way/11', anchor: [51, 51] };
  const labels = prepareLabels([a, b]);
  assert.deepEqual(labels, prepareLabels([b, a]));
  assert.equal(labels.length, 6);
  assert.ok(labels.every((p) => p.name === a.name));
  assert.throws(() => prepareLabels([{ ...a, anchor: [200, 200] }]));
});

test('competing lakes prefer the larger ground area, without name or identity overrides', () => {
  const larger = lake('way/20', 167000, [ring(0,0,100,100)], [50,50]);
  const smaller = { ...larger, id: 'way/21', name: 'Neighbour', area_m2: 20000, anchor: [51,51] };
  const labels = prepareLabels([smaller,larger]);
  assert.equal(labels.length, 6);
  assert.ok(labels.every(p => p.lake_id === larger.id));
});

test('production preparation reads whole source geometry and stages labels before publication', () => {
  const input = lake('relation/14', 1000000);
  input.name = "O'Brien Lake";
  const calls = [];
  const result = preparePreviewLakeLabels(
    (sql) => {
      calls.push(sql);
      return calls.length === 1 ? JSON.stringify(input) : '';
    },
    { fromActive: true },
  );
  assert.equal(result.lakes, 1);
  assert.match(calls[0], /local_topo_preview_active\.water/);
  assert.match(exportSql, /ST_Area\(ST_Transform\(geom, 4326\)::geography\)/);
  assert.match(
    exportSql,
    /ST_UnaryUnion\(ST_Collect\(ST_MakeValid\(geom\)\)\)/,
  );
  assert.match(exportSql, /ST_PointOnSurface/);
  assert.doesNotMatch(exportSql, /ST_AsMVTGeom|ST_TileEnvelope/);
  assert.match(
    calls[1],
    /BEGIN;.*CREATE TABLE local_topo_preview_stage.lake_labels.*COMMIT;/s,
  );
  assert.ok(calls[1].includes("O''Brien Lake"));
  assert.doesNotMatch(calls[1], /ALTER.*local_topo_preview_active/);
  let writes = 0;
  assert.throws(() =>
    preparePreviewLakeLabels(() => {
      writes++;
      return 'broken json';
    }),
  );
  assert.equal(writes, 1);
});
