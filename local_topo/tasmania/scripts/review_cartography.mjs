import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const stackDir = dirname(scriptDir);
const fixturePath = join(stackDir, 'fixtures', 'cartography-review.json');
const defaultOutputRoot = join(stackDir, 'runtime', 'review', 'cartography');

function resolveBaseUrl() {
  const configured = process.env.LOCAL_TOPO_REVIEW_BASE_URL?.trim();
  return new URL(configured && configured.length > 0 ? configured : 'http://127.0.0.1:8090');
}

async function main() {
  const fixture = JSON.parse(await readFile(fixturePath, 'utf8'));
  const baseUrl = resolveBaseUrl();
  const outputRoot = process.env.LOCAL_TOPO_REVIEW_OUTPUT_ROOT?.trim() || defaultOutputRoot;

  await mkdir(outputRoot, { recursive: true });

  for (const tile of fixture.tiles) {
    const tilePath = `/tasmania/local-topo/${tile.z}/${tile.x}/${tile.y}.png`;
    const tileUrl = new URL(tilePath, baseUrl);
    const response = await fetch(tileUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch ${tilePath}: HTTP ${response.status}`);
    }

    const body = Buffer.from(await response.arrayBuffer());
    const outputPath = join(outputRoot, `${tile.slug}.png`);
    await writeFile(outputPath, body);

    process.stdout.write(`${tile.slug}: ${tileUrl}\n`);
    process.stdout.write(`  saved: ${outputPath}\n`);
    for (const expectation of tile.expectations) {
      process.stdout.write(`  - ${expectation}\n`);
    }
  }
}

await main();
