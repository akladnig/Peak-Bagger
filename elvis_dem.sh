#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

if [ -n "${PEAK_BAGGER_ELVIS_DEM_TOOL_BINARY:-}" ]; then
  exec "${PEAK_BAGGER_ELVIS_DEM_TOOL_BINARY}" "$@"
fi

binary_path="$script_dir/build/tool/elvis_dem"
build_stamp_path="$script_dir/build/tool/.elvis_dem_cli_build_stamp"

resolve_dart() {
  if command -v dart >/dev/null 2>&1; then
    command -v dart
    return 0
  fi

  if command -v flutter >/dev/null 2>&1; then
    local flutter_bin
    local flutter_dir
    local dart_candidate
    flutter_bin="$(command -v flutter)"
    flutter_dir="$(cd "$(dirname "$flutter_bin")" && pwd)"
    dart_candidate="$flutter_dir/dart"
    if [ -x "$dart_candidate" ]; then
      printf '%s\n' "$dart_candidate"
      return 0
    fi
  fi

  printf 'Unable to locate the Dart SDK. Ensure `dart` or `flutter` is available on PATH.\n' >&2
  return 1
}

dart_bin="$(resolve_dart)"

needs_build() {
  if [ ! -x "$binary_path" ] || [ ! -f "$build_stamp_path" ]; then
    return 0
  fi

  local build_stamp_mtime
  build_stamp_mtime="$(stat -f %m "$build_stamp_path")"

  local path
  while IFS= read -r -d '' path; do
    if [ "$(stat -f %m "$path")" -gt "$build_stamp_mtime" ]; then
      return 0
    fi
  done < <(
    find \
      "$script_dir/tool" \
      "$script_dir/lib" \
      -type f \
      \( -name '*.dart' \) \
      -print0
  )

  local metadata_file
  for metadata_file in \
    "$script_dir/pubspec.yaml" \
    "$script_dir/pubspec.lock"; do
    if [ -f "$metadata_file" ] && [ "$(stat -f %m "$metadata_file")" -gt "$build_stamp_mtime" ]; then
      return 0
    fi
  done

  return 1
}

if needs_build; then
  (
    cd "$script_dir"
    mkdir -p "$(dirname "$binary_path")"
    "$dart_bin" compile exe tool/elvis_dem.dart -o "$binary_path"
    touch "$build_stamp_path"
  )
fi

exec "$binary_path" "$@"
