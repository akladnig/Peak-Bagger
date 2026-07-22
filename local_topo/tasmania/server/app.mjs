import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';
import { resolve, sep } from 'node:path';
import { pathToFileURL } from 'node:url';

const capabilitiesFileUrl = new URL('../fixtures/capabilities.json', import.meta.url);
const tileRoutePattern = /^\/tasmania\/local-topo\/(\d+)\/(\d+)\/(\d+)\.png$/;
const defaultDataSetId = 'tasmania-local-topo-smoke';

async function loadCapabilities() {
  return JSON.parse(await readFile(capabilitiesFileUrl, 'utf8'));
}

function json(response, statusCode, body) {
  response.writeHead(statusCode, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
  });
  response.end(JSON.stringify(body));
}

function buildTileserverTileUrl({
  tileserverInternalUrl,
  dataSetId,
  z,
  x,
  y,
  tileScale = '',
}) {
  return new URL(
    `/data/${dataSetId}/${z}/${x}/${y}${tileScale}.png`,
    tileserverInternalUrl,
  );
}

function buildTileserverStyleTileUrl({
  tileserverInternalUrl,
  styleId,
  z,
  x,
  y,
  tileScale = '',
}) {
  return new URL(
    `/styles/${styleId}/${z}/${x}/${y}${tileScale}.png`,
    tileserverInternalUrl,
  );
}

function resolveStaticTilePath(staticTileRoot, requestPathname) {
  const rootPath = resolve(staticTileRoot);
  const relativePath = requestPathname.startsWith('/')
    ? requestPathname.slice(1)
    : requestPathname;
  const tilePath = resolve(rootPath, relativePath);

  if (tilePath !== rootPath && !tilePath.startsWith(`${rootPath}${sep}`)) {
    return null;
  }

  return tilePath;
}

async function serveStaticTile({ response, staticTileRoot, requestPathname }) {
  const tilePath = resolveStaticTilePath(staticTileRoot, requestPathname);
  if (tilePath == null) {
    json(response, 404, { error: 'not-found' });
    return;
  }

  try {
    const body = await readFile(tilePath);
    response.writeHead(200, {
      'content-type': 'image/png',
      'cache-control': 'public, max-age=300',
    });
    response.end(body);
  } catch (error) {
    if (
      error instanceof Error &&
      'code' in error &&
      (error.code === 'ENOENT' || error.code === 'ENOTDIR')
    ) {
      json(response, 404, { error: 'not-found' });
      return;
    }

    throw error;
  }
}

export async function createApp({
  capabilities,
  tileserverInternalUrl = process.env.TILESERVER_INTERNAL_URL ?? 'http://127.0.0.1:8080',
  staticTileRoot = process.env.LOCAL_TOPO_STATIC_TILE_ROOT ?? '',
  dataSetId = process.env.TILESERVER_DATASET_ID ?? defaultDataSetId,
  styleId = process.env.TILESERVER_STYLE_ID ?? '',
  tileScale = process.env.TILESERVER_TILE_SCALE ?? '',
} = {}) {
  const resolvedCapabilities = capabilities ?? (await loadCapabilities());
  const trimmedStaticTileRoot = staticTileRoot.trim();
  const trimmedStyleId = styleId.trim();
  const trimmedTileScale = tileScale.trim();

  return async function app(request, response) {
    const requestUrl = new URL(request.url ?? '/', 'http://localhost');

    if (request.method !== 'GET') {
      json(response, 405, { error: 'method-not-allowed' });
      return;
    }

    if (requestUrl.pathname === '/healthz') {
      json(response, 200, { ok: true });
      return;
    }

    if (requestUrl.pathname === '/capabilities') {
      json(response, 200, resolvedCapabilities);
      return;
    }

    const tileMatch = tileRoutePattern.exec(requestUrl.pathname);
    if (tileMatch == null) {
      json(response, 404, { error: 'not-found' });
      return;
    }

    const [, z, x, y] = tileMatch;

    try {
      if (trimmedStaticTileRoot.length > 0) {
        await serveStaticTile({
          response,
          staticTileRoot: trimmedStaticTileRoot,
          requestPathname: requestUrl.pathname,
        });
        return;
      }

      const tileResponse = await fetch(
        trimmedStyleId.length === 0
            ? buildTileserverTileUrl({
                tileserverInternalUrl,
                dataSetId,
                z,
                x,
                y,
                tileScale: trimmedTileScale,
              })
            : buildTileserverStyleTileUrl({
                tileserverInternalUrl,
                styleId: trimmedStyleId,
                z,
                x,
                y,
                tileScale: trimmedTileScale,
              }),
      );

      const body = Buffer.from(await tileResponse.arrayBuffer());
      const contentType =
        tileResponse.headers.get('content-type') ?? 'application/octet-stream';

      response.writeHead(tileResponse.status, {
        'content-type': contentType,
        'cache-control':
          tileResponse.headers.get('cache-control') ?? 'public, max-age=300',
      });
      response.end(body);
    } catch (error) {
      json(response, 502, {
        error: 'tileserver-unavailable',
        message: error instanceof Error ? error.message : String(error),
      });
    }
  };
}

export async function startServer({
  port = Number(process.env.PORT ?? '8080'),
  host = process.env.HOST ?? '0.0.0.0',
  ...options
} = {}) {
  const app = await createApp(options);
  const server = createServer((request, response) => {
    void app(request, response);
  });

  await new Promise((resolve) => {
    server.listen(port, host, resolve);
  });

  return server;
}

if (process.argv[1] != null && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const server = await startServer();
  const address = server.address();
  if (typeof address === 'object' && address != null) {
    process.stdout.write(
      `Tasmania local topo gateway listening on ${address.address}:${address.port}\n`,
    );
  }
}
