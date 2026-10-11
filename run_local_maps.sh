#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/local_slovenia_proxy.sh"

defines_file="$script_dir/dart_defines.local.json"
flutter_log_path="$script_dir/.dart_tool/run_local_maps.log"
local_topo_dir="$script_dir/local_topo/tasmania"
# An explicit URL uses an externally managed server, including SSH tunnels.
local_topo_base_url="${LOCAL_TOPO_BASE_URL:-http://127.0.0.1:${LOCAL_TOPO_PORT:-8090}}"
local_topo_base_url="${local_topo_base_url%/}"

started_proxy=0
started_local_topo_stack=0

local_topo_is_ready() {
  local capabilities_status
  local tile_status
  capabilities_status="$(curl --connect-timeout 5 --max-time 15 -s -o /dev/null -w '%{http_code}' "$local_topo_base_url/capabilities" || true)"
  tile_status="$(curl --connect-timeout 5 --max-time 15 -s -o /dev/null -w '%{http_code}' "$local_topo_base_url/tasmania/local-topo/0/0/0.png" || true)"
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
  if [ -n "${LOCAL_TOPO_BASE_URL:-}" ]; then
    printf 'Local tile server readiness checks failed at %s\n' "$local_topo_base_url" >&2
    printf 'Check that server and its /capabilities and /tasmania/local-topo/0/0/0.png endpoints.\n' >&2
    exit 1
  fi
  if docker info >/dev/null 2>&1; then
    npm run stack:up --prefix "$local_topo_dir"
    started_local_topo_stack=1
  else
    local_topo_base_url="http://mac-mini.local:8090"
    if ! local_topo_is_ready; then
      printf 'Local Docker engine is unavailable and the Mini tile server is not ready at %s.\n' "$local_topo_base_url" >&2
      printf 'Check the Mini server, or set LOCAL_TOPO_BASE_URL to its reachable URL.\n' >&2
      printf 'For a MacBook-hosted stack, start Docker Desktop first.\n' >&2
      exit 1
    fi
    printf 'Using existing Tasmania local topo stack at %s\n' "$local_topo_base_url"
  fi
else
  printf 'Using existing Tasmania local topo stack at %s\n' "$local_topo_base_url"
fi

printf 'In Peak Bagger settings, save %s as Local tile server base URL.\n' "$local_topo_base_url"

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
