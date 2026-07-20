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

should_refresh_osm=0
if [ "$force_source_refresh" -eq 1 ] || [ ! -f "$osm_extract_path" ]; then
  should_refresh_osm=1
elif [ "$dry_run" -eq 0 ]; then
  osm_extract_size="$(stat -f%z "$osm_extract_path")"
  if [ "$osm_extract_size" -lt "$minimum_osm_extract_bytes" ]; then
    printf 'Refreshing Tasmania OSM extract because %s is only %s bytes\n' "$osm_extract_path" "$osm_extract_size"
    should_refresh_osm=1
  fi
fi

if [ "$should_refresh_osm" -eq 1 ]; then
  run_command "$dry_run" curl -fL "$geofabrik_tasmania_url" -o "$osm_extract_path"
fi

if [ -f "$dem_tiff_path" ]; then
  printf 'Using existing merged DEM: %s\n' "$dem_tiff_path"
else
  run_command "$dry_run" bash -lc "cd '$repo_root' && dart run tool/download_tasmania_thelist_dem.dart --output-dir '$dem_dir'"
fi

run_command "$dry_run" docker run --rm -e JAVA_TOOL_OPTIONS=-Xmx4g -v "$stack_dir:/workspace" ghcr.io/onthegomap/planetiler:latest --download --download_dir=/workspace/input/planetiler_sources --osm-path=/workspace/input/osm/tasmania-latest.osm.pbf --output=/workspace/output/tasmania-osm.mbtiles --force

run_command "$dry_run" gdal_contour -i 25 "$dem_tiff_path" "$contours_projected_geojson_path"

run_command "$dry_run" ogr2ogr -f GeoJSON -s_srs "$dem_source_srs" -t_srs EPSG:4326 "$contours_geojson_path" "$contours_projected_geojson_path"

if command -v tippecanoe >/dev/null 2>&1; then
  run_command "$dry_run" tippecanoe -o "$output_dir/tasmania-contours.mbtiles" -Z8 -z16 -l contours --force "$contours_geojson_path"
else
  run_command "$dry_run" docker run --rm -v "$stack_dir:/workspace" ubuntu:24.04 bash -lc "apt-get update >/dev/null && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tippecanoe >/dev/null && tippecanoe -o /workspace/output/tasmania-contours.mbtiles -Z8 -z16 -l contours --force /workspace/output/tasmania-contours.geojson"
fi

if [ "$dry_run" -eq 0 ]; then
  printf 'Finished %s rebuild path.\n' "$mode"
fi
