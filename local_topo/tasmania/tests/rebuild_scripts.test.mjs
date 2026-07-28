import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, rm, utimes, writeFile } from 'node:fs/promises';
import { createServer } from 'node:http';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
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

async function writeFixture(path, contents) {
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, contents);
}

async function cleanupWorkspace(workspace) {
  await rm(workspace.root, { force: true, recursive: true });
  await rm(workspace.scratchRoot, { force: true, recursive: true });
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

test('manual refresh dry-run defaults to elvis-topo without invoking ELVIS derivation inline', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'tasmania-local.osm.pbf');
  const homeRoot = join(workspace.root, 'home');
  const elvisTopoPath = join(
    homeRoot,
    'Documents',
    'Bushwalking',
    'DEM',
    'Tasmania',
    'elvis_topo',
    'elvis_topo_5m.tif',
  );
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await writeFixture(elvisTopoPath, 'dem');

  const { stdout } = await runScript('manual_refresh.sh', ['--dry-run'], {
    env: {
      ...process.env,
      ...workspace.env,
      HOME: homeRoot,
      LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
    },
  });

  assert.match(stdout, /Using local OSM override:/);
  assert.match(stdout, /Selected DEM source: ELVIS topo DEM/);
  assert.ok(stdout.includes(elvisTopoPath));
  assert.doesNotMatch(stdout, /download\.geofabrik\.de/);
  assert.doesNotMatch(stdout, /elvis_dem\.sh/);
  assert.doesNotMatch(stdout, /\/Volumes\/Media\/Elvis\/tas-elvis/);
  assert.match(stdout, /ghcr\.io\/onthegomap\/planetiler:latest/);
  assert.match(stdout, /gdaldem/);
  assert.match(stdout, /gdal_translate/);
  assert.match(stdout, /gdaladdo/);
  assert.match(stdout, /gdal_contour/);
  assert.match(stdout, /ogr2ogr/);
  assert.match(stdout, /tippecanoe/);
  assert.match(stdout, /prerender_tiles\.mjs/);
  assert.match(stdout, /tasmania\/local-topo/);

  await cleanupWorkspace(workspace);
});

test('scheduled refresh dry-run only fetches Geofabrik data when the managed extract is older than 30 days', async () => {
  const workspace = await makeTestWorkspace();
  const managedOsmPath = join(workspace.inputDir, 'osm', 'tasmania-latest.osm.pbf');
  const homeRoot = join(workspace.root, 'home');
  const elvisTopoPath = join(homeRoot, 'Documents', 'Bushwalking', 'DEM', 'Tasmania', 'elvis_topo', 'elvis_topo_5m.tif');
  await writeFixture(managedOsmPath, '1234567890abcdef');
  await writeFixture(elvisTopoPath, 'dem');

  const freshEpoch = 1735603200;
  await utimes(managedOsmPath, freshEpoch, freshEpoch);
  const freshRun = await runScript('scheduled_refresh.sh', ['--dry-run'], {
    env: {
      ...process.env,
      ...workspace.env,
      HOME: homeRoot,
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
      HOME: homeRoot,
    },
  });

  assert.match(staleRun.stdout, /download\.geofabrik\.de\/australia-oceania\/australia\/tasmania-latest\.osm\.pbf/);

  await cleanupWorkspace(workspace);
});

test('rebuild uses the explicitly selected thelist DEM and writes source metadata', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const thelistDemPath = join(workspace.root, 'thelist.tif');
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await writeFixture(thelistDemPath, 'dem');

  await withRenderServer(async (baseUrl) => {
    const run = await runScript('rebuild_stack.sh', ['--mode', 'manual', '--dem-source', 'thelist'], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
        LOCAL_TOPO_THELIST_DEM_TIF: thelistDemPath,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
      },
    });

    assert.match(run.stdout, /Selected DEM source: theLIST 25m DEM/);
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

  assert.equal(metadata.demSource.key, 'thelist');
  assert.equal(metadata.demSource.label, 'theLIST 25m DEM');
  assert.equal(metadata.demSource.path, thelistDemPath);
  assert.equal(metadata.contours.intervalMeters, 25);
  assert.equal(metadata.contours.sourceLabel, 'theLIST 25m DEM');
  assert.equal(metadata.contours.sourcePath, thelistDemPath);
  assert.equal(contoursGeojson.features[0]?.properties?.elev, 100);
  assert.equal(await readFile(reliefPath, 'utf8'), 'mbtiles');

  await cleanupWorkspace(workspace);
});

test('rebuild keeps copernicus fully explicit and does not auto-fallback to thelist for contours', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const thelistDemPath = join(workspace.root, 'thelist.tif');
  const copernicusDemPath = join(workspace.root, 'copernicus.tif');
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await writeFixture(thelistDemPath, 'dem');
  await writeFixture(copernicusDemPath, 'dem');

  await withRenderServer(async (baseUrl) => {
    const run = await runScript('rebuild_stack.sh', ['--mode', 'manual', '--dem-source', 'copernicus'], {
      env: {
        ...process.env,
        ...workspace.env,
        FAKE_CONTOUR_FAIL_INTERVAL: '10',
        FAKE_CONTOUR_FAIL_MATCH: 'copernicus',
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
        LOCAL_TOPO_THELIST_DEM_TIF: thelistDemPath,
        LOCAL_TOPO_COPERNICUS_DEM_TIF: copernicusDemPath,
        LOCAL_TOPO_PRERENDER_BASE_URL: baseUrl,
      },
    });

    assert.match(run.stdout, /Selected DEM source: Copernicus GLO 30/);
    assert.match(run.stdout, /Contour plan: 25m from Copernicus GLO 30/);
  });

  const metadataPath = join(
    workspace.outputDir,
    'tiles',
    'tasmania',
    'local-topo',
    'source-metadata.json',
  );
  const metadata = JSON.parse(await readFile(metadataPath, 'utf8'));

  assert.equal(metadata.demSource.key, 'copernicus');
  assert.equal(metadata.demSource.path, copernicusDemPath);
  assert.equal(metadata.contours.intervalMeters, 25);
  assert.equal(metadata.contours.sourceLabel, 'Copernicus GLO 30');
  assert.equal(metadata.contours.sourcePath, copernicusDemPath);

  await cleanupWorkspace(workspace);
});

test('rebuild accepts a custom absolute DEM path when explicitly requested', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const customDemPath = join(workspace.root, 'custom.tif');
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await writeFixture(customDemPath, 'dem');

  await withRenderServer(async (baseUrl) => {
    await runScript('rebuild_stack.sh', ['--mode', 'manual', '--dem-source', 'custom', '--dem-path', customDemPath], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
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

  assert.equal(metadata.demSource.key, 'custom');
  assert.equal(metadata.demSource.label, 'Custom DEM');
  assert.equal(metadata.demSource.path, customDemPath);

  await cleanupWorkspace(workspace);
});

test('custom DEM selection requires --dem-path', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  await writeFixture(overrideOsmPath, '1234567890abcdef');

  await assert.rejects(
    runScript('rebuild_stack.sh', ['--mode', 'manual', '--dem-source', 'custom'], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
      },
    }),
    (error) => {
      assert.match(error.stderr, /--dem-source=custom requires --dem-path/);
      return true;
    },
  );

  await cleanupWorkspace(workspace);
});

test('default elvis-topo selection fails fast with maintainer guidance when the prepared artifact is missing', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const homeRoot = join(workspace.root, 'home');
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await mkdir(join(homeRoot, 'Documents', 'Bushwalking'), { recursive: true });

  await assert.rejects(
    runScript('manual_refresh.sh', [], {
      env: {
        ...process.env,
        ...workspace.env,
        HOME: homeRoot,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
      },
    }),
    (error) => {
      assert.match(error.stderr, /Selected DEM source 'elvis-topo'/);
      assert.match(error.stderr, /\.\/elvis_dem\.sh build-topo/);
      return true;
    },
  );

  await cleanupWorkspace(workspace);
});

test('rebuild rejects DEM inputs that are not accepted as readable EPSG:28355 GeoTIFFs for this slice', async () => {
  const workspace = await makeTestWorkspace();
  const overrideOsmPath = join(workspace.root, 'override.osm.pbf');
  const customDemPath = join(workspace.root, 'custom.txt');
  await writeFixture(overrideOsmPath, '1234567890abcdef');
  await writeFixture(customDemPath, 'not-a-tiff');

  await assert.rejects(
    runScript('rebuild_stack.sh', ['--mode', 'manual', '--dem-source', 'custom', '--dem-path', customDemPath], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_OSM_EXTRACT_OVERRIDE: overrideOsmPath,
      },
    }),
    (error) => {
      assert.match(error.stderr, /readable EPSG:28355 GeoTIFF/);
      return true;
    },
  );

  await cleanupWorkspace(workspace);
});

test('scheduled rebuild falls back to stale but valid OSM data when refresh download fails', async () => {
  const workspace = await makeTestWorkspace();
  const managedOsmPath = join(workspace.inputDir, 'osm', 'tasmania-latest.osm.pbf');
  const homeRoot = join(workspace.root, 'home');
  const elvisTopoPath = join(homeRoot, 'Documents', 'Bushwalking', 'DEM', 'Tasmania', 'elvis_topo', 'elvis_topo_5m.tif');
  await writeFixture(managedOsmPath, '1234567890abcdef');
  await writeFixture(elvisTopoPath, 'dem');
  const staleEpoch = 1732406400;
  await utimes(managedOsmPath, staleEpoch, staleEpoch);

  let stdout = '';
  await withRenderServer(async (baseUrl) => {
    const run = await runScript('scheduled_refresh.sh', [], {
      env: {
        ...process.env,
        ...workspace.env,
        FAKE_CURL_FAIL: '1',
        HOME: homeRoot,
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
  assert.equal(metadata.demSource.key, 'elvis-topo');
  assert.equal(metadata.osmSource.usedStaleFallback, 1);

  await cleanupWorkspace(workspace);
});

test('help output and README document the explicit DEM source contract', async () => {
  const { stdout } = await runScript('manual_refresh.sh', ['--help']);
  const readme = await readFile(new URL('../README.md', import.meta.url), 'utf8');

  assert.match(stdout, /--dem-source SOURCE/);
  assert.match(stdout, /elvis-topo, thelist, copernicus, or custom/);
  assert.match(stdout, /--dem-path ABSOLUTE_PATH/);
  assert.doesNotMatch(stdout, /higher-detail/i);

  assert.match(readme, /--dem-source=elvis-topo/);
  assert.match(readme, /LOCAL_TOPO_ELVIS_TOPO_DEM_TIF/);
  assert.match(readme, /LOCAL_TOPO_THELIST_DEM_TIF/);
  assert.match(readme, /LOCAL_TOPO_COPERNICUS_DEM_TIF/);
  assert.doesNotMatch(readme, /DEM selection prefers a readable higher-detail local DEM/);
});
