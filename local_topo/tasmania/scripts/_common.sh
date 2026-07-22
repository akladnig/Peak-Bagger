#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stack_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$stack_dir/../.." && pwd)"

runtime_dir="${LOCAL_TOPO_RUNTIME_DIR:-$stack_dir/runtime}"
input_dir="${LOCAL_TOPO_INPUT_DIR:-$stack_dir/input}"
output_dir="${LOCAL_TOPO_OUTPUT_DIR:-$stack_dir/output}"
static_tiles_root="$output_dir/tiles"
static_tiles_layout_root="$static_tiles_root/tasmania/local-topo"
static_tiles_probe_path="$static_tiles_root/tasmania/local-topo/0/0/0.png"
source_metadata_path="$static_tiles_layout_root/source-metadata.json"
smoke_static_tile_root="$runtime_dir/static"
smoke_static_tile_path="$smoke_static_tile_root/tasmania/local-topo/0/0/0.png"
osm_dir="$input_dir/osm"
planetiler_sources_dir="$input_dir/planetiler_sources"
default_dem_tiff_path="$repo_root/assets/tasmania_dem_25m.tif"
dem_source_srs="${LOCAL_TOPO_THELIST_DEM_SRS:-EPSG:28355}"
thelist_dem_label="theLIST 25m DEM"
higher_detail_dem_label="${LOCAL_TOPO_HIGH_DETAIL_DEM_LABEL:-Higher Detail Local DEM}"
copernicus_dem_label="Copernicus GLO 30"

default_shared_dem_dir="$HOME/Documents/Bushwalking/DEM/Tasmania/thelist_25m"
configured_dem_dir="${LOCAL_TOPO_THELIST_DEM_DIR:-}"
configured_dem_tiff_path="${LOCAL_TOPO_THELIST_DEM_TIF:-}"
higher_detail_dem_tiff_path="${LOCAL_TOPO_HIGH_DETAIL_DEM_TIF:-}"
copernicus_dem_tiff_path="${LOCAL_TOPO_COPERNICUS_DEM_TIF:-}"

if [ -n "$configured_dem_dir" ]; then
  dem_dir="$configured_dem_dir"
elif [ -d "$default_shared_dem_dir/raw_zips" ] || [ -d "$default_shared_dem_dir/extracted" ]; then
  dem_dir="$default_shared_dem_dir"
else
  dem_dir="$input_dir/dem/thelist_25m"
fi

if [ -n "$configured_dem_tiff_path" ]; then
  dem_tiff_path="$configured_dem_tiff_path"
elif [ -f "$default_dem_tiff_path" ]; then
  dem_tiff_path="$default_dem_tiff_path"
else
  dem_tiff_path="$dem_dir/tasmania_dem_25m.tif"
fi

osm_extract_path="${LOCAL_TOPO_OSM_EXTRACT_PATH:-$osm_dir/tasmania-latest.osm.pbf}"
osm_extract_override_path="${LOCAL_TOPO_OSM_EXTRACT_OVERRIDE:-}"
staged_osm_extract_path="$osm_dir/tasmania-build-input.osm.pbf"
smoke_mbtiles_path="$runtime_dir/tasmania-local-topo-smoke.mbtiles"
contours_projected_geojson_path="$output_dir/tasmania-contours-projected.geojson"
contours_geojson_path="$output_dir/tasmania-contours.geojson"
relief_hillshade_tiff_path="$output_dir/tasmania-relief-hillshade.tif"
relief_mbtiles_path="$output_dir/tasmania-relief.mbtiles"

geofabrik_tasmania_url="https://download.geofabrik.de/australia-oceania/australia/tasmania-latest.osm.pbf"
minimum_osm_extract_bytes="${LOCAL_TOPO_MIN_OSM_EXTRACT_BYTES:-10000000}"
osm_refresh_max_age_days="${LOCAL_TOPO_OSM_REFRESH_MAX_AGE_DAYS:-30}"
preferred_contour_interval_meters="${LOCAL_TOPO_PREFERRED_CONTOUR_INTERVAL_METERS:-10}"
fallback_contour_interval_meters="${LOCAL_TOPO_FALLBACK_CONTOUR_INTERVAL_METERS:-25}"
preferred_contour_mode="${LOCAL_TOPO_PREFERRED_CONTOUR_MODE:-auto}"
prerender_min_zoom="${LOCAL_TOPO_PRERENDER_MIN_ZOOM:-0}"
prerender_max_zoom="${LOCAL_TOPO_PRERENDER_MAX_ZOOM:-16}"
prerender_bounds="${LOCAL_TOPO_PRERENDER_BOUNDS:-143.833,-43.643,148.482,-39.579}"
prerender_concurrency="${LOCAL_TOPO_PRERENDER_CONCURRENCY:-8}"
prerender_base_url="${LOCAL_TOPO_PRERENDER_BASE_URL:-}"
prerender_port="${LOCAL_TOPO_PRERENDER_PORT:-18080}"
prerender_resume="${LOCAL_TOPO_PRERENDER_RESUME:-0}"
curl_bin="${LOCAL_TOPO_CURL_BIN:-curl}"
docker_bin="${LOCAL_TOPO_DOCKER_BIN:-docker}"
node_bin="${LOCAL_TOPO_NODE_BIN:-node}"
gdalinfo_bin="${LOCAL_TOPO_GDALINFO_BIN:-gdalinfo}"
gdaldem_bin="${LOCAL_TOPO_GDALDEM_BIN:-gdaldem}"
gdal_contour_bin="${LOCAL_TOPO_GDAL_CONTOUR_BIN:-gdal_contour}"
gdal_translate_bin="${LOCAL_TOPO_GDAL_TRANSLATE_BIN:-gdal_translate}"
gdaladdo_bin="${LOCAL_TOPO_GDALADDO_BIN:-gdaladdo}"
ogr2ogr_bin="${LOCAL_TOPO_OGR2OGR_BIN:-ogr2ogr}"
tippecanoe_bin="${LOCAL_TOPO_TIPPECANOE_BIN:-tippecanoe}"
smoke_png_hex="89504E470D0A1A0A0000000D4948445200000001000000010804000000B51C0C020000000B4944415478DA63FCFF1F0003030200EDA5610D0000000049454E44AE426082"
prerender_runtime_base_url=""

selected_osm_extract_path=""
selected_osm_source_kind=""
build_osm_extract_path=""
selected_dem_path=""
selected_dem_label=""
selected_contour_dem_path=""
selected_contour_source_label=""
selected_contour_interval_meters=""
used_stale_osm_fallback=0

print_command() {
  printf '+'
  for arg in "$@"; do
    printf ' %q' "$arg"
  done
  printf '\n'
}

run_command() {
  local dry_run="$1"
  shift
  print_command "$@"
  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi
  "$@"
}

fail() {
  printf '%s\n' "$*" >&2
  exit 1
}

current_time_epoch() {
  if [ -n "${LOCAL_TOPO_CURRENT_TIME_EPOCH:-}" ]; then
    printf '%s\n' "$LOCAL_TOPO_CURRENT_TIME_EPOCH"
    return 0
  fi

  date +%s
}

file_size_bytes() {
  stat -f%z "$1"
}

file_mtime_epoch() {
  stat -f%m "$1"
}

resolved_path() {
  local path="$1"
  if [ -d "$path" ]; then
    (cd "$path" && pwd)
  else
    local parent_dir
    parent_dir="$(cd "$(dirname "$path")" && pwd)"
    printf '%s/%s\n' "$parent_dir" "$(basename "$path")"
  fi
}

path_is_within_stack_dir() {
  local path
  path="$(resolved_path "$1")"
  [ "$path" = "$stack_dir" ] || [[ "$path" == "$stack_dir/"* ]]
}

workspace_path_for_host_path() {
  local path
  path="$(resolved_path "$1")"
  if ! path_is_within_stack_dir "$path"; then
    fail "Path must stay within $stack_dir for docker-backed rebuild steps: $path"
  fi

  printf '/workspace%s\n' "${path#$stack_dir}"
}

json_escape() {
  local value="$1"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  value=${value//$'\n'/\\n}
  printf '%s' "$value"
}

is_usable_osm_extract() {
  local path="$1"
  if [ ! -f "$path" ]; then
    return 1
  fi

  local size_bytes
  size_bytes="$(file_size_bytes "$path")" || return 1
  [ "$size_bytes" -ge "$minimum_osm_extract_bytes" ]
}

is_scheduled_osm_refresh_due() {
  local path="$1"

  if ! is_usable_osm_extract "$path"; then
    return 0
  fi

  local now_epoch
  local mtime_epoch
  local max_age_seconds
  now_epoch="$(current_time_epoch)"
  mtime_epoch="$(file_mtime_epoch "$path")"
  max_age_seconds=$((osm_refresh_max_age_days * 24 * 60 * 60))

  [ $((now_epoch - mtime_epoch)) -gt "$max_age_seconds" ]
}

dem_is_accepted() {
  local path="$1"
  if [ -z "$path" ] || [ ! -f "$path" ]; then
    return 1
  fi

  "$gdalinfo_bin" "$path" >/dev/null 2>&1
}

select_dem_source() {
  if dem_is_accepted "$higher_detail_dem_tiff_path"; then
    selected_dem_path="$higher_detail_dem_tiff_path"
    selected_dem_label="$higher_detail_dem_label"
  elif dem_is_accepted "$dem_tiff_path"; then
    selected_dem_path="$dem_tiff_path"
    selected_dem_label="$thelist_dem_label"
  elif dem_is_accepted "$copernicus_dem_tiff_path"; then
    selected_dem_path="$copernicus_dem_tiff_path"
    selected_dem_label="$copernicus_dem_label"
  else
    fail "No accepted local DEM is available. Provide a readable higher-detail local DEM, theLIST 25m DEM, or reserve-only Copernicus GLO 30 input."
  fi

  printf 'Selected DEM source: %s (%s)\n' "$selected_dem_label" "$selected_dem_path"
}

preferred_contours_supported() {
  local dem_path="$1"

  case "$preferred_contour_mode" in
    acceptable)
      return 0
      ;;
    fallback)
      return 1
      ;;
    auto)
      ;;
    *)
      fail "Unsupported LOCAL_TOPO_PREFERRED_CONTOUR_MODE: $preferred_contour_mode"
      ;;
  esac

  local probe_dir
  local probe_output_path
  probe_dir="$(mktemp -d "${TMPDIR:-/tmp}/peak-bagger-local-topo-contour-probe.XXXXXX")"
  probe_output_path="$probe_dir/contours.geojson"

  if "$gdal_contour_bin" -i "$preferred_contour_interval_meters" "$dem_path" "$probe_output_path" >/dev/null 2>&1; then
    rm -rf "$probe_dir"
    return 0
  fi

  rm -rf "$probe_dir"
  return 1
}

select_contour_plan() {
  if [ "$selected_dem_label" = "$thelist_dem_label" ]; then
    selected_contour_dem_path="$dem_tiff_path"
    selected_contour_source_label="$thelist_dem_label"
    selected_contour_interval_meters="$fallback_contour_interval_meters"
  elif preferred_contours_supported "$selected_dem_path"; then
    selected_contour_dem_path="$selected_dem_path"
    selected_contour_source_label="$selected_dem_label"
    selected_contour_interval_meters="$preferred_contour_interval_meters"
  elif dem_is_accepted "$dem_tiff_path"; then
    selected_contour_dem_path="$dem_tiff_path"
    selected_contour_source_label="$thelist_dem_label"
    selected_contour_interval_meters="$fallback_contour_interval_meters"
  else
    fail "Preferred ${preferred_contour_interval_meters}m contours are not acceptable for $selected_dem_label, and theLIST 25m DEM is unavailable for the required ${fallback_contour_interval_meters}m fallback contours."
  fi

  printf 'Contour plan: %sm from %s (%s)\n' \
    "$selected_contour_interval_meters" \
    "$selected_contour_source_label" \
    "$selected_contour_dem_path"
}

download_managed_osm_extract() {
  local dry_run="$1"

  print_command "$curl_bin" -fL "$geofabrik_tasmania_url" -o "$osm_extract_path"
  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi

  "$curl_bin" -fL "$geofabrik_tasmania_url" -o "$osm_extract_path"
}

resolve_osm_source() {
  local mode="$1"
  local force_source_refresh="$2"
  local dry_run="$3"

  selected_osm_extract_path="$osm_extract_path"
  selected_osm_source_kind="managed-cache"
  used_stale_osm_fallback=0

  if [ -n "$osm_extract_override_path" ]; then
    if ! is_usable_osm_extract "$osm_extract_override_path"; then
      fail "Configured local OSM override is missing or below the minimum size threshold: $osm_extract_override_path"
    fi

    selected_osm_extract_path="$osm_extract_override_path"
    selected_osm_source_kind="local-override"
    printf 'Using local OSM override: %s\n' "$selected_osm_extract_path"
    return 0
  fi

  local should_refresh=0
  if [ "$force_source_refresh" -eq 1 ]; then
    should_refresh=1
    printf 'Refreshing Tasmania OSM extract because --force-source-refresh was requested.\n'
  elif ! is_usable_osm_extract "$osm_extract_path"; then
    should_refresh=1
    printf 'Refreshing Tasmania OSM extract because %s is missing or below %s bytes.\n' "$osm_extract_path" "$minimum_osm_extract_bytes"
  elif [ "$mode" = "scheduled" ] && is_scheduled_osm_refresh_due "$osm_extract_path"; then
    should_refresh=1
    printf 'Refreshing Tasmania OSM extract because %s is older than %s days.\n' "$osm_extract_path" "$osm_refresh_max_age_days"
  else
    printf 'Reusing local Tasmania OSM extract: %s\n' "$osm_extract_path"
  fi

  if [ "$should_refresh" -eq 0 ]; then
    return 0
  fi

  if download_managed_osm_extract "$dry_run"; then
    if [ "$dry_run" -eq 1 ]; then
      return 0
    fi

    if ! is_usable_osm_extract "$osm_extract_path"; then
      fail "Downloaded Tasmania OSM extract is missing or below the minimum size threshold: $osm_extract_path"
    fi

    return 0
  fi

  if [ "$mode" = "scheduled" ] && is_usable_osm_extract "$osm_extract_path"; then
    used_stale_osm_fallback=1
    printf 'Scheduled OSM refresh failed; using stale OSM data from %s\n' "$osm_extract_path"
    return 0
  fi

  fail "Failed to refresh Tasmania OSM extract and no usable local extract is available."
}

prepare_osm_extract_for_build() {
  local dry_run="$1"

  build_osm_extract_path="$selected_osm_extract_path"
  if path_is_within_stack_dir "$selected_osm_extract_path"; then
    return 0
  fi

  build_osm_extract_path="$staged_osm_extract_path"
  run_command "$dry_run" cp "$selected_osm_extract_path" "$build_osm_extract_path"
}

build_osm_mbtiles() {
  local dry_run="$1"

  run_command \
    "$dry_run" \
    "$docker_bin" \
    run \
    --rm \
    -e JAVA_TOOL_OPTIONS=-Xmx4g \
    -v "$stack_dir:/workspace" \
    ghcr.io/onthegomap/planetiler:latest \
    --download \
    "--download_dir=$(workspace_path_for_host_path "$planetiler_sources_dir")" \
    "--osm-path=$(workspace_path_for_host_path "$build_osm_extract_path")" \
    "--output=$(workspace_path_for_host_path "$output_dir/tasmania-osm.mbtiles")" \
    --force
}

build_contour_artifacts() {
  local dry_run="$1"

  run_command \
    "$dry_run" \
    "$gdal_contour_bin" \
    -a elev \
    -i "$selected_contour_interval_meters" \
    "$selected_contour_dem_path" \
    "$contours_projected_geojson_path"

  run_command \
    "$dry_run" \
    "$ogr2ogr_bin" \
    -f GeoJSON \
    -s_srs "$dem_source_srs" \
    -t_srs EPSG:4326 \
    "$contours_geojson_path" \
    "$contours_projected_geojson_path"

  if command -v "$tippecanoe_bin" >/dev/null 2>&1; then
    run_command \
      "$dry_run" \
      "$tippecanoe_bin" \
      -o "$output_dir/tasmania-contours.mbtiles" \
      -Z10 \
      -z16 \
      -l contours \
      -y elev \
      --drop-densest-as-needed \
      --coalesce-densest-as-needed \
      --simplification=4 \
      --simplify-only-low-zooms \
      --force \
      "$contours_geojson_path"
    return 0
  fi

  run_command \
    "$dry_run" \
    "$docker_bin" \
    run \
    --rm \
    -v "$stack_dir:/workspace" \
    ubuntu:24.04 \
    bash \
    -lc \
    "apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tippecanoe >/dev/null && tippecanoe -o $(workspace_path_for_host_path "$output_dir/tasmania-contours.mbtiles") -Z10 -z16 -l contours -y elev --drop-densest-as-needed --coalesce-densest-as-needed --simplification=4 --simplify-only-low-zooms --force $(workspace_path_for_host_path "$contours_geojson_path")"
}

build_relief_artifacts() {
  local dry_run="$1"

  run_command "$dry_run" rm -f "$relief_hillshade_tiff_path" "$relief_mbtiles_path"

  run_command \
    "$dry_run" \
    "$gdaldem_bin" \
    hillshade \
    "$selected_dem_path" \
    "$relief_hillshade_tiff_path" \
    -of \
    GTiff \
    -compute_edges \
    -multidirectional

  run_command \
    "$dry_run" \
    "$gdal_translate_bin" \
    "$relief_hillshade_tiff_path" \
    "$relief_mbtiles_path" \
    -of \
    MBTILES \
    -co \
    NAME=tasmania-relief \
    -co \
    DESCRIPTION=Peak\ Bagger\ Tasmania\ terrain\ relief\ shading \
    -co \
    TILE_FORMAT=PNG \
    -co \
    BOUNDS="$prerender_bounds" \
    -co \
    ZOOM_LEVEL_STRATEGY=UPPER

  run_command \
    "$dry_run" \
    "$gdaladdo_bin" \
    -r \
    average \
    "$relief_mbtiles_path" \
    2 \
    4 \
    8 \
    16 \
    32 \
    64 \
    128 \
    256
}

start_prerender_tileserver() {
  local dry_run="$1"
  local container_name="$2"
  local base_url="http://127.0.0.1:$prerender_port"

  prerender_runtime_base_url="$base_url"

  print_command \
    "$docker_bin" \
    run \
    -d \
    --rm \
    --name "$container_name" \
    -p "127.0.0.1:${prerender_port}:8080" \
    -v "$stack_dir:/data" \
    maptiler/tileserver-gl:latest \
    -c /data/config/tileserver-config.json \
    --ignore-missing-files \
    --verbose \
    1

  if [ "$dry_run" -eq 1 ]; then
    return 0
  fi

  "$docker_bin" run -d --rm --name "$container_name" -p "127.0.0.1:${prerender_port}:8080" -v "$stack_dir:/data" maptiler/tileserver-gl:latest -c /data/config/tileserver-config.json --ignore-missing-files --verbose 1 >/dev/null

  local readiness_url="$base_url/styles/tasmania-local-topo/0/0/0.png"
  local attempt
  for attempt in $(seq 1 30); do
    if "$curl_bin" -fsS "$readiness_url" -o /dev/null >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  "$docker_bin" rm -f "$container_name" >/dev/null 2>&1 || true
  fail "Timed out waiting for the prerender TileServer GL instance to become ready."
}

stop_prerender_tileserver() {
  local container_name="$1"
  if [ -z "$container_name" ]; then
    return 0
  fi

  "$docker_bin" rm -f "$container_name" >/dev/null 2>&1 || true
}

prerender_static_tiles() {
  local dry_run="$1"
  local runtime_base_url="$prerender_base_url"
  local container_name=""

  if [ "$prerender_resume" != "1" ]; then
    run_command "$dry_run" rm -rf "$static_tiles_layout_root"
  fi
  run_command "$dry_run" mkdir -p "$static_tiles_layout_root"

  if [ -z "$runtime_base_url" ]; then
    container_name="peak-bagger-local-topo-prerender-$$-$RANDOM"
    start_prerender_tileserver "$dry_run" "$container_name"
    runtime_base_url="$prerender_runtime_base_url"
  fi

  if [ "$dry_run" -eq 0 ] && [ -n "$container_name" ]; then
    trap "stop_prerender_tileserver \"$container_name\"" EXIT
  fi

  run_command \
    "$dry_run" \
    env \
      "LOCAL_TOPO_PRERENDER_BASE_URL=$runtime_base_url" \
      "LOCAL_TOPO_PRERENDER_OUTPUT_ROOT=$static_tiles_layout_root" \
      "LOCAL_TOPO_PRERENDER_MIN_ZOOM=$prerender_min_zoom" \
      "LOCAL_TOPO_PRERENDER_MAX_ZOOM=$prerender_max_zoom" \
      "LOCAL_TOPO_PRERENDER_BOUNDS=$prerender_bounds" \
      "LOCAL_TOPO_PRERENDER_CONCURRENCY=$prerender_concurrency" \
      "LOCAL_TOPO_PRERENDER_SKIP_EXISTING=$prerender_resume" \
      "$node_bin" \
      "$script_dir/prerender_tiles.mjs"

  if [ "$dry_run" -eq 0 ] && [ -n "$container_name" ]; then
    stop_prerender_tileserver "$container_name"
    trap - EXIT
  fi
}

write_source_metadata() {
  mkdir -p "$static_tiles_layout_root"

  printf '{\n' > "$source_metadata_path"
  printf '  "demSource": {\n' >> "$source_metadata_path"
  printf '    "label": "%s",\n' "$(json_escape "$selected_dem_label")" >> "$source_metadata_path"
  printf '    "path": "%s"\n' "$(json_escape "$selected_dem_path")" >> "$source_metadata_path"
  printf '  },\n' >> "$source_metadata_path"
  printf '  "contours": {\n' >> "$source_metadata_path"
  printf '    "intervalMeters": %s,\n' "$selected_contour_interval_meters" >> "$source_metadata_path"
  printf '    "sourceLabel": "%s",\n' "$(json_escape "$selected_contour_source_label")" >> "$source_metadata_path"
  printf '    "sourcePath": "%s"\n' "$(json_escape "$selected_contour_dem_path")" >> "$source_metadata_path"
  printf '  },\n' >> "$source_metadata_path"
  printf '  "osmSource": {\n' >> "$source_metadata_path"
  printf '    "kind": "%s",\n' "$(json_escape "$selected_osm_source_kind")" >> "$source_metadata_path"
  printf '    "path": "%s",\n' "$(json_escape "$selected_osm_extract_path")" >> "$source_metadata_path"
  printf '    "usedStaleFallback": %s\n' "$used_stale_osm_fallback" >> "$source_metadata_path"
  printf '  }\n' >> "$source_metadata_path"
  printf '}\n' >> "$source_metadata_path"
}

ensure_stack_dirs() {
  mkdir -p "$runtime_dir" "$input_dir" "$output_dir" "$static_tiles_root" "$osm_dir" "$input_dir/dem" "$dem_dir" "$planetiler_sources_dir"
}
