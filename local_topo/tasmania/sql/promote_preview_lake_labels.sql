BEGIN;
CREATE SCHEMA IF NOT EXISTS local_topo_lake_labels_retired;
DROP TABLE IF EXISTS local_topo_lake_labels_retired.lake_labels;
ALTER TABLE IF EXISTS local_topo_preview_active.lake_labels SET SCHEMA local_topo_lake_labels_retired;
ALTER TABLE local_topo_preview_stage.lake_labels SET SCHEMA local_topo_preview_active;
COMMIT;
