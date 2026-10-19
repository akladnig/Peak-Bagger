BEGIN;
ALTER TABLE local_topo_preview_active.lake_labels SET SCHEMA local_topo_preview_stage;
ALTER TABLE IF EXISTS local_topo_lake_labels_retired.lake_labels SET SCHEMA local_topo_preview_active;
COMMIT;
