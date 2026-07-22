import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const pngFixture = Buffer.from('89504E470D0A1A0A', 'hex');

test('prerender resume mode skips existing tiles and renders missing ones', async () => {
  const outputRoot = await mkdtemp(join(tmpdir(), 'peak-bagger-prerender-resume-'));
  const existingTilePath = join(outputRoot, '1', '0', '0.png');
  await mkdir(join(outputRoot, '1', '0'), { recursive: true });
  await writeFile(existingTilePath, 'existing');

  let requestCount = 0;
  const server = createServer((request, response) => {
    if ((request.url ?? '').endsWith('.png')) {
      requestCount += 1;
      response.writeHead(200, { 'content-type': 'image/png' });
      response.end(pngFixture);
      return;
    }

    response.writeHead(404).end();
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;
  const scriptPath = new URL('../scripts/prerender_tiles.mjs', import.meta.url).pathname;

  try {
    const run = await execFileAsync(process.execPath, [scriptPath], {
      env: {
        ...process.env,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
        LOCAL_TOPO_PRERENDER_OUTPUT_ROOT: outputRoot,
        LOCAL_TOPO_PRERENDER_MIN_ZOOM: '1',
        LOCAL_TOPO_PRERENDER_MAX_ZOOM: '1',
        LOCAL_TOPO_PRERENDER_BOUNDS: '-180,-85,180,85',
        LOCAL_TOPO_PRERENDER_CONCURRENCY: '2',
        LOCAL_TOPO_PRERENDER_SKIP_EXISTING: '1',
      },
    });

    assert.match(run.stdout, /Prerendered 3 tiles .* skipped 1 existing tiles/);
    assert.equal(requestCount, 3);
    assert.equal(await readFile(existingTilePath, 'utf8'), 'existing');
    assert.deepEqual(await readFile(join(outputRoot, '1', '0', '1.png')), pngFixture);
    assert.deepEqual(await readFile(join(outputRoot, '1', '1', '0.png')), pngFixture);
    assert.deepEqual(await readFile(join(outputRoot, '1', '1', '1.png')), pngFixture);
  } finally {
    await new Promise((resolve, reject) => server.close((error) => (error ? reject(error) : resolve())));
    await rm(outputRoot, { force: true, recursive: true });
  }
});
