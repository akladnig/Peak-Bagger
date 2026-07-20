#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

dry_run=0
mode="manual"
force_source_refresh=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      ;;
    --mode=*)
      mode="${1#--mode=}"
      ;;
    --mode)
      shift
      mode="$1"
      ;;
    --force-source-refresh)
      force_source_refresh=1
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$mode" != "manual" ] && [ "$mode" != "scheduled" ]; then
  printf 'Unsupported mode: %s\n' "$mode" >&2
  exit 1
fi

if [ "$mode" = "scheduled" ]; then
  force_source_refresh=1
fi

ensure_stack_dirs

if [ "$force_source_refresh" -eq 1 ]; then
  run_command "$dry_run" curl -L "$geofabrik_tasmania_url" -o "$osm_extract_path"
fi

run_command "$dry_run" dart run tool/download_tasmania_thelist_dem.dart --output-dir "$dem_dir"

run_command "$dry_run" docker run --rm -e JAVA_TOOL_OPTIONS=-Xmx4g -v "$stack_dir:/workspace" ghcr.io/onthegomap/planetiler:latest --osm-path=/workspace/input/osm/tasmania-latest.osm.pbf --output=/workspace/output/tasmania-osm.mbtiles --force

run_command "$dry_run" gdal_contour -i 25 "$dem_dir/tasmania_dem_25m.tif" "$output_dir/tasmania-contours.geojson"

run_command "$dry_run" tippecanoe -o "$output_dir/tasmania-contours.mbtiles" -zg -l contours --force "$output_dir/tasmania-contours.geojson"

if [ "$dry_run" -eq 0 ]; then
  printf 'Finished %s rebuild path.\n' "$mode"
fi
