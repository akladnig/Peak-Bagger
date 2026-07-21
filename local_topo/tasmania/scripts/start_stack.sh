#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

mode="static"

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

"$script_dir/prepare_smoke_fixture.sh"

unset LOCAL_TOPO_STATIC_TILE_ROOT
unset TILESERVER_STYLE_ID
unset TILESERVER_DATASET_ID

if [ "$mode" = "preview" ]; then
  if [ ! -f "$output_dir/tasmania-osm.mbtiles" ] || [ ! -f "$output_dir/tasmania-relief.mbtiles" ] || [ ! -f "$output_dir/tasmania-contours.mbtiles" ]; then
    printf 'Preview mode requires rebuilt output/tasmania-osm.mbtiles, output/tasmania-relief.mbtiles, and output/tasmania-contours.mbtiles\n' >&2
    exit 1
  fi

  export TILESERVER_STYLE_ID="tasmania-local-topo"
  printf 'Using explicit on-demand Tasmania style tiles from output/*.mbtiles\n'
elif [ -f "$static_tiles_probe_path" ]; then
  export LOCAL_TOPO_STATIC_TILE_ROOT="$static_tiles_root"
  printf 'Using pre-rendered static tiles from %s\n' "$static_tiles_root"
else
  export LOCAL_TOPO_STATIC_TILE_ROOT="$smoke_static_tile_root"
  printf 'Using deterministic static smoke fixture because %s is missing\n' "$static_tiles_probe_path"
fi

docker compose -f "$stack_dir/docker-compose.yml" up -d

base_url="http://127.0.0.1:${LOCAL_TOPO_PORT:-8090}"
capabilities_url="$base_url/capabilities"
tile_url="$base_url/tasmania/local-topo/0/0/0.png"

for attempt in $(seq 1 30); do
  capabilities_status="$(curl -s -o /dev/null -w '%{http_code}' "$capabilities_url" || true)"
  tile_status="$(curl -s -o /dev/null -w '%{http_code}' "$tile_url" || true)"
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
