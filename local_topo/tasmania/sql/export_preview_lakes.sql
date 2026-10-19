-- area_id is osm2pgsql's signed area identity: positive way, negative relation.
-- Group BEFORE clipping; preserve holes and disconnected relation components.
WITH lakes AS (
  SELECT area_id, name, ST_UnaryUnion(ST_Collect(ST_MakeValid(geom))) AS geom
  FROM local_topo_preview_stage.water
  WHERE name IS NOT NULL AND btrim(name) <> ''
    AND class IN ('water', 'lake', 'pond', 'reservoir')
  GROUP BY area_id, name
)
SELECT jsonb_build_object(
  'id', CASE WHEN area_id < 0 THEN 'relation/' || -area_id ELSE 'way/' || area_id END,
  'name', name,
  'area_m2', ST_Area(ST_Transform(geom, 4326)::geography),
  'geometry', ST_AsGeoJSON(geom)::jsonb,
  'anchor', ST_AsGeoJSON(ST_PointOnSurface(geom))::jsonb -> 'coordinates'
)
FROM lakes ORDER BY area_id;
