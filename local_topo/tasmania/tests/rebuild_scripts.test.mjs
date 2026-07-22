import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, rm, utimes, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);
const pngFixture = Buffer.from('89504E470D0A1A0A', 'hex');

async function runScript(scriptName, args = [], options = {}) {
  return execFileAsync(`./scripts/${scriptName}`, args, {
    cwd: new URL('..', import.meta.url),
    ...options,
  });
}

async function makeExecutableScript(path, contents) {
  await writeFile(path, contents);
  await chmod(path, 0o755);
}

async function makeTestWorkspace() {
  const root = await mkdtemp(join(tmpdir(), 'peak-bagger-local-topo-rebuild-'));
  const stackRoot = new URL('..', import.meta.url).pathname;
  const scratchRoot = join(stackRoot, '.tmp-rebuild-tests', root.split('/').at(-1));
  const inputDir = join(scratchRoot, 'input');
  const outputDir = join(scratchRoot, 'output');
  const runtimeDir = join(scratchRoot, 'runtime');
  const binDir = join(root, 'bin');
  await mkdir(join(inputDir, 'osm'), { recursive: true });
  await mkdir(join(outputDir), { recursive: true });
  await mkdir(join(runtimeDir), { recursive: true });
  await mkdir(binDir, { recursive: true });

  const gdalinfoPath = join(binDir, 'gdalinfo');
  const gdaldemPath = join(binDir, 'gdaldem');
  const gdalContourPath = join(binDir, 'gdal_contour');
  const gdalTranslatePath = join(binDir, 'gdal_translate');
  const gdaladdoPath = join(binDir, 'gdaladdo');
  const ogr2ogrPath = join(binDir, 'ogr2ogr');
  const tippecanoePath = join(binDir, 'tippecanoe');
  const curlPath = join(binDir, 'curl');
  const dockerPath = join(binDir, 'docker');

  await makeExecutableScript(
    gdalinfoPath,
    `#!/usr/bin/env bash
set -euo pipefail
target="$1"
if [[ "$target" == *"unreadable"* ]]; then
  exit 1
fi
[ -f "$target" ]
`,
  );

  await makeExecutableScript(
    gdaldemPath,
    `#!/usr/bin/env bash
set -euo pipefail
input="$2"
output="$3"
[ -f "$input" ]
mkdir -p "$(dirname "$output")"
printf 'hillshade' > "$output"
`,
  );

  await makeExecutableScript(
    gdalContourPath,
    `#!/usr/bin/env bash
set -euo pipefail
interval=""
attribute=""
args=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    -a)
      shift
      attribute="$1"
      ;;
    -i)
      shift
      interval="$1"
      ;;
    *)
      args+=("$1")
      ;;
  esac
  shift
done
input="\${args[0]}"
output="\${args[1]}"
if [ "\${FAKE_CONTOUR_FAIL_INTERVAL:-}" = "$interval" ] && [[ "$input" == *"\${FAKE_CONTOUR_FAIL_MATCH:-}"* ]]; then
  exit 1
fi
mkdir -p "$(dirname "$output")"
if [ -n "$attribute" ]; then
  printf '{"type":"FeatureCollection","features":[{"type":"Feature","properties":{"%s":100},"geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}]}' "$attribute" > "$output"
else
  printf '{"type":"FeatureCollection","features":[]}' > "$output"
fi
`,
  );

  await makeExecutableScript(
    gdalTranslatePath,
    `#!/usr/bin/env bash
set -euo pipefail
input="$1"
output="$2"
[ -f "$input" ]
mkdir -p "$(dirname "$output")"
printf 'mbtiles' > "$output"
`,
  );

  await makeExecutableScript(
    gdaladdoPath,
    `#!/usr/bin/env bash
set -euo pipefail
dataset="$3"
[ -f "$dataset" ]
`,
  );

  await makeExecutableScript(
    ogr2ogrPath,
    `#!/usr/bin/env bash
set -euo pipefail
output="\${@: -2:1}"
input="\${@: -1}"
mkdir -p "$(dirname "$output")"
cp "$input" "$output"
`,
  );

  await makeExecutableScript(
    tippecanoePath,
    `#!/usr/bin/env bash
set -euo pipefail
output=""
while [ "$#" -gt 0 ]; do
  if [ "$1" = "-o" ]; then
    shift
    output="$1"
  fi
  shift
done
mkdir -p "$(dirname "$output")"
printf 'mbtiles' > "$output"
`,
  );

  await makeExecutableScript(
    curlPath,
    `#!/usr/bin/env bash
set -euo pipefail
if [ "\${FAKE_CURL_FAIL:-0}" = "1" ]; then
  exit 1
fi
output=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o)
      shift
      output="$1"
      ;;
  esac
  shift
done
mkdir -p "$(dirname "$output")"
printf '1234567890abcdef' > "$output"
`,
  );

  await makeExecutableScript(
    dockerPath,
    `#!/usr/bin/env bash
set -euo pipefail
stack_dir="${stackRoot}"
command="$1"
shift
if [ "$command" = "run" ]; then
  for arg in "$@"; do
    case "$arg" in
      --output=/workspace/*)
        host_output="$stack_dir\${arg#--output=/workspace}"
        mkdir -p "$(dirname "$host_output")"
        printf 'mbtiles' > "$host_output"
        ;;
    esac
  done
  exit 0
fi
if [ "$command" = "rm" ]; then
  exit 0
fi
exit 0
`,
  );

  return {
    root,
    scratchRoot,
    inputDir,
    outputDir,
    runtimeDir,
    env: {
      LOCAL_TOPO_INPUT_DIR: inputDir,
      LOCAL_TOPO_OUTPUT_DIR: outputDir,
      LOCAL_TOPO_RUNTIME_DIR: runtimeDir,
      LOCAL_TOPO_GDALINFO_BIN: gdalinfoPath,
      LOCAL_TOPO_GDALDEM_BIN: gdaldemPath,
      LOCAL_TOPO_GDAL_CONTOUR_BIN: gdalContourPath,
      LOCAL_TOPO_GDAL_TRANSLATE_BIN: gdalTranslatePath,
      LOCAL_TOPO_GDALADDO_BIN: gdaladdoPath,
      LOCAL_TOPO_OGR2OGR_BIN: ogr2ogrPath,
      LOCAL_TOPO_TIPPECANOE_BIN: tippecanoePath,
      LOCAL_TOPO_CURL_BIN: curlPath,
      LOCAL_TOPO_DOCKER_BIN: dockerPath,
      LOCAL_TOPO_NODE_BIN: process.execPath,
      LOCAL_TOPO_MIN_OSM_EXTRACT_BYTES: '8',
      LOCAL_TOPO_PRERENDER_MIN_ZOOM: '0',
      LOCAL_TOPO_PRERENDER_MAX_ZOOM: '0',
      LOCAL_TOPO_PRERENDER_CONCURRENCY: '1',
      LOCAL_TOPO_CURRENT_TIME_EPOCH: '1735689600',
    },
  };
}

async function withRenderServer(fn) {
  const server = createServer((request, response) => {
    if ((request.url ?? '').endsWith('.png')) {
      response.writeHead(200, { 'content-type': 'image/png' });
      response.end(pngFixture);
      return;
    }

    response.writeHead(404).end();
  });

  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const address = server.address();
  const baseUrl = `http://127.0.0.1:${address.port}`;

  try {
    await fn(baseUrl);
  } finally {
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
}

test('manual refresh dry-run uses a local OSM override and plans prerendered PNG output', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'tasmania-local.osm.pbf');
  const demPath = join(workspace.root, 'thelist.tif');
  await writeFile(overrideOsmPath, '1234567890abcdef');
  await writeFile(demPath, 'dem');

  const { stdout } = await runScript('manual_refresh.sh', ['--dry-run'], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
      LOCAL_TOPO_THELIST_DEM_TIF: demPath,
    },
  });

  assert.match(stdout, /Using local OSM override:/);
  assert.doesNotMatch(stdout, /download\.geofabrik\.de/);
  assert.match(stdout, /ghcr\.io\/onthegomap\/planetiler:latest/);
  assert.match(stdout, /gdaldem/);
  assert.match(stdout, /gdal_translate/);
  assert.match(stdout, /gdaladdo/);
  assert.match(stdout, /gdal_contour/);
  assert.match(stdout, /ogr2ogr/);
  assert.match(stdout, /tippecanoe/);
  assert.match(stdout, /prerender_tiles\.mjs/);
  assert.match(stdout, /tasmania\/local-topo/);

  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
});

test('scheduled refresh dry-run only fetches Geofabrik data when the managed extract is older than 30 days', async () => {
  const workspace = await makeTestWorkspace();
  const managedOsmPath = join(workspace.inputDir, 'osm', 'tasmania-latest.osm.pbf');
  const demPath = join(workspace.root, 'thelist.tif');
  await writeFile(managedOsmPath, '1234567890abcdef');
  await writeFile(demPath, 'dem');

  const freshEpoch = 1735603200;
  await utimes(managedOsmPath, freshEpoch, freshEpoch);
  const freshRun = await runScript('scheduled_refresh.sh', ['--dry-run'], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_THELIST_DEM_TIF: demPath,
    },
  });

  assert.doesNotMatch(freshRun.stdout, /download\.geofabrik\.de/);
  assert.match(freshRun.stdout, /Reusing local Tasmania OSM extract:/);

  const staleEpoch = 1732406400;
  await utimes(managedOsmPath, staleEpoch, staleEpoch);
  const staleRun = await runScript('scheduled_refresh.sh', ['--dry-run'], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_THELIST_DEM_TIF: demPath,
    },
  });

  assert.match(staleRun.stdout, /download\.geofabrik\.de\/australia-oceania\/australia\/tasmania-latest\.osm\.pbf/);

  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
});

test('rebuild prefers higher-detail DEMs, falls back to theLIST 25m contours, and writes source metadata', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const highDetailDemPath = join(workspace.root, 'higher-detail.tif');
  const thelistDemPath = join(workspace.root, 'thelist.tif');
  await writeFile(overrideOsmPath, '1234567890abcdef');
  await writeFile(highDetailDemPath, 'dem');
  await writeFile(thelistDemPath, 'dem');

  await withRenderServer(async (baseUrl) => {
    const run = await runScript('rebuild_stack.sh', ['--mode', 'manual'], {
      env: {
        ...process.env,
        ...workspace.env,
        FAKE_CONTOUR_FAIL_INTERVAL: '10',
        FAKE_CONTOUR_FAIL_MATCH: 'higher-detail',
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
        LOCAL_TOPO_HIGH_DETAIL_DEM_TIF: highDetailDemPath,
        LOCAL_TOPO_THELIST_DEM_TIF: thelistDemPath,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
      },
    });

    assert.match(run.stdout, /gdal_contour -a elev -i 25 /);
    assert.match(run.stdout, /tippecanoe .* -l contours -y elev /);
  });

  const metadataPath = join(
    workspace.outputDir,
    'tiles',
    'tasmania',
    'local-topo',
    'source-metadata.json',
  );
  const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));
  const reliefPath = join(workspace.outputDir, 'tasmania-relief.mbtiles');
  const contoursGeojsonPath = join(workspace.outputDir, 'tasmania-contours.geojson');
  const contoursGeojson = JSON.parse(await readFile(contoursGeojsonPath, 'utf8'));

  assert.equal(metadata.demSource.label, 'Higher Detail Local DEM');
  assert.equal(metadata.contours.intervalMeters, 25);
  assert.equal(metadata.contours.sourceLabel, 'theLIST 25m DEM');
  assert.equal(contoursGeojson.features[0]?.properties?.elev, 100);
  assert.equal(await readFile(reliefPath, 'utf8'), 'mbtiles');

  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
});

test('rebuild keeps theLIST ahead of reserve-only Copernicus when higher-detail DEMs are unavailable', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const unreadableHighDetailDemPath = join(workspace.root, 'higher-detail-unreadable.tif');
  const thelistDemPath = join(workspace.root, 'thelist.tif');
  const copernicusDemPath = join(workspace.root, 'copernicus.tif');
  await writeFile(overrideOsmPath, '1234567890abcdef');
  await writeFile(unreadableHighDetailDemPath, 'dem');
  await writeFile(thelistDemPath, 'dem');
  await writeFile(copernicusDemPath, 'dem');

  await withRenderServer(async (baseUrl) => {
    await runScript('rebuild_stack.sh', ['--mode', 'manual'], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
        LOCAL_TOPO_HIGH_DETAIL_DEM_TIF: unreadableHighDetailDemPath,
        LOCAL_TOPO_THELIST_DEM_TIF: thelistDemPath,
        LOCAL_TOPO_COPERNICUS_DEM_TIF: copernicusDemPath,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
      },
    });
  });

  const metadataPath = join(
    workspace.outputDir,
    'tiles',
    'tasmania',
    'local-topo',
    'source-metadata.json',
  );
  const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));

  assert.equal(metadata.demSource.label, 'theLIST 25m DEM');

  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
});

test('scheduled rebuild falls back to stale but valid OSM data when refresh download fails', async () => {
  const workspace = await makeTestWorkspace();
  const managedOsmPath = join(workspace.inputDir, 'osm', 'tasmania-latest.osm.pbf');
  const thelistDemPath = join(workspace.root, 'thelist.tif');
  await writeFile(managedOsmPath, '1234567890abcdef');
  await writeFile(thelistDemPath, 'dem');
  const staleEpoch = 1732406400;
  await utimes(managedOsmPath, staleEpoch, staleEpoch);

  let stdout = '';
  await withRenderServer(async (baseUrl) => {
    const run = await runScript('scheduled_refresh.sh', [], {
      env: {
        ...process.env,
        ...workspace.env,
        FAKE_CURL_FAIL: '1',
        LOCAL_TOPO_THELIST_DEM_TIF: thelistDemPath,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
      },
    });
    stdout = run.stdout;
  });

  const metadataPath = join(
    workspace.outputDir,
    'tiles',
    'tasmania',
    'local-topo',
    'source-metadata.json',
  );
  const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));

  assert.match(stdout, /using stale OSM data/i);
  assert.equal(metadata.osmSource.usedStaleFallback, 1);

  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
});
