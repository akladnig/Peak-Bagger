BEGIN;

DROP SCHEMA IF EXISTS local_topo_preview_retired CASCADE;
ALTER SCHEMA local_topo_preview_active RENAME TO local_topo_preview_retired;
ALTER SCHEMA local_topo_preview_stage RENAME TO local_topo_preview_active;
CREATE SCHEMA local_topo_preview_stage;

COMMIT;
