#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

ensure_stack_dirs

if ! command -v sqlite3 >/dev/null 2>&1; then
  printf 'Missing required command: sqlite3\n' >&2
  exit 1
fi

rm -f "$smoke_mbtiles_path"

sqlite3 "$smoke_mbtiles_path" \
  "PRAGMA application_id=0;" \
  "CREATE TABLE metadata (name text, value text);" \
  "INSERT INTO metadata VALUES ('name', 'tasmania-local-topo-smoke');" \
  "INSERT INTO metadata VALUES ('type', 'baselayer');" \
  "INSERT INTO metadata VALUES ('version', '1');" \
  "INSERT INTO metadata VALUES ('description', 'Deterministic smoke-test raster fixture for Peak Bagger local topo.');" \
  "INSERT INTO metadata VALUES ('format', 'png');" \
  "INSERT INTO metadata VALUES ('minzoom', '0');" \
  "INSERT INTO metadata VALUES ('maxzoom', '0');" \
  "INSERT INTO metadata VALUES ('bounds', '143.8,-43.8,148.6,-39.0');" \
  "CREATE TABLE tiles (zoom_level integer, tile_column integer, tile_row integer, tile_data blob);" \
  "CREATE UNIQUE INDEX tile_index ON tiles (zoom_level, tile_column, tile_row);" \
  "INSERT INTO tiles VALUES (0, 0, 0, X'$smoke_png_hex');"

printf 'Prepared smoke fixture: %s\n' "$smoke_mbtiles_path"
