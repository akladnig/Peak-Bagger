#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

mode="preview"
preview_style_id="${LOCAL_TOPO_STYLE:-tasmania-openstreetmap-contours-martin}"
preview_tileserver="${LOCAL_TOPO_TILESERVER:-martin}"

supported_preview_styles=(
  tasmania-openstreetmap-contours-martin
  tasmania-openstreetmap-contours
  tasmania-maptiler-topo
  tasmania-maptiler-outdoor
)

joined_preview_styles="$(IFS=', '; printf '%s' "${supported_preview_styles[*]}")"

is_supported_preview_style() {
  local style_id="$1"
  case "$style_id" in
    tasmania-openstreetmap-contours-martin|tasmania-openstreetmap-contours|tasmania-maptiler-topo|tasmania-maptiler-outdoor)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_supported_preview_tileserver() {
  local backend="$1"
  case "$backend" in
    martin|tileserver)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

preview_style_uses_osm_backend() {
  local style_id="$1"
  case "$style_id" in
    tasmania-openstreetmap-contours-martin|tasmania-openstreetmap-contours)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --mode=*)
      mode="${1#--mode=}"
      ;;
    --mode)
      shift
      mode="$1"
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$mode" != "static" ] && [ "$mode" != "preview" ]; then
  printf 'Unsupported mode: %s\n' "$mode" >&2
  exit 1
fi

if [ "$mode" = "preview" ]; then
  if ! is_supported_preview_style "$preview_style_id"; then
    printf 'LOCAL_TOPO_STYLE must be one of: %s\n' "$joined_preview_styles" >&2
    exit 1
  fi

  if ! is_supported_preview_tileserver "$preview_tileserver"; then
    printf 'LOCAL_TOPO_TILESERVER must be either martin or tileserver\n' >&2
    exit 1
  fi
fi

unset LOCAL_TOPO_STATIC_TILE_ROOT
unset TILESERVER_STYLE_ID
unset TILESERVER_DATASET_ID
unset TILESERVER_TILE_SCALE
unset TILESERVER_OSM_BACKEND

compose_args=(up -d)

if [ "$mode" = "preview" ]; then
  missing_preview_inputs=()
  for required_path in \
    "$output_dir/tasmania-osm.mbtiles" \
    "$output_dir/tasmania-relief.mbtiles" \
    "$output_dir/tasmania-contours.mbtiles"; do
    if [ ! -f "$required_path" ]; then
      missing_preview_inputs+=("$required_path")
    fi
  done

  if [ "${#missing_preview_inputs[@]}" -gt 0 ]; then
    printf 'Preview mode requires rebuilt preview inputs:\n' >&2
    for required_path in "${missing_preview_inputs[@]}"; do
      printf '  %s\n' "$required_path" >&2
    done
    exit 1
  fi

  export TILESERVER_STYLE_ID="$preview_style_id"
  export TILESERVER_TILE_SCALE="${LOCAL_TOPO_PREVIEW_TILE_SCALE:-}"
  if preview_style_uses_osm_backend "$preview_style_id"; then
    export TILESERVER_OSM_BACKEND="$preview_tileserver"
    printf 'Using preview style %s with %s OSM preview backend\n' "$preview_style_id" "$preview_tileserver"
  else
    printf 'Using preview style %s; LOCAL_TOPO_TILESERVER does not retarget this non-OSM preview style\n' "$preview_style_id"
  fi
  # TileServer GL only reads the style registry at process start.
  compose_args+=(--force-recreate gateway tileserver postgis martin)
else
  "$script_dir/prepare_smoke_fixture.sh"

  if [ -f "$static_tiles_probe_path" ]; then
    export LOCAL_TOPO_STATIC_TILE_ROOT="$(workspace_path_for_host_path "$static_tiles_root")"
    printf 'Using pre-rendered static tiles from %s\n' "$static_tiles_root"
  else
    export LOCAL_TOPO_STATIC_TILE_ROOT="$(workspace_path_for_host_path "$smoke_static_tile_root")"
    printf 'Using deterministic static smoke fixture because %s is missing\n' "$static_tiles_probe_path"
  fi
  compose_args+=(gateway tileserver)
fi

"$docker_bin" compose -f "$stack_dir/docker-compose.yml" "${compose_args[@]}"

base_url="http://127.0.0.1:${LOCAL_TOPO_PORT:-8090}"
capabilities_url="$base_url/capabilities"
tile_url="$base_url/tasmania/local-topo/0/0/0.png"

for attempt in $(seq 1 30); do
  capabilities_status="$("$curl_bin" -s -o /dev/null -w '%{http_code}' "$capabilities_url" || true)"
  tile_status="$("$curl_bin" -s -o /dev/null -w '%{http_code}' "$tile_url" || true)"
  if [ "$capabilities_status" = "200" ] && [ "$tile_status" = "200" ]; then
    printf 'Tasmania local topo stack started on %s\n' "$base_url"
    exit 0
  fi
  sleep 1
done

printf 'Tasmania local topo stack failed readiness checks.\n' >&2
printf 'Capabilities status: %s\n' "$capabilities_status" >&2
printf 'Tile status: %s\n' "$tile_status" >&2
exit 1
