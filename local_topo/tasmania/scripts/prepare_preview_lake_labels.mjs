import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { prepareLabels } from './lake_labels.mjs';

export const exportSql = readFileSync(
  new URL('../sql/export_preview_lakes.sql', import.meta.url),
  'utf8',
);

export function labelSql(labels) {
  const json = JSON.stringify(labels).replaceAll("'", "''");
  return `BEGIN;
DROP TABLE IF EXISTS local_topo_preview_stage.lake_labels;
CREATE TABLE local_topo_preview_stage.lake_labels (
  fid bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  label_id text UNIQUE NOT NULL, lake_id text NOT NULL, name text NOT NULL,
  area_m2 double precision NOT NULL, label_zoom integer NOT NULL CHECK (label_zoom BETWEEN 13 AND 18),
  geom geometry(Point,3857) NOT NULL
);
INSERT INTO local_topo_preview_stage.lake_labels(label_id,lake_id,name,area_m2,label_zoom,geom)
SELECT id,lake_id,name,area_m2,zoom,ST_SetSRID(ST_MakePoint((point->>0)::float8,(point->>1)::float8),3857)
FROM jsonb_to_recordset('${json}'::jsonb)
AS l(id text,lake_id text,name text,area_m2 float8,zoom integer,point jsonb);
CREATE INDEX ON local_topo_preview_stage.lake_labels USING gist(geom);
ANALYZE local_topo_preview_stage.lake_labels;
COMMIT;`;
}

export function preparePreviewLakeLabels(runSql, { fromActive = false } = {}) {
  const rows = runSql(
    fromActive
      ? exportSql.replaceAll(
          'local_topo_preview_stage.water',
          'local_topo_preview_active.water',
        )
      : exportSql,
  ).trim();
  const lakes = rows ? rows.split('\n').map((row) => JSON.parse(row)) : [];
  const labels = prepareLabels(lakes);
  runSql(labelSql(labels));
  return { lakes: lakes.length, labels: labels.length };
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) {
  if (process.argv.slice(2).some((arg) => arg !== '--from-active'))
    throw new Error('Only --from-active is supported');
  const stackDir = fileURLToPath(new URL('..', import.meta.url));
  const db =
    process.env.LOCAL_TOPO_PREVIEW_DATABASE_URL ||
    'postgresql://postgres:postgres@postgis:5432/local_topo_preview';
  const result = preparePreviewLakeLabels(
    (sql) =>
      execFileSync(
        process.env.LOCAL_TOPO_DOCKER_BIN || 'docker',
        [
          'compose',
          '-f',
          `${stackDir}/docker-compose.yml`,
          'exec',
          '-T',
          'postgis',
          'psql',
          db,
          '-X',
          '-qAt',
          '-v',
          'ON_ERROR_STOP=1',
          '-f',
          '-',
        ],
        { input: sql, encoding: 'utf8', maxBuffer: 256 * 1024 * 1024 },
      ),
    { fromActive: process.argv.includes('--from-active') },
  );
  console.log(
    `Prepared ${result.labels} lake labels from ${result.lakes} whole lakes in staged preview data.`,
  );
}
