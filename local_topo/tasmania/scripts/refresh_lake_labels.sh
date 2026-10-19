#!/usr/bin/env bash
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"
dry_run=0
case "${1:-}" in
  --dry-run) dry_run=1 ;;
  '') ;;
  *) fail 'Usage: bash scripts/refresh_lake_labels.sh [--dry-run]' ;;
esac
[ "$#" -le 1 ] || fail 'Usage: bash scripts/refresh_lake_labels.sh [--dry-run]'
ensure_stack_dirs
# Derive from the already imported selected OSM source, without reimporting it.
# Like full refreshes, this explicit maintainer operation must run serially.
ensure_preview_postgis_service "$dry_run"
LOCAL_TOPO_PREVIEW_DATABASE_URL="$preview_database_url" LOCAL_TOPO_DOCKER_BIN="$docker_bin" \
  run_command "$dry_run" "$node_bin" "$script_dir/prepare_preview_lake_labels.mjs" --from-active
run_preview_postgis_sql "$dry_run" "$sql_dir/validate_preview_lake_labels.sql"
validate_preview_stage_martin "$dry_run" lake_labels
run_preview_postgis_sql "$dry_run" "$sql_dir/promote_preview_lake_labels.sql"
if ! run_command "$dry_run" "$docker_bin" compose -f "$stack_dir/docker-compose.yml" restart martin tileserver; then
  run_preview_postgis_sql 0 "$sql_dir/restore_preview_lake_labels.sql"
  run_command 0 "$docker_bin" compose -f "$stack_dir/docker-compose.yml" restart martin tileserver || true
  fail 'Preview restart failed; restored previous lake-label data.'
fi
