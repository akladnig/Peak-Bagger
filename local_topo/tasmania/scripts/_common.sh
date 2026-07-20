#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
stack_dir="$(cd "$script_dir/.." && pwd)"
repo_root="$(cd "$stack_dir/../.." && pwd)"

runtime_dir="$stack_dir/runtime"
input_dir="$stack_dir/input"
output_dir="$stack_dir/output"
osm_dir="$input_dir/osm"
planetiler_sources_dir="$input_dir/planetiler_sources"
default_dem_tiff_path="$repo_root/assets/tasmania_dem_25m.tif"
dem_source_srs="${LOCAL_TOPO_THELIST_DEM_SRS:-EPSG:28355}"

default_shared_dem_dir="$HOME/Documents/Bushwalking/DEM/Tasmania/thelist_25m"
configured_dem_dir="${LOCAL_TOPO_THELIST_DEM_DIR:-}"
configured_dem_tiff_path="${LOCAL_TOPO_THELIST_DEM_TIF:-}"

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

osm_extract_path="$osm_dir/tasmania-latest.osm.pbf"
smoke_mbtiles_path="$runtime_dir/tasmania-local-topo-smoke.mbtiles"
contours_projected_geojson_path="$output_dir/tasmania-contours-projected.geojson"
contours_geojson_path="$output_dir/tasmania-contours.geojson"

geofabrik_tasmania_url="https://download.geofabrik.de/australia-oceania/australia/tasmania-latest.osm.pbf"
minimum_osm_extract_bytes="${LOCAL_TOPO_MIN_OSM_EXTRACT_BYTES:-10000000}"
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
  mkdir -p "$runtime_dir" "$input_dir" "$output_dir" "$osm_dir" "$input_dir/dem" "$dem_dir" "$planetiler_sources_dir"
}
