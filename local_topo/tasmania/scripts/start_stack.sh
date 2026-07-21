#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

"$script_dir/prepare_smoke_fixture.sh"

unset TILESERVER_STYLE_ID
unset TILESERVER_DATASET_ID

if [ -f "$output_dir/tasmania-osm.mbtiles" ] && [ -f "$output_dir/tasmania-contours.mbtiles" ]; then
  export TILESERVER_STYLE_ID="tasmania-local-topo"
  printf 'Using rebuilt Tasmania style tiles from output/*.mbtiles\n'
else
  export TILESERVER_DATASET_ID="tasmania-local-topo-smoke"
  printf 'Using deterministic smoke raster fixture because rebuilt output/*.mbtiles is missing\n'
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
