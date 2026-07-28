#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

dry_run=0
mode="manual"
force_source_refresh=0
dem_source="elvis-topo"
custom_dem_path=""

print_usage() {
  cat <<'EOF'
Usage: ./scripts/rebuild_stack.sh [options]

Rebuild the Tasmania Local Topo stack from prepared artifacts only.

Options:
  --mode manual|scheduled      Select rebuild mode.
  --dry-run                    Print commands without executing them.
  --force-source-refresh       Force a managed OSM refresh.
  --dem-source SOURCE          Select DEM source: elvis-topo, thelist, copernicus, or custom.
  --dem-path ABSOLUTE_PATH     Required with --dem-source=custom; must point to a readable EPSG:28355 GeoTIFF.
  --help                       Show this usage text.

Named DEM sources must already be prepared. The default elvis-topo source uses the
prepared ELVIS topo DEM and does not invoke ./elvis_dem.sh or rescan the raw ELVIS source.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --help)
      print_usage
      exit 0
      ;;
    --dry-run)
      dry_run=1
      ;;
    --mode=*)
      mode="${1#--mode=}"
      ;;
    --mode)
      shift
      if [ "$#" -eq 0 ]; then
        fail "--mode requires a value"
      fi
      mode="$1"
      ;;
    --force-source-refresh)
      force_source_refresh=1
      ;;
    --dem-source=*)
      dem_source="${1#--dem-source=}"
      ;;
    --dem-source)
      shift
      if [ "$#" -eq 0 ]; then
        fail "--dem-source requires a value"
      fi
      dem_source="$1"
      ;;
    --dem-path=*)
      custom_dem_path="${1#--dem-path=}"
      ;;
    --dem-path)
      shift
      if [ "$#" -eq 0 ]; then
        fail "--dem-path requires a value"
      fi
      custom_dem_path="$1"
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

case "$dem_source" in
  elvis-topo|thelist|copernicus|custom)
    ;;
  *)
    fail "Unsupported DEM source: $dem_source"
    ;;
esac

ensure_stack_dirs

resolve_osm_source "$mode" "$force_source_refresh" "$dry_run"
select_dem_source "$dem_source" "$custom_dem_path"
select_contour_plan
prepare_osm_extract_for_build "$dry_run"
build_osm_mbtiles "$dry_run"
build_relief_artifacts "$dry_run"
build_contour_artifacts "$dry_run"
prerender_static_tiles "$dry_run"

if [ "$dry_run" -eq 0 ]; then
  write_source_metadata
  printf 'Finished %s rebuild path with %s and %sm contours.\n' \
    "$mode" \
    "$selected_dem_label" \
    "$selected_contour_interval_meters"
fi
