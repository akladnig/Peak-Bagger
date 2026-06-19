#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/local_slovenia_proxy.sh"

defines_file="$script_dir/dart_defines.local.json"

started_proxy=0

cleanup() {
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

if ! proxy_is_ready; then
  start_managed_proxy
  started_proxy=1
else
  printf 'Using existing Slovenia proxy on port %s\n' "$proxy_port"
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

flutter "${flutter_args[@]}"
