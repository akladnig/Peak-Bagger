#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/local_slovenia_proxy.sh"

defines_file="$script_dir/dart_defines.local.json"
flutter_log_path="$script_dir/.dart_tool/run_local_maps.log"
local_topo_dir="$script_dir/local_topo/tasmania"
local_topo_base_url="http://127.0.0.1:${LOCAL_TOPO_PORT:-8090}"

started_proxy=0
started_local_topo_stack=0

local_topo_is_ready() {
  local capabilities_status
  local tile_status
  capabilities_status="$(curl -s -o /dev/null -w '%{http_code}' "$local_topo_base_url/capabilities" || true)"
  tile_status="$(curl -s -o /dev/null -w '%{http_code}' "$local_topo_base_url/tasmania/local-topo/0/0/0.png" || true)"
  [ "$capabilities_status" = "200" ] && [ "$tile_status" = "200" ]
}

cleanup() {
  if [ "$started_local_topo_stack" -eq 1 ]; then
    npm run stack:down --prefix "$local_topo_dir" >/dev/null 2>&1 || true
  fi
  if [ "$started_proxy" -eq 1 ]; then
    stop_managed_proxy >/dev/null 2>&1 || true
  fi
}

has_device_arg=0
for arg in "$@"; do
  case "$arg" in
    -d|--device-id|--device-id=*)
      has_device_arg=1
      ;;
  esac
done

if [ ! -f "$defines_file" ]; then
  printf 'Missing %s\n' "$defines_file" >&2
  printf 'Create it from dart_defines.example.json before running this helper.\n' >&2
  exit 1
fi

trap cleanup EXIT INT TERM

mkdir -p "$script_dir/.dart_tool"

if ! proxy_is_ready; then
  start_managed_proxy
  started_proxy=1
else
  printf 'Using existing Slovenia proxy on port %s\n' "$proxy_port"
fi

if ! local_topo_is_ready; then
  if [ -f "$local_topo_dir/output/tasmania-osm.mbtiles" ] && [ -f "$local_topo_dir/output/tasmania-relief.mbtiles" ] && [ -f "$local_topo_dir/output/tasmania-contours.mbtiles" ]; then
    npm run stack:up:preview --prefix "$local_topo_dir"
  else
    npm run stack:up --prefix "$local_topo_dir"
  fi
  started_local_topo_stack=1
else
  printf 'Using existing Tasmania local topo stack at %s\n' "$local_topo_base_url"
fi

flutter_args=(run --dart-define-from-file=dart_defines.local.json)
if [ "$has_device_arg" -eq 0 ]; then
  flutter_args+=(-d macos)
fi
flutter_args+=("$@")

printf 'Running: flutter'
for arg in "${flutter_args[@]}"; do
  printf ' %q' "$arg"
done
printf '\n'
printf 'Flutter log: %s\n' "$flutter_log_path"

flutter "${flutter_args[@]}" 2>&1 | tee "$flutter_log_path"
