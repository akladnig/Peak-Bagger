import { access, mkdir, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';

function requireEnv(name) {
  const value = process.env[name]?.trim();
  if (value == null || value.length === 0) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function parseIntegerEnv(name, fallback) {
  const raw = process.env[name]?.trim();
  if (raw == null || raw.length === 0) {
    return fallback;
  }

  const value = Number.parseInt(raw, 10);
  if (!Number.isInteger(value)) {
    throw new Error(`Invalid integer for ${name}: ${raw}`);
  }

  return value;
}

function parseBooleanEnv(name, fallback = false) {
  const raw = process.env[name]?.trim().toLowerCase();
  if (raw == null || raw.length === 0) {
    return fallback;
  }

  if (raw === '1' || raw === 'true' || raw === 'yes') {
    return true;
  }

  if (raw === '0' || raw === 'false' || raw === 'no') {
    return false;
  }

  throw new Error(`Invalid boolean for ${name}: ${raw}`);
}

function parseBounds(value) {
  const parts = value.split(',').map((part) => Number.parseFloat(part.trim()));
  if (parts.length !== 4 || parts.some((part) => Number.isNaN(part))) {
    throw new Error(`Invalid LOCAL_TOPO_PRERENDER_BOUNDS: ${value}`);
  }

  const [west, south, east, north] = parts;
  if (!(west < east) || !(south < north)) {
    throw new Error(`Invalid LOCAL_TOPO_PRERENDER_BOUNDS ordering: ${value}`);
  }

  return { west, south, east, north };
}

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function lonToTileX(lon, zoom) {
  const tilesPerAxis = 2 ** zoom;
  const normalized = ((lon + 180) / 360) * tilesPerAxis;
  return clamp(Math.floor(normalized), 0, tilesPerAxis - 1);
}

function latToTileY(lat, zoom) {
  const tilesPerAxis = 2 ** zoom;
  const radians = (lat * Math.PI) / 180;
  const mercator =
    (1 - Math.log(Math.tan(radians) + 1 / Math.cos(radians)) / Math.PI) / 2;
  return clamp(Math.floor(mercator * tilesPerAxis), 0, tilesPerAxis - 1);
}

function buildTilePlans({ bounds, minZoom, maxZoom }) {
  const plans = [];

  for (let zoom = minZoom; zoom <= maxZoom; zoom += 1) {
    const minX = lonToTileX(bounds.west, zoom);
    const maxX = lonToTileX(bounds.east, zoom);
    const minY = latToTileY(bounds.north, zoom);
    const maxY = latToTileY(bounds.south, zoom);
    plans.push({ zoom, minX, maxX, minY, maxY });
  }

  return plans;
}

function* tileCoordinates(plans) {
  for (const plan of plans) {
    for (let x = plan.minX; x <= plan.maxX; x += 1) {
      for (let y = plan.minY; y <= plan.maxY; y += 1) {
        yield { z: plan.zoom, x, y };
      }
    }
  }
}

async function main() {
  const baseUrl = new URL(requireEnv('LOCAL_TOPO_PRERENDER_BASE_URL'));
  const outputRoot = requireEnv('LOCAL_TOPO_PRERENDER_OUTPUT_ROOT');
  const minZoom = parseIntegerEnv('LOCAL_TOPO_PRERENDER_MIN_ZOOM', 0);
  const maxZoom = parseIntegerEnv('LOCAL_TOPO_PRERENDER_MAX_ZOOM', 16);
  const concurrency = parseIntegerEnv('LOCAL_TOPO_PRERENDER_CONCURRENCY', 8);
  const skipExisting = parseBooleanEnv('LOCAL_TOPO_PRERENDER_SKIP_EXISTING', false);
  const bounds = parseBounds(requireEnv('LOCAL_TOPO_PRERENDER_BOUNDS'));

  if (minZoom < 0 || maxZoom < minZoom) {
    throw new Error(`Invalid zoom range: ${minZoom}-${maxZoom}`);
  }

  if (concurrency < 1) {
    throw new Error(`Invalid LOCAL_TOPO_PRERENDER_CONCURRENCY: ${concurrency}`);
  }

  const plans = buildTilePlans({ bounds, minZoom, maxZoom });
  const iterator = tileCoordinates(plans);
  let renderedCount = 0;
  let skippedCount = 0;

  async function fileExists(path) {
    try {
      await access(path);
      return true;
    } catch {
      return false;
    }
  }

  async function renderTiles() {
    while (true) {
      const next = iterator.next();
      if (next.done) {
        return;
      }

      const { z, x, y } = next.value;
      const outputPath = join(outputRoot, String(z), String(x), `${y}.png`);
      if (skipExisting && (await fileExists(outputPath))) {
        skippedCount += 1;
        continue;
      }

      const tileUrl = new URL(`/styles/tasmania-local-topo/${z}/${x}/${y}.png`, baseUrl);
      const response = await fetch(tileUrl);
      if (!response.ok) {
        throw new Error(`Failed to prerender ${tileUrl.pathname}: HTTP ${response.status}`);
      }

      const body = Buffer.from(await response.arrayBuffer());
      await mkdir(dirname(outputPath), { recursive: true });
      await writeFile(outputPath, body);
      renderedCount += 1;
    }
  }

  await Promise.all(
    Array.from({ length: concurrency }, () => renderTiles()),
  );

  process.stdout.write(
    `Prerendered ${renderedCount} tiles into ${outputRoot} for zooms ${minZoom}-${maxZoom}` +
      (skipExisting ? `, skipped ${skippedCount} existing tiles` : '') +
      '\n',
  );
}

await main();
