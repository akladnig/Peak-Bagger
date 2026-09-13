import assert from 'node:assert/strict';
import { readFile, mkdtemp, mkdir, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { inflateSync } from 'node:zlib';

import { createApp, startServer } from '../server/app.mjs';

const pngFixture = Buffer.from('89504E470D0A1A0A', 'hex');
const overlayFixtureRoot = new URL('../fixtures/overlay-rendering/', import.meta.url);

function readPngPixels(buffer) {
  assert.equal(buffer.subarray(0, 8).toString('hex'), '89504e470d0a1a0a');
  let offset = 8;
  let width;
  let height;
  const imageData = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString('ascii');
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    offset += length + 12;

    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      assert.equal(data[8], 8);
      assert.equal(data[9], 6);
    } else if (type === 'IDAT') {
      imageData.push(data);
    }
  }

  assert.notEqual(width, undefined);
  assert.notEqual(height, undefined);
  const scanlines = inflateSync(Buffer.concat(imageData));
  const pixels = [];
  let scanlineOffset = 0;
  for (let y = 0; y < height; y += 1) {
    assert.equal(scanlines[scanlineOffset], 0);
    scanlineOffset += 1;
    for (let x = 0; x < width; x += 1) {
      pixels.push([...scanlines.subarray(scanlineOffset, scanlineOffset + 4)]);
      scanlineOffset += 4;
    }
  }
  return pixels;
}

async function readOverlayFixture(name) {
  return readFile(new URL(name, overlayFixtureRoot));
}

function listen(server) {
  return new Promise((resolve) => {
    server.listen(0, '127.0.0.1', () => {
      resolve(server.address());
    });
  });
}

async function closeServer(server) {
  await new Promise((resolve, reject) => {
    server.close((error) => {
      if (error != null) {
        reject(error);
        return;
      }
      resolve();
    });
  });
}

async function makeStaticTileRoot() {
  const root = await mkdtemp(join(tmpdir(), 'peak-bagger-local-topo-'));
  await Promise.all(
    [
      'local-topo',
      'terrain-relief-shading',
      'contour-lines',
    ].map(async (route) => {
      const tileDirectory = join(root, 'tasmania', route, '0', '0');
      await mkdir(tileDirectory, { recursive: true });
      await writeFile(join(tileDirectory, '0.png'), pngFixture);
    }),
  );
  return root;
}

test('GET /capabilities returns the committed v2 contract with standalone overlays without auth', async () => {
  const server = await startServer({ port: 0, host: '127.0.0.1' });
  const address = server.address();

  try {
    assert.notEqual(address, null);
    assert.equal(typeof address, 'object');
    const baseUrl = `http://127.0.0.1:${address.port}`;

    const response = await fetch(new URL('/capabilities', baseUrl));
    assert.equal(response.status, 200);
    assert.equal(response.headers.has('www-authenticate'), false);

    const body = await response.json();
    assert.deepEqual(body, {
      service: 'peak-bagger-local-topo',
      version: 2,
      basemaps: [
        {
          key: 'localTopo',
          label: 'Local Topo',
          regions: [
            {
              regionKey: 'tasmania',
              tilePathTemplate: '/tasmania/local-topo/{z}/{x}/{y}.png',
            },
          ],
        },
      ],
      overlays: [
        {
          key: 'terrainReliefShading',
          label: 'Terrain relief shading',
          regions: [
            {
              regionKey: 'tasmania',
              tilePathTemplate: '/tasmania/terrain-relief-shading/{z}/{x}/{y}.png',
            },
          ],
        },
        {
          key: 'contourLines',
          label: 'Contour lines',
          regions: [
            {
              regionKey: 'tasmania',
              tilePathTemplate: '/tasmania/contour-lines/{z}/{x}/{y}.png',
            },
          ],
        },
      ],
    });
  } finally {
    await closeServer(server);
  }
});

test('GET /capabilities preserves the committed v1 fixture', async () => {
  const v1Capabilities = JSON.parse(
    await readFile(new URL('../fixtures/capabilities-v1.json', import.meta.url), 'utf8'),
  );
  const app = await createApp({ capabilities: v1Capabilities });
  const server = createServer((request, response) => void app(request, response));
  const address = await listen(server);

  try {
    const response = await fetch(`http://127.0.0.1:${address.port}/capabilities`);
    assert.deepEqual(await response.json(), v1Capabilities);
  } finally {
    await closeServer(server);
  }
});

test('Tasmania tile route proxies to the deterministic tileserver path without auth', async () => {
  let seenPath = null;
  let seenAuthorization = null;

  const backend = createServer((request, response) => {
    seenPath = request.url;
    seenAuthorization = request.headers.authorization ?? null;
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });

  const backendAddress = await listen(backend);
  const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;

  const app = await createApp({ tileserverInternalUrl: backendBaseUrl });
  const gateway = createServer((request, response) => {
    void app(request, response);
  });
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    const response = await fetch(new URL('/tasmania/local-topo/0/0/0.png', baseUrl));

    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type') ?? '', /^image\/png/);
    assert.equal(response.headers.get('cache-control'), 'public, max-age=300');
    await response.arrayBuffer();

    assert.equal(seenPath, '/data/tasmania-local-topo-smoke/0/0/0.png');
    assert.equal(seenAuthorization, null);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
  }
});

test('Tasmania tile route can proxy rendered style tiles without auth', async () => {
  let seenPath = null;
  let seenAuthorization = null;

  const backend = createServer((request, response) => {
    seenPath = request.url;
    seenAuthorization = request.headers.authorization ?? null;
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });

  const backendAddress = await listen(backend);
  const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;

  const app = await createApp({
    tileserverInternalUrl: backendBaseUrl,
    styleId: 'tasmania-local-topo',
  });
  const gateway = createServer((request, response) => {
    void app(request, response);
  });
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    const response = await fetch(
      new URL('/tasmania/local-topo/15/29781/20716.png', baseUrl),
    );

    assert.equal(response.status, 200);
    assert.match(response.headers.get('content-type') ?? '', /^image\/png/);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    await response.arrayBuffer();

    assert.equal(
      seenPath,
      '/styles/tasmania-local-topo/15/29781/20716.png',
    );
    assert.equal(seenAuthorization, null);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
  }
});

test('overlay tile routes proxy their isolated TileServer styles without auth', async () => {
  const seenPaths = [];
  const backend = createServer((request, response) => {
    seenPaths.push(request.url);
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });
  const backendAddress = await listen(backend);
  const app = await createApp({
    tileserverInternalUrl: `http://127.0.0.1:${backendAddress.port}`,
    styleId: 'tasmania-local-topo',
  });
  const gateway = createServer((request, response) => void app(request, response));
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    for (const route of ['terrain-relief-shading', 'contour-lines']) {
      const response = await fetch(new URL(`/tasmania/${route}/13/3711/2577.png`, baseUrl));
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /^image\/png/);
      assert.equal(response.headers.get('cache-control'), 'no-store');
    }

    assert.deepEqual(seenPaths, [
      '/styles/tasmania-terrain-relief-shading/13/3711/2577.png',
      '/styles/tasmania-contour-lines/13/3711/2577.png',
    ]);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
  }
});

test('overlay rendering fixtures retain transparency and contour zoom tiers', async () => {
  const fixtures = new Map(
    await Promise.all(
      [
        ['terrain-relief-shading/13/3711/2577.png', 'terrain-relief-z13.png'],
        ['contour-lines/11/927/644.png', 'contour-lines-z11.png'],
        ['contour-lines/12/1855/1288.png', 'contour-lines-z12.png'],
        ['contour-lines/13/3711/2577.png', 'contour-lines-z13.png'],
      ].map(async ([route, fixture]) => [route, await readOverlayFixture(fixture)]),
    ),
  );
  const backend = createServer((request, response) => {
    const fixture = fixtures.get((request.url ?? '').replace(/^\/styles\/tasmania-/, '').replace(/^\//, ''));
    assert.notEqual(fixture, undefined);
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(fixture);
  });
  const backendAddress = await listen(backend);
  const app = await createApp({
    tileserverInternalUrl: `http://127.0.0.1:${backendAddress.port}`,
  });
  const gateway = createServer((request, response) => void app(request, response));
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    const fetchPixels = async (route) =>
      readPngPixels(Buffer.from(await (await fetch(new URL(`/tasmania/${route}.png`, baseUrl))).arrayBuffer()));

    const reliefPixels = await fetchPixels('terrain-relief-shading/13/3711/2577');
    assert.deepEqual(reliefPixels[0], [0, 0, 0, 0]);
    assert.deepEqual(reliefPixels[1], [100, 100, 100, 192]);

    const zoom11Pixels = await fetchPixels('contour-lines/11/927/644');
    assert.deepEqual(zoom11Pixels, [[0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]);

    const zoom12Pixels = await fetchPixels('contour-lines/12/1855/1288');
    assert.deepEqual(zoom12Pixels, [[0, 0, 0, 0], [125, 92, 55, 102], [111, 79, 45, 128]]);

    const zoom13Pixels = await fetchPixels('contour-lines/13/3711/2577');
    assert.deepEqual(zoom13Pixels, [[140, 106, 67, 77], [125, 92, 55, 102], [111, 79, 45, 128]]);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
  }
});

test('Tasmania tile route can proxy rendered retina style tiles without auth', async () => {
  let seenPath = null;

  const backend = createServer((request, response) => {
    seenPath = request.url;
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });

  const backendAddress = await listen(backend);
  const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;

  const app = await createApp({
    tileserverInternalUrl: backendBaseUrl,
    styleId: 'tasmania-local-topo',
    tileScale: '@2x',
  });
  const gateway = createServer((request, response) => {
    void app(request, response);
  });
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    const response = await fetch(
      new URL('/tasmania/local-topo/15/29781/20716.png', baseUrl),
    );

    assert.equal(response.status, 200);
    assert.equal(response.headers.get('cache-control'), 'no-store');
    await response.arrayBuffer();

    assert.equal(
      seenPath,
      '/styles/tasmania-local-topo/15/29781/20716@2x.png',
    );
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
  }
});

test('Tasmania tile route keeps the preview route stable for both OSM comparison style ids', async () => {
  const styleIds = [
    'tasmania-openstreetmap-contours',
    'tasmania-openstreetmap-contours-martin',
  ];

  for (const styleId of styleIds) {
    let seenPath = null;

    const backend = createServer((request, response) => {
      seenPath = request.url;
      response.writeHead(200, { 'content-type': 'image/png' });
      response.end(pngFixture);
    });

    const backendAddress = await listen(backend);
    const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;

    const app = await createApp({
      tileserverInternalUrl: backendBaseUrl,
      styleId,
    });
    const gateway = createServer((request, response) => {
      void app(request, response);
    });
    const gatewayAddress = await listen(gateway);

    try {
      const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
      const response = await fetch(new URL('/tasmania/local-topo/15/29781/20716.png', baseUrl));

      assert.equal(response.status, 200);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      await response.arrayBuffer();
      assert.equal(seenPath, `/styles/${styleId}/15/29781/20716.png`);
    } finally {
      await closeServer(gateway);
      await closeServer(backend);
    }
  }
});

test('Tasmania tile route keeps the preview route stable for the MapTiler preview style ids', async () => {
  const styleIds = ['tasmania-maptiler-topo', 'tasmania-maptiler-outdoor'];

  for (const styleId of styleIds) {
    let seenPath = null;

    const backend = createServer((request, response) => {
      seenPath = request.url;
      response.writeHead(200, { 'content-type': 'image/png' });
      response.end(pngFixture);
    });

    const backendAddress = await listen(backend);
    const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;

    const app = await createApp({
      tileserverInternalUrl: backendBaseUrl,
      styleId,
    });
    const gateway = createServer((request, response) => {
      void app(request, response);
    });
    const gatewayAddress = await listen(gateway);

    try {
      const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
      const response = await fetch(new URL('/tasmania/local-topo/15/29781/20716.png', baseUrl));

      assert.equal(response.status, 200);
      assert.equal(response.headers.get('cache-control'), 'no-store');
      await response.arrayBuffer();
      assert.equal(seenPath, `/styles/${styleId}/15/29781/20716.png`);
    } finally {
      await closeServer(gateway);
      await closeServer(backend);
    }
  }
});

test('Tasmania tile route serves static prerendered tiles without backend fallback', async () => {
  let backendRequests = 0;

  const backend = createServer((_request, response) => {
    backendRequests += 1;
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });

  const backendAddress = await listen(backend);
  const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;
  const staticTileRoot = await makeStaticTileRoot();

  const app = await createApp({
    staticTileRoot,
    styleId: 'tasmania-local-topo',
    tileserverInternalUrl: backendBaseUrl,
  });
  const gateway = createServer((request, response) => {
    void app(request, response);
  });
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    for (const route of ['local-topo', 'terrain-relief-shading', 'contour-lines']) {
      const response = await fetch(new URL(`/tasmania/${route}/0/0/0.png`, baseUrl));
      assert.equal(response.status, 200);
      assert.match(response.headers.get('content-type') ?? '', /^image\/png/);
      await response.arrayBuffer();
    }

    assert.equal(backendRequests, 0);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
    await rm(staticTileRoot, { force: true, recursive: true });
  }
});

test('Tasmania static delivery returns 404 for missing prerendered tiles without on-demand fallback', async () => {
  let backendRequests = 0;

  const backend = createServer((_request, response) => {
    backendRequests += 1;
    response.writeHead(200, { 'content-type': 'image/png' });
    response.end(pngFixture);
  });

  const backendAddress = await listen(backend);
  const backendBaseUrl = `http://127.0.0.1:${backendAddress.port}`;
  const staticTileRoot = await mkdtemp(join(tmpdir(), 'peak-bagger-local-topo-empty-'));

  const app = await createApp({
    staticTileRoot,
    styleId: 'tasmania-local-topo',
    tileserverInternalUrl: backendBaseUrl,
  });
  const gateway = createServer((request, response) => {
    void app(request, response);
  });
  const gatewayAddress = await listen(gateway);

  try {
    const baseUrl = `http://127.0.0.1:${gatewayAddress.port}`;
    const response = await fetch(new URL('/tasmania/local-topo/0/0/0.png', baseUrl));

    assert.equal(response.status, 404);
    assert.deepEqual(await response.json(), { error: 'not-found' });
    assert.equal(backendRequests, 0);
  } finally {
    await closeServer(gateway);
    await closeServer(backend);
    await rm(staticTileRoot, { force: true, recursive: true });
  }
});
