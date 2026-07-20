#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stack_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$stack_dir/../.." && pwd)"

runtime_dir="$stack_dir/runtime"
input_dir="$stack_dir/input"
output_dir="$stack_dir/output"
osm_dir="$input_dir/osm"
dem_dir="$input_dir/dem/thelist_25m"

osm_extract_path="$osm_dir/tasmania-latest.osm.pbf"
smoke_mbtiles_path="$runtime_dir/tasmania-local-topo-smoke.mbtiles"

geofabrik_tasmania_url="https://download.geofabrik.de/australia-oceania/tasmania-latest.osm.pbf"
smoke_png_hex="89504E470D0A1A0A0000000D4948445200000001000000010804000000B51C0C020000000B4944415478DA63FCFF1F0003030200EDA5610D0000000049454E44AE426082"

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

ensure_stack_dirs() {
  mkdir -p "$runtime_dir" "$input_dir" "$output_dir" "$osm_dir" "$input_dir/dem"
}
