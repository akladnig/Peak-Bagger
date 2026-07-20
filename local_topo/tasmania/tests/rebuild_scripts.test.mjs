import assert from 'node:assert/strict';
import { execFile } from 'node:child_process';
import test from 'node:test';
import { promisify } from 'node:util';

const execFileAsync = promisify(execFile);

async function runScript(scriptName, args = []) {
  return execFileAsync(`./scripts/${scriptName}`, args, {
    cwd: new URL('..', import.meta.url),
  });
}

test('manual refresh dry-run advertises the theLIST, Planetiler, and contour build path', async () => {
  const { stdout } = await runScript('manual_refresh.sh', ['--dry-run']);

  assert.match(
    stdout,
    /(download_tasmania_thelist_dem\.dart|Using existing merged DEM:)/,
  );
  assert.match(stdout, /ghcr\.io\/onthegomap\/planetiler:latest/);
  assert.match(stdout, /gdal_contour/);
  assert.match(stdout, /ogr2ogr/);
  assert.match(stdout, /tippecanoe/);
});

test('scheduled refresh dry-run forces fresh Tasmania source downloads', async () => {
  const { stdout } = await runScript('scheduled_refresh.sh', ['--dry-run']);

  assert.match(stdout, /download\.geofabrik\.de\/australia-oceania\/australia\/tasmania-latest\.osm\.pbf/);
  assert.match(
    stdout,
    /(download_tasmania_thelist_dem\.dart|Using existing merged DEM:)/,
  );
  assert.match(stdout, /tasmania-osm\.mbtiles/);
  assert.match(stdout, /tasmania-contours\.mbtiles/);
});
