import { mkdir, readFile, writeFile } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDir = dirname(fileURLToPath(import.meta.url));
const stackDir = dirname(scriptDir);
const fixturePath = join(stackDir, 'fixtures', 'cartography-review.json');
const defaultOutputRoot = join(stackDir, 'runtime', 'review', 'cartography');

export function parseArgs(args = process.argv.slice(2)) {
  let styleId = process.env.LOCAL_TOPO_REVIEW_STYLE_ID?.trim() || '';

  for (let index = 0; index < args.length; index += 1) {
    const argument = args[index];
    if (argument.startsWith('--style-id=')) {
      styleId = argument.slice('--style-id='.length).trim();
      continue;
    }

    if (argument === '--style-id') {
      styleId = (args[index + 1] ?? '').trim();
      index += 1;
      continue;
    }

    throw new Error(`Unknown argument: ${argument}`);
  }

  return { styleId };
}

function resolveBaseUrl() {
  const configured = process.env.LOCAL_TOPO_REVIEW_BASE_URL?.trim();
  return new URL(configured && configured.length > 0 ? configured : 'http://127.0.0.1:8090');
}

export async function loadFixture() {
  return JSON.parse(await readFile(fixturePath, 'utf8'));
}

export function resolveStyleReview(fixture, styleId) {
  const styleReview = fixture.styleReviews?.[styleId];
  if (styleReview != null) {
    return styleReview;
  }

  const availableStyleIds = Object.keys(fixture.styleReviews ?? {}).sort();
  throw new Error(
    `Unknown or missing review style id: ${styleId || '<empty>'}. ` +
      `Pass --style-id=<styleId> or set LOCAL_TOPO_REVIEW_STYLE_ID. ` +
      `Available style ids: ${availableStyleIds.join(', ')}`,
  );
}

export async function runReview({
  styleId,
  fixture,
  baseUrl = resolveBaseUrl(),
  outputRoot = process.env.LOCAL_TOPO_REVIEW_OUTPUT_ROOT?.trim() || defaultOutputRoot,
  fetchImpl = fetch,
  log = (message) => process.stdout.write(message),
}) {
  const styleReview = resolveStyleReview(fixture, styleId);
  const styleOutputRoot = join(outputRoot, styleId);

  await mkdir(styleOutputRoot, { recursive: true });

  log(`${styleId}: ${baseUrl}\n`);
  for (const expectation of styleReview.variantExpectations) {
    log(`  * ${expectation}\n`);
  }

  for (const tile of styleReview.tiles) {
    const tilePath = `/tasmania/local-topo/${tile.z}/${tile.x}/${tile.y}.png`;
    const tileUrl = new URL(tilePath, baseUrl);
    const response = await fetchImpl(tileUrl);
    if (!response.ok) {
      throw new Error(`Failed to fetch ${tilePath}: HTTP ${response.status}`);
    }

    const body = Buffer.from(await response.arrayBuffer());
    const outputPath = join(styleOutputRoot, `${tile.slug}.png`);
    await writeFile(outputPath, body);

    log(`${tile.slug}: ${tileUrl}\n`);
    log(`  saved: ${outputPath}\n`);
    for (const expectation of tile.expectations) {
      log(`  - ${expectation}\n`);
    }
  }
}

async function main() {
  const { styleId } = parseArgs();
  const fixture = await loadFixture();
  await runReview({ styleId, fixture });
}

if (process.argv[1] != null && fileURLToPath(import.meta.url) === process.argv[1]) {
  await main();
}
