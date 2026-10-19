-- Subdivision is validation-only, AFTER whole-lake area and positions have been
-- prepared. It keeps shoreline/holes checks bounded for the largest lakes.
CREATE TEMP TABLE lake_label_geometry_parts AS
WITH whole_lakes AS (
  SELECT CASE WHEN area_id < 0 THEN 'relation/' || -area_id ELSE 'way/' || area_id END AS lake_id,
    ST_UnaryUnion(ST_Collect(ST_MakeValid(geom))) AS geom
  FROM local_topo_preview_active.water
  WHERE name IS NOT NULL AND btrim(name) <> ''
    AND class IN ('water', 'lake', 'pond', 'reservoir')
  GROUP BY area_id
)
SELECT lake_id, part.geom FROM whole_lakes
CROSS JOIN LATERAL ST_Subdivide(geom,256) AS part(geom);
CREATE INDEX ON lake_label_geometry_parts USING gist(geom);
ANALYZE lake_label_geometry_parts;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM local_topo_preview_stage.lake_labels l
    WHERE NOT EXISTS (
      SELECT 1 FROM lake_label_geometry_parts p
      WHERE p.lake_id=l.lake_id AND p.geom && l.geom AND ST_Covers(p.geom,l.geom)
    )
  ) THEN RAISE EXCEPTION 'Prepared lake label is outside its whole-lake geometry'; END IF;
  IF EXISTS (
    SELECT 1 FROM local_topo_preview_stage.lake_labels
    WHERE area_m2 < 1000000 GROUP BY lake_id,label_zoom HAVING count(*) > 1
  ) THEN RAISE EXCEPTION 'Duplicate small-lake anchors'; END IF;
  IF EXISTS (
    SELECT 1 FROM local_topo_preview_stage.lake_labels a
    CROSS JOIN LATERAL (
      SELECT 1 FROM local_topo_preview_stage.lake_labels b
      WHERE a.lake_id=b.lake_id AND a.label_zoom=b.label_zoom AND a.fid<b.fid
        AND ST_DWithin(a.geom,b.geom,512 * 40075016.68557849 / (256 * power(2,a.label_zoom)))
        AND ST_Distance(a.geom,b.geom) < 512 * 40075016.68557849 / (256 * power(2,a.label_zoom))
      LIMIT 1
    ) AS violation
  ) THEN RAISE EXCEPTION 'Lake repeats violate 512 logical pixel spacing'; END IF;
END
$$;
