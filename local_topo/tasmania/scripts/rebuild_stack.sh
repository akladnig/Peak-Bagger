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

ensure_stack_dirs

resolve_osm_source "$mode" "$force_source_refresh" "$dry_run"
select_dem_source
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
