import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import { chmod, mkdtemp, mkdir, readFile, rm, writeFile } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

async function runStartStack(args = [], options = {}) {
  return execFileAsync('./scripts/start_stack.sh', args, {
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
  await rm(workspace.scratchRoot, { force: true, recursive: true });
  await rm(workspace.root, { force: true, recursive: true });
}

async function makeTestWorkspace() {
  const root = await mkdtemp(join(tmpdir(), 'peak-bagger-local-topo-start-'));
  const stackRoot = new URL('..', import.meta.url).pathname;
  const scratchRoot = join(stackRoot, '.tmp-start-stack-tests', root.split('/').at(-1));
  const outputDir = join(scratchRoot, 'output');
  const runtimeDir = join(scratchRoot, 'runtime');
  const binDir = join(root, 'bin');
  const dockerLogPath = join(root, 'docker.log');
  await mkdir(outputDir, { recursive: true });
  await mkdir(runtimeDir, { recursive: true });
  await mkdir(binDir, { recursive: true });

  const dockerPath = join(binDir, 'docker');
  const curlPath = join(binDir, 'curl');

  await makeExecutableScript(
    dockerPath,
    `#!/usr/bin/env bash
set -euo pipefail
log_path=${JSON.stringify(dockerLogPath)}
printf 'argv=%s\n' "$*" >> "$log_path"
printf 'TILESERVER_STYLE_ID=%s\n' "\${TILESERVER_STYLE_ID:-}" >> "$log_path"
printf 'TILESERVER_OSM_BACKEND=%s\n' "\${TILESERVER_OSM_BACKEND:-}" >> "$log_path"
printf 'LOCAL_TOPO_STATIC_TILE_ROOT=%s\n' "\${LOCAL_TOPO_STATIC_TILE_ROOT:-}" >> "$log_path"
`,
  );

  await makeExecutableScript(
    curlPath,
    `#!/usr/bin/env bash
set -euo pipefail
url="\${@: -1}"
case "$url" in
  */capabilities)
    printf '%s' "\${FAKE_CURL_CAPABILITIES_STATUS:-200}"
    ;;
  */tasmania/local-topo/*)
    printf '%s' "\${FAKE_CURL_TILE_STATUS:-200}"
    ;;
  *)
    printf '%s' "\${FAKE_CURL_STATUS:-200}"
    ;;
esac
`,
  );

  return {
    root,
    scratchRoot,
    outputDir,
    runtimeDir,
    dockerLogPath,
    env: {
      LOCAL_TOPO_OUTPUT_DIR: outputDir,
      LOCAL_TOPO_RUNTIME_DIR: runtimeDir,
      LOCAL_TOPO_DOCKER_BIN: dockerPath,
      LOCAL_TOPO_CURL_BIN: curlPath,
      LOCAL_TOPO_PORT: '18090',
    },
  };
}

async function writePreviewInputs(workspace) {
  await Promise.all([
    writeFixture(join(workspace.outputDir, 'tasmania-osm.mbtiles'), 'mbtiles'),
    writeFixture(join(workspace.outputDir, 'tasmania-relief.mbtiles'), 'mbtiles'),
    writeFixture(join(workspace.outputDir, 'tasmania-contours.mbtiles'), 'mbtiles'),
  ]);
}

async function readDockerLog(workspace) {
  return readFile(workspace.dockerLogPath, 'utf8');
}

test('package scripts expose preview default, explicit preview alias, and explicit static startup', async () => {
  const packageJson = JSON.parse(await readFile(new URL('../package.json', import.meta.url), 'utf8'));

  assert.equal(packageJson.scripts['stack:up'], './scripts/start_stack.sh --mode=preview');
  assert.equal(packageJson.scripts['stack:up:preview'], './scripts/start_stack.sh --mode=preview');
  assert.equal(packageJson.scripts['stack:up:static'], './scripts/start_stack.sh --mode=static');
});

test('default startup enters preview mode with Martin preview defaults', async () => {
  const workspace = await makeTestWorkspace();
  await writePreviewInputs(workspace);

  const run = await runStartStack([], {
    env: {
      ...process.env,
      ...workspace.env,
    },
  });

  assert.match(
    run.stdout,
    /Using preview style tasmania-openstreetmap-contours-martin with martin OSM preview backend/,
  );
  assert.match(run.stdout, /Tasmania local topo stack started on http:\/\/127\.0\.0\.1:18090/);

  const dockerLog = await readDockerLog(workspace);
  assert.match(dockerLog, /argv=compose -f .*docker-compose\.yml up -d --force-recreate gateway tileserver postgis martin/);
  assert.match(dockerLog, /TILESERVER_STYLE_ID=tasmania-openstreetmap-contours-martin/);
  assert.match(dockerLog, /TILESERVER_OSM_BACKEND=martin/);
  assert.match(dockerLog, /LOCAL_TOPO_STATIC_TILE_ROOT=$/m);

  await cleanupWorkspace(workspace);
});

test('static startup ignores LOCAL_TOPO_STYLE and keeps the previous static fallback behavior', async () => {
  const workspace = await makeTestWorkspace();

  const run = await runStartStack(['--mode=static'], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_STYLE: 'not-a-real-style',
    },
  });

  assert.match(run.stdout, /Using deterministic static smoke fixture because .*0\/0\/0\.png is missing/);
  const dockerLog = await readDockerLog(workspace);
  assert.match(dockerLog, /argv=compose -f .*docker-compose\.yml up -d gateway tileserver/);
  assert.match(dockerLog, /LOCAL_TOPO_STATIC_TILE_ROOT=\/workspace\/.*\/runtime\/static/);
  assert.match(dockerLog, /TILESERVER_STYLE_ID=$/m);
  assert.match(dockerLog, /TILESERVER_OSM_BACKEND=$/m);

  await cleanupWorkspace(workspace);
});

test('preview startup rejects unsupported LOCAL_TOPO_STYLE values before compose starts', async () => {
  const workspace = await makeTestWorkspace();
  await writePreviewInputs(workspace);

  await assert.rejects(
    runStartStack([], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_STYLE: 'tasmania-local-topo',
      },
    }),
    (error) => {
      assert.match(error.stderr, /LOCAL_TOPO_STYLE must be one of:/);
      return true;
    },
  );

  await assert.rejects(readFile(workspace.dockerLogPath, 'utf8'));
  await cleanupWorkspace(workspace);
});

test('preview startup rejects unsupported LOCAL_TOPO_TILESERVER values before compose starts', async () => {
  const workspace = await makeTestWorkspace();
  await writePreviewInputs(workspace);

  await assert.rejects(
    runStartStack([], {
      env: {
        ...process.env,
        ...workspace.env,
        LOCAL_TOPO_TILESERVER: 'bad-backend',
      },
    }),
    (error) => {
      assert.match(error.stderr, /LOCAL_TOPO_TILESERVER must be either martin or tileserver/);
      return true;
    },
  );

  await assert.rejects(readFile(workspace.dockerLogPath, 'utf8'));
  await cleanupWorkspace(workspace);
});

test('preview startup fails fast when rebuilt preview inputs are missing', async () => {
  const workspace = await makeTestWorkspace();

  await assert.rejects(
    runStartStack([], {
      env: {
        ...process.env,
        ...workspace.env,
      },
    }),
    (error) => {
      assert.match(error.stderr, /Preview mode requires rebuilt preview inputs:/);
      assert.match(error.stderr, /tasmania-osm\.mbtiles/);
      assert.match(error.stderr, /tasmania-relief\.mbtiles/);
      assert.match(error.stderr, /tasmania-contours\.mbtiles/);
      return true;
    },
  );

  await assert.rejects(readFile(workspace.dockerLogPath, 'utf8'));
  await cleanupWorkspace(workspace);
});

test('LOCAL_TOPO_TILESERVER only applies to the OSM-backed preview styles', async () => {
  const workspace = await makeTestWorkspace();
  await writePreviewInputs(workspace);

  const run = await runStartStack([], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_STYLE: 'tasmania-maptiler-topo',
      LOCAL_TOPO_TILESERVER: 'tileserver',
    },
  });

  assert.match(
    run.stdout,
    /Using preview style tasmania-maptiler-topo; LOCAL_TOPO_TILESERVER does not retarget this non-OSM preview style/,
  );

  const dockerLog = await readDockerLog(workspace);
  assert.match(dockerLog, /TILESERVER_STYLE_ID=tasmania-maptiler-topo/);
  assert.match(dockerLog, /TILESERVER_OSM_BACKEND=$/m);

  await cleanupWorkspace(workspace);
});

test('LOCAL_TOPO_TILESERVER=tileserver keeps the legacy OSM comparison path available', async () => {
  const workspace = await makeTestWorkspace();
  await writePreviewInputs(workspace);

  const run = await runStartStack([], {
    env: {
      ...process.env,
      ...workspace.env,
      LOCAL_TOPO_STYLE: 'tasmania-openstreetmap-contours',
      LOCAL_TOPO_TILESERVER: 'tileserver',
    },
  });

  assert.match(
    run.stdout,
    /Using preview style tasmania-openstreetmap-contours with tileserver OSM preview backend/,
  );

  const dockerLog = await readDockerLog(workspace);
  assert.match(dockerLog, /TILESERVER_STYLE_ID=tasmania-openstreetmap-contours/);
  assert.match(dockerLog, /TILESERVER_OSM_BACKEND=tileserver/);

  await cleanupWorkspace(workspace);
});
