import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import test from 'node:test';

import { createApp, startServer } from '../server/app.mjs';

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

test('GET /capabilities returns the committed v1 contract without auth', async () => {
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
      version: 1,
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
    });
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
    response.end(Buffer.from('89504E470D0A1A0A', 'hex'));
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
    response.end(Buffer.from('89504E470D0A1A0A', 'hex'));
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
