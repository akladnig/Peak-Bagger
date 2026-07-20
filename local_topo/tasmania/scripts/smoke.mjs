import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const baseUrl = process.argv[2] ?? process.env.LOCAL_TOPO_BASE_URL ?? 'http://127.0.0.1:8090';
const expectedCapabilities = JSON.parse(
  await readFile(new URL('../fixtures/capabilities.json', import.meta.url), 'utf8'),
);

const capabilitiesResponse = await fetch(new URL('/capabilities', baseUrl));
assert.equal(capabilitiesResponse.status, 200, 'GET /capabilities must return 200');
assert.match(
  capabilitiesResponse.headers.get('content-type') ?? '',
  /^application\/json/,
  'GET /capabilities must return JSON',
);
assert.equal(
  capabilitiesResponse.headers.has('www-authenticate'),
  false,
  'GET /capabilities must not require app-managed auth',
);

const capabilities = await capabilitiesResponse.json();
assert.deepEqual(
  capabilities,
  expectedCapabilities,
  'Capabilities contract must match the committed v1 fixture exactly',
);

const tileResponse = await fetch(new URL('/tasmania/local-topo/0/0/0.png', baseUrl));
assert.equal(
  tileResponse.status,
  200,
  'Tasmania tile route must return 200 without auth headers',
);
assert.match(
  tileResponse.headers.get('content-type') ?? '',
  /^image\/png/,
  'Tasmania tile route must return PNG tiles',
);
assert.equal(
  tileResponse.headers.has('www-authenticate'),
  false,
  'Tasmania tile route must not require app-managed auth',
);

await tileResponse.arrayBuffer();

process.stdout.write(`Smoke verification passed for ${baseUrl}\n`);
