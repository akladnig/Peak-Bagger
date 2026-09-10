DO $$
DECLARE
  required_layer text;
  required_layers text[] := ARRAY[
    'landcover',
    'landuse',
    'water',
    'water_name',
    'waterway',
    'cliff',
    'transportation',
    'transportation_name',
    'building',
    'place',
    'place_area',
    'poi',
    'poi_area',
    'park',
    'boundary'
  ];
BEGIN
  FOREACH required_layer IN ARRAY required_layers LOOP
    IF to_regclass(format('local_topo_preview_stage.%I', required_layer)) IS NULL THEN
      RAISE EXCEPTION 'Missing required staged preview layer local_topo_preview_stage.%', required_layer;
    END IF;
  END LOOP;
END
$$;
