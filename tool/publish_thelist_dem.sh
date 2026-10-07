#!/usr/bin/env bash
set -euo pipefail

# Internal worker: the first operand is always resolver-owned Mapping staging.
# The optional second operand is a checked non-store preparation VRT.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
output_path="${1:?Resolver-staged output is required}"
source_path="${2:-$repo_root/build/dem/thelist_25m/tasmania_dem_25m.vrt}"
dart run "$repo_root/tool/non_store_paths.dart" "$source_path"
exec gdal_translate "$source_path" "$output_path" \
  --config GDAL_PAM_ENABLED NO \
  -co TILED=YES -co COMPRESS=DEFLATE -co BIGTIFF=IF_SAFER
