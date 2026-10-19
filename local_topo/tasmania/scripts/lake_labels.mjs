// Prepared once from whole OSM polygons, never from a tile or viewport.
const worldMetres = 2 * Math.PI * 6378137;
export const metresPerPixel = (zoom) => worldMetres / (256 * 2 ** zoom);

export function classifyLake(area) {
  if (!Number.isFinite(area) || area < 0)
    throw new Error('Invalid whole-lake ground area');
  return area >= 1000000 ? 'large' : 'small';
}

function crossings(ring, y) {
  const intersections = [];
  for (let i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    const [xi, yi] = ring[i],
      [xj, yj] = ring[j];
    if (yi > y !== yj > y)
      intersections.push(((xj - xi) * (y - yi)) / (yj - yi) + xi);
  }
  return intersections.sort((a, b) => a - b);
}

function insideCrossings(intersections, x) {
  let low = 0,
    high = intersections.length;
  while (low < high) {
    const mid = (low + high) >>> 1;
    if (intersections[mid] <= x) low = mid + 1;
    else high = mid;
  }
  return (intersections.length - low) % 2 === 1;
}

// A lattice row shares a latitude. Scan full polygon edges once per row rather
// than once per candidate point (important for detailed statewide shorelines).
function scanlineContains(geometry, y) {
  const polygons =
    geometry.type === 'Polygon' ? [geometry.coordinates] : geometry.coordinates;
  const rows = polygons.map((rings) => rings.map((ring) => crossings(ring, y)));
  return (x) =>
    rows.some(
      ([outer, ...holes]) =>
        insideCrossings(outer, x) && !holes.some((r) => insideCrossings(r, x)),
    );
}

export function containsPoint(geometry, [x, y]) {
  return scanlineContains(geometry, y)(x);
}
function bounds(geometry) {
  const points = geometry.coordinates.flat(geometry.type === 'Polygon' ? 1 : 2);
  return points.reduce(
    ([a, b, c, d], [x, y]) => [
      Math.min(a, x),
      Math.min(b, y),
      Math.max(c, x),
      Math.max(d, y),
    ],
    [Infinity, Infinity, -Infinity, -Infinity],
  );
}

// Conservative bounds for the production 16px Roboto / 10em wrapping style.
// Reserve more than the actual glyph width/line count, including long words.
// Global preparation prevents different tile render contexts admitting two
// overlapping lake labels; native renderer collision detection remains enabled.
function textBounds(name) {
  const words = name.split(/\s+/u);
  return [
    Math.max(160, ...words.map((w) => [...w].length * 32)) + 12,
    Math.max(1, words.length) * 24 + 12,
  ];
}

function collisionIndex() {
  const cells = new Map();
  const keys = (b) => {
    const result = [];
    for (
      let x = Math.floor((b.x - b.width / 2) / 256);
      x <= Math.floor((b.x + b.width / 2) / 256);
      x++
    ) {
      for (
        let y = Math.floor((b.y - b.height / 2) / 256);
        y <= Math.floor((b.y + b.height / 2) / 256);
        y++
      )
        result.push(`${x}/${y}`);
    }
    return result;
  };
  return (box) => {
    const buckets = keys(box);
    for (const key of buckets) {
      if (
        (cells.get(key) ?? []).some(
          (b) =>
            Math.abs(b.x - box.x) * 2 < b.width + box.width &&
            Math.abs(b.y - box.y) * 2 < b.height + box.height,
        )
      )
        return false;
    }
    for (const key of buckets) {
      if (!cells.has(key)) cells.set(key, []);
      cells.get(key).push(box);
    }
    return true;
  };
}

export function prepareLabels(lakes) {
  const labels = [];
  const sorted = [...lakes].sort(
    (a, b) => b.area_m2 - a.area_m2 || a.id.localeCompare(b.id),
  );
  const seen = new Set();
  for (const lake of sorted) {
    if (seen.has(lake.id))
      throw new Error(`Duplicate whole-lake identity: ${lake.id}`);
    seen.add(lake.id);
    classifyLake(lake.area_m2);
    if (!lake.name?.trim() || !containsPoint(lake.geometry, lake.anchor)) {
      throw new Error(`Missing name or invalid interior anchor: ${lake.id}`);
    }
  }
  for (let zoom = 13; zoom <= 18; zoom++) {
    const accept = collisionIndex();
    const unit = metresPerPixel(zoom);
    for (const lake of sorted) {
      const [width, height] = textBounds(lake.name);
      const step = Math.max(514, width, height) * unit; // >512 absorbs MVT quantisation.
      const points = [lake.anchor];
      if (classifyLake(lake.area_m2) === 'large') {
        const [minX, minY, maxX, maxY] = bounds(lake.geometry);
        const [ax, ay] = lake.anchor;
        for (
          let row = Math.ceil((minY - ay) / step);
          row <= Math.floor((maxY - ay) / step);
          row++
        ) {
          const y = ay + row * step;
          const containsX = scanlineContains(lake.geometry, y);
          for (
            let col = Math.ceil((minX - ax) / step);
            col <= Math.floor((maxX - ax) / step);
            col++
          ) {
            if (row === 0 && col === 0) continue;
            const point = [ax + col * step, y];
            if (containsX(point[0])) points.push(point);
          }
        }
      }
      for (const [index, point] of points.entries()) {
        const box = { x: point[0] / unit, y: point[1] / unit, width, height };
        if (!accept(box)) continue;
        labels.push({
          id: `${lake.id}/${zoom}/${index}`,
          lake_id: lake.id,
          name: lake.name,
          area_m2: lake.area_m2,
          zoom,
          point,
        });
      }
    }
  }
  return labels;
}
