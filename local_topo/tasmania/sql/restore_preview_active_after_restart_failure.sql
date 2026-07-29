BEGIN;

DROP SCHEMA IF EXISTS local_topo_preview_active CASCADE;
ALTER SCHEMA local_topo_preview_retired RENAME TO local_topo_preview_active;
CREATE SCHEMA IF NOT EXISTS local_topo_preview_stage;

COMMIT;
