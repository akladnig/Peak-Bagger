#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
boundaries_dir="assets/polygons/osm-boundaries"

polygon=""
output_dir=""
simplify_meters=250
outward_buffer_meters=600
final_buffer_meters=100
keep_work=false

usage() {
  cat <<'EOF'
Usage: tool/convert_osm_boundary_to_poly.sh --polygon <name> [options]

Convert an OSM boundary GeoJSON into app-compatible, single-ring .poly files.
The result is deliberately biased outward: it removes holes, applies an
outward buffer, simplifies in metres, then applies a final outward buffer.

Polygon selection:
  -p, --polygon <name>       veneto, fvg, emilia-romagna,
                              trentino-alto-adige, or all (required)

Options:
  -o, --output-dir <path>    Destination directory. Defaults to
                              build/polygon-conversion/<polygon>.
      --simplify-meters <n>  Topology-preserving simplification tolerance.
                              Default: 250.
      --outward-buffer-meters <n>
                              Initial outward buffer before simplification.
                              Default: 600.
      --final-buffer-meters <n>
                              Final outward buffer after simplification.
                              Default: 100.
      --keep-work            Preserve projected intermediate geometries.
  -h, --help                 Show this help.

Examples:
  tool/convert_osm_boundary_to_poly.sh --polygon veneto
  tool/convert_osm_boundary_to_poly.sh --polygon fvg --simplify-meters 350 \
    --outward-buffer-meters 800

The script never writes to assets/polygons. Review the generated GeoJSON and
.poly files before copying selected outputs into the app assets.
EOF
}

require_value() {
  if [ "$#" -lt 2 ] || [ -z "$2" ]; then
    printf 'Missing value for %s\n' "$1" >&2
    exit 1
  fi
}

is_positive_number() {
  awk -v value="$1" 'BEGIN { exit !(value > 0) }'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -p|--polygon|--region)
      require_value "$1" "${2:-}"
      polygon="$2"
      shift
      ;;
    --polygon=*|--region=*)
      polygon="${1#*=}"
      ;;
    -o|--output-dir)
      require_value "$1" "${2:-}"
      output_dir="$2"
      shift
      ;;
    --output-dir=*)
      output_dir="${1#*=}"
      ;;
    --simplify-meters)
      require_value "$1" "${2:-}"
      simplify_meters="$2"
      shift
      ;;
    --simplify-meters=*)
      simplify_meters="${1#*=}"
      ;;
    --outward-buffer-meters)
      require_value "$1" "${2:-}"
      outward_buffer_meters="$2"
      shift
      ;;
    --outward-buffer-meters=*)
      outward_buffer_meters="${1#*=}"
      ;;
    --final-buffer-meters)
      require_value "$1" "${2:-}"
      final_buffer_meters="$2"
      shift
      ;;
    --final-buffer-meters=*)
      final_buffer_meters="${1#*=}"
      ;;
    --keep-work)
      keep_work=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      usage >&2
      exit 1
      ;;
  esac
  shift
done

if [ -z "$polygon" ]; then
  printf 'A polygon selection is required.\n' >&2
  usage >&2
  exit 1
fi

for value in "$simplify_meters" "$outward_buffer_meters" "$final_buffer_meters"; do
  if ! is_positive_number "$value"; then
    printf 'Distance values must be positive numbers: %s\n' "$value" >&2
    exit 1
  fi
done

for command in ogr2ogr python3; do
  if ! command -v "$command" >/dev/null 2>&1; then
    printf 'Required command not found: %s\n' "$command" >&2
    exit 1
  fi
done

source_for_polygon() {
  case "$1" in
    veneto)
      printf '%s\n' "$boundaries_dir/veneto_poly.geojson"
      ;;
    fvg)
      printf '%s\n' "$boundaries_dir/fvg.geojson.gz"
      ;;
    emilia-romagna)
      printf '%s\n' "$boundaries_dir/emilia-romagna.geojson.gz"
      ;;
    trentino-alto-adige)
      printf '%s\n' "$boundaries_dir/taa.geojson.gz"
      ;;
    *)
      return 1
      ;;
  esac
}

selected_polygons=()
if [ "$polygon" = "all" ]; then
  selected_polygons=(veneto fvg emilia-romagna trentino-alto-adige)
else
  if ! source_for_polygon "$polygon" >/dev/null; then
    printf 'Unsupported polygon: %s\n' "$polygon" >&2
    exit 1
  fi
  selected_polygons=("$polygon")
fi

if [ -z "$output_dir" ]; then
  output_dir="$repo_root/build/polygon-conversion/$polygon"
elif [[ "$output_dir" != /* ]]; then
  output_dir="$repo_root/$output_dir"
fi

mkdir -p "$output_dir"
work_dir="$(mktemp -d "${TMPDIR:-/tmp}/peak-bagger-polygons.XXXXXX")"

cleanup() {
  if [ "$keep_work" = true ]; then
    printf 'Intermediate files retained at %s\n' "$work_dir"
  else
    rm -rf "$work_dir"
  fi
}
trap cleanup EXIT

convert_polygon() {
  local selected_polygon="$1"
  local source
  local source_input
  local raw_path
  local outer_path
  local candidate_path

  source="$(source_for_polygon "$selected_polygon")"
  if [ ! -f "$repo_root/$source" ]; then
    printf 'Missing source boundary: %s\n' "$repo_root/$source" >&2
    exit 1
  fi

  source_input="$source"
  if [[ "$source" == *.gz ]]; then
    source_input="/vsigzip/$source"
  fi

  raw_path="$work_dir/$selected_polygon-raw.gpkg"
  outer_path="$work_dir/$selected_polygon-outer.gpkg"
  candidate_path="$output_dir/$selected_polygon-conservative.geojson"

  printf 'Converting %s from %s\n' "$selected_polygon" "$source"

  # Project to metres and split every multipolygon into independently usable parts.
  ogr2ogr -overwrite -f GPKG "$raw_path" "$source_input" \
    -nln raw -t_srs EPSG:32632 -explodecollections

  # The app supports one outer ring per .poly file, so intentionally fill holes.
  ogr2ogr -overwrite -f GPKG "$outer_path" "$raw_path" \
    -nln outer -dialect sqlite \
    -sql 'SELECT ST_MakePolygon(ST_ExteriorRing(geom)) AS geom FROM raw'

  # Buffer before and after simplification so the candidate favors inclusion.
  ogr2ogr -overwrite -f GeoJSON "$candidate_path" "$outer_path" \
    -nln candidate -t_srs EPSG:4326 -dialect sqlite \
    -sql "SELECT ST_Buffer(ST_SimplifyPreserveTopology(ST_Buffer(geom, $outward_buffer_meters), $simplify_meters), $final_buffer_meters) AS geom FROM outer"

  python3 - "$candidate_path" "$output_dir" "$selected_polygon" <<'PY'
import json
import sys
from pathlib import Path

source_path = Path(sys.argv[1])
output_dir = Path(sys.argv[2])
prefix = sys.argv[3]
data = json.loads(source_path.read_text())
polygons = []

for feature in data['features']:
    geometry = feature['geometry']
    if geometry['type'] == 'Polygon':
        polygons.append(geometry['coordinates'][0])
    elif geometry['type'] == 'MultiPolygon':
        polygons.extend(polygon[0] for polygon in geometry['coordinates'])
    else:
        raise ValueError(f"Unexpected geometry type: {geometry['type']}")

for index, ring in enumerate(polygons, start=1):
    if ring[0] == ring[-1]:
        ring = ring[:-1]
    if len(ring) < 3:
        raise ValueError(f'Polygon part {index} has fewer than three vertices.')

    path = output_dir / f'{prefix}-{index}.poly'
    lines = ['none', '1']
    lines.extend(f'{longitude:.7f} {latitude:.7f}' for longitude, latitude in ring)
    lines.extend(['END', 'END', ''])
    path.write_text('\n'.join(lines))
    print(f'Wrote {path}')
PY
}

cd "$repo_root"
for selected_polygon in "${selected_polygons[@]}"; do
  convert_polygon "$selected_polygon"
done

printf 'Review candidates in %s before copying files into assets/polygons.\n' "$output_dir"
