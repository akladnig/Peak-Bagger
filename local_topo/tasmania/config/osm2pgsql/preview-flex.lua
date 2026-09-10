local schema = os.getenv('LOCAL_TOPO_PREVIEW_IMPORT_SCHEMA') or 'local_topo_preview_stage'

local landcover = osm2pgsql.define_area_table('landcover', {
    { column = 'class', type = 'text' },
    { column = 'subclass', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local landuse = osm2pgsql.define_area_table('landuse', {
    { column = 'class', type = 'text' },
    { column = 'subclass', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local water = osm2pgsql.define_area_table('water', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'intermittent', type = 'bool' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local waterName = osm2pgsql.define_way_table('water_name', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'intermittent', type = 'bool' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'linestring', projection = 3857, not_null = true },
}, { schema = schema })

local waterway = osm2pgsql.define_way_table('waterway', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'intermittent', type = 'bool' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'linestring', projection = 3857, not_null = true },
}, { schema = schema })

local cliff = osm2pgsql.define_way_table('cliff', {
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'linestring', projection = 3857, not_null = true },
}, { schema = schema })

local transportation = osm2pgsql.define_way_table('transportation', {
    { column = 'class', type = 'text' },
    { column = 'subclass', type = 'text' },
    { column = 'surface', type = 'text' },
    { column = 'service', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'ref', type = 'text' },
    { column = 'oneway', type = 'int2' },
    { column = 'layer', type = 'int4' },
    { column = 'bridge', type = 'bool' },
    { column = 'tunnel', type = 'bool' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'linestring', projection = 3857, not_null = true },
}, { schema = schema })

local transportationName = osm2pgsql.define_way_table('transportation_name', {
    { column = 'class', type = 'text' },
    { column = 'subclass', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'ref', type = 'text' },
    { column = 'network', type = 'text' },
    { column = 'layer', type = 'int4' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'linestring', projection = 3857, not_null = true },
}, { schema = schema })

local building = osm2pgsql.define_area_table('building', {
    { column = 'class', type = 'text' },
    { column = 'subclass', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'layer', type = 'int4' },
    { column = 'render_height', type = 'real' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local place = osm2pgsql.define_node_table('place', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'population', type = 'int8' },
    { column = 'capital', type = 'int2' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'point', projection = 3857, not_null = true },
}, { schema = schema })

local placeArea = osm2pgsql.define_area_table('place_area', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'point', projection = 3857, not_null = true },
}, { schema = schema })

local poi = osm2pgsql.define_node_table('poi', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'point', projection = 3857, not_null = true },
}, { schema = schema })

local poiArea = osm2pgsql.define_area_table('poi_area', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local park = osm2pgsql.define_area_table('park', {
    { column = 'class', type = 'text' },
    { column = 'name', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multipolygon', projection = 3857, not_null = true },
}, { schema = schema })

local boundary = osm2pgsql.define_relation_table('boundary', {
    { column = 'admin_level', type = 'text' },
    { column = 'maritime', type = 'bool' },
    { column = 'disputed', type = 'bool' },
    { column = 'name', type = 'text' },
    { column = 'tags', type = 'jsonb' },
    { column = 'geom', type = 'multilinestring', projection = 3857, not_null = true },
}, { schema = schema })

local function boolean_tag(value)
    return value == 'yes' or value == 'true' or value == '1'
end

local function integer_tag(value, fallback)
    local parsed = tonumber(value)
    if parsed == nil then
        return fallback
    end
    return math.floor(parsed)
end

local function first_tag(tags, ...)
    local keys = { ... }
    for _, key in ipairs(keys) do
        local value = tags[key]
        if value ~= nil and value ~= '' then
            return value
        end
    end
    return nil
end

local function surface_transport_class(tags)
    return first_tag(tags, 'highway', 'railway', 'aerialway')
end

local function poi_class(tags)
    if tags.tourism == 'wilderness_hut' or tags.tourism == 'alpine_hut' or tags.tourism == 'camp_site' then
        return tags.tourism
    end
    if tags.building == 'hut' then
        return 'hut'
    end
    if tags.waterway == 'waterfall' then
        return 'waterfall'
    end
    if tags.amenity == 'toilets' then
        return 'toilets'
    end
    return nil
end

local function poi_area_class(tags)
    if tags.tourism == 'wilderness_hut' or tags.tourism == 'alpine_hut' then
        return tags.tourism
    end
    if tags.building == 'hut' then
        return 'hut'
    end
    if tags.amenity == 'toilets' then
        return 'toilets'
    end
    return nil
end

function osm2pgsql.process_node(object)
    local poiClass = poi_class(object.tags)
    if poiClass ~= nil then
        poi:insert({
            class = poiClass,
            name = object.tags.name,
            geom = object:as_point(),
        })
    end

    local placeClass = object.tags.place
    if placeClass ~= nil then
        place:insert({
            class = placeClass,
            name = object.tags.name,
            population = integer_tag(object.tags.population, nil),
            capital = integer_tag(object.tags.capital, 0),
            tags = object.tags,
            geom = object:as_point(),
        })
    end
end

function osm2pgsql.process_way(object)
    local tags = object.tags

    local landcoverClass = first_tag(tags, 'natural', 'landcover')
    if object.is_closed and landcoverClass ~= nil and landcoverClass ~= 'water' then
        landcover:insert({
            class = landcoverClass,
            subclass = tags.wood,
            name = tags.name,
            tags = tags,
            geom = object:as_polygon(),
        })
    end

    local landuseClass = tags.landuse
    if object.is_closed and landuseClass ~= nil then
        landuse:insert({
            class = landuseClass,
            subclass = first_tag(tags, 'amenity', 'leisure', 'tourism'),
            name = tags.name,
            tags = tags,
            geom = object:as_polygon(),
        })
    end

    if object.is_closed and (tags.natural == 'water' or tags.water ~= nil or tags.waterway == 'riverbank') then
        water:insert({
            class = first_tag(tags, 'water', 'natural', 'waterway'),
            name = tags.name,
            intermittent = boolean_tag(tags.intermittent),
            tags = tags,
            geom = object:as_polygon(),
        })
    end

    local poiAreaClass = poi_area_class(tags)
    if object.is_closed and poiAreaClass ~= nil then
        poiArea:insert({
            class = poiAreaClass,
            name = tags.name,
            geom = object:as_polygon(),
        })
    end

    if object.is_closed and tags.place == 'islet' then
        placeArea:insert({
            class = tags.place,
            name = tags.name,
            tags = tags,
            geom = object:as_polygon():centroid(),
        })
    end

    if tags.waterway ~= nil and tags.name ~= nil then
        waterName:insert({
            class = tags.waterway,
            name = tags.name,
            intermittent = boolean_tag(tags.intermittent),
            tags = tags,
            geom = object:as_linestring(),
        })
    end

    if tags.waterway ~= nil then
        waterway:insert({
            class = tags.waterway,
            name = tags.name,
            intermittent = boolean_tag(tags.intermittent),
            tags = tags,
            geom = object:as_linestring(),
        })
    end

    if tags.natural == 'cliff' then
        cliff:insert({
            name = tags.name,
            geom = object:as_linestring(),
        })
    end

    local transportationClass = surface_transport_class(tags)
    if transportationClass ~= nil then
        transportation:insert({
            class = transportationClass,
            subclass = first_tag(tags, 'highway', 'railway', 'aerialway'),
            surface = tags.surface,
            service = tags.service,
            name = tags.name,
            ref = tags.ref,
            oneway = integer_tag(tags.oneway == '-1' and '-1' or tags.oneway == 'yes' and '1' or tags.oneway, 0),
            layer = integer_tag(tags.layer, 0),
            bridge = boolean_tag(tags.bridge),
            tunnel = boolean_tag(tags.tunnel),
            tags = tags,
            geom = object:as_linestring(),
        })
        if tags.name ~= nil or tags.ref ~= nil then
            transportationName:insert({
                class = transportationClass,
                subclass = first_tag(tags, 'highway', 'railway', 'aerialway'),
                name = tags.name,
                ref = tags.ref,
                network = first_tag(tags, 'network', 'route', 'operator'),
                layer = integer_tag(tags.layer, 0),
                tags = tags,
                geom = object:as_linestring(),
            })
        end
    end

    if object.is_closed and tags.building ~= nil then
        building:insert({
            class = tags.building,
            subclass = first_tag(tags, 'building:part', 'amenity', 'shop'),
            name = tags.name,
            layer = integer_tag(tags.layer, 0),
            render_height = tonumber(tags.height),
            tags = tags,
            geom = object:as_polygon(),
        })
    end

    if object.is_closed and (tags.leisure == 'park' or tags.boundary == 'national_park') then
        park:insert({
            class = first_tag(tags, 'leisure', 'boundary'),
            name = tags.name,
            tags = tags,
            geom = object:as_polygon(),
        })
    end
end

function osm2pgsql.process_relation(object)
    local tags = object.tags

    if (tags.type == 'multipolygon' or tags.type == 'boundary') and tags.landuse ~= nil then
        landuse:insert({
            class = tags.landuse,
            subclass = first_tag(tags, 'amenity', 'leisure', 'tourism'),
            name = tags.name,
            tags = tags,
            geom = object:as_multipolygon(),
        })
    end

    if (tags.type == 'multipolygon' or tags.type == 'boundary') and (tags.natural == 'water' or tags.water ~= nil or tags.waterway == 'riverbank') then
        water:insert({
            class = first_tag(tags, 'water', 'natural', 'waterway'),
            name = tags.name,
            intermittent = boolean_tag(tags.intermittent),
            tags = tags,
            geom = object:as_multipolygon(),
        })
    end

    local poiAreaClass = poi_area_class(tags)
    if (tags.type == 'multipolygon' or tags.type == 'boundary') and poiAreaClass ~= nil then
        poiArea:insert({
            class = poiAreaClass,
            name = tags.name,
            geom = object:as_multipolygon(),
        })
    end

    if (tags.type == 'multipolygon' or tags.type == 'boundary') and tags.place == 'islet' then
        placeArea:insert({
            class = tags.place,
            name = tags.name,
            tags = tags,
            geom = object:as_multipolygon():centroid(),
        })
    end

    if (tags.type == 'multipolygon' or tags.type == 'boundary') and tags.building ~= nil then
        building:insert({
            class = tags.building,
            subclass = first_tag(tags, 'building:part', 'amenity', 'shop'),
            name = tags.name,
            layer = integer_tag(tags.layer, 0),
            render_height = tonumber(tags.height),
            tags = tags,
            geom = object:as_multipolygon(),
        })
    end

    if (tags.type == 'multipolygon' or tags.type == 'boundary') and (tags.leisure == 'park' or tags.boundary == 'national_park') then
        park:insert({
            class = first_tag(tags, 'leisure', 'boundary'),
            name = tags.name,
            tags = tags,
            geom = object:as_multipolygon(),
        })
    end

    if tags.boundary ~= nil or tags.admin_level ~= nil then
        boundary:insert({
            admin_level = tags.admin_level,
            maritime = boolean_tag(tags.maritime),
            disputed = boolean_tag(tags.disputed),
            name = tags.name,
            tags = tags,
            geom = object:as_multilinestring(),
        })
    end
end
