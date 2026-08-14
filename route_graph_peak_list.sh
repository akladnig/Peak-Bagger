#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_path='tool/route_graph_peak_list.dart'
binary_path="$script_dir/build/macos/Build/Products/Release/peak_bagger.app/Contents/MacOS/peak_bagger"
build_stamp_path="$script_dir/build/macos/Build/Products/Release/.route_graph_peak_list_cli_build_stamp"
target_identity_path="$script_dir/build/macos/Build/Products/Release/.peak_bagger_cli_target"

cd "$script_dir"

if [ -n "${PEAK_BAGGER_ROUTE_GRAPH_TOOL_BINARY:-}" ]; then
  exec "${PEAK_BAGGER_ROUTE_GRAPH_TOOL_BINARY}" "$@"
fi

needs_build() {
  if [ ! -x "$binary_path" ] || [ ! -f "$build_stamp_path" ] || [ ! -f "$target_identity_path" ]; then
    return 0
  fi

  if [ "$(<"$target_identity_path")" != "$target_path" ]; then
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
      "$script_dir/macos/Runner" \
      "$script_dir/macos/Runner.xcodeproj" \
      "$script_dir/macos/Runner.xcworkspace" \
      -type f \
      \( -name '*.dart' -o -name '*.swift' -o -name '*.plist' -o -name '*.xcconfig' -o -name '*.pbxproj' -o -name '*.xcscheme' -o -name '*.xcworkspacedata' \) \
      -print0
  )

  local metadata_file
  for metadata_file in \
    "$script_dir/pubspec.yaml" \
    "$script_dir/pubspec.lock" \
    "$script_dir/macos/Podfile" \
    "$script_dir/macos/Podfile.lock"; do
    if [ -f "$metadata_file" ] && [ "$(stat -f %m "$metadata_file")" -gt "$build_stamp_mtime" ]; then
      return 0
    fi
  done

  return 1
}

if needs_build; then
  "${PEAK_BAGGER_ROUTE_GRAPH_FLUTTER_BINARY:-flutter}" build macos --release -t "$target_path"
  mkdir -p "$(dirname "$build_stamp_path")"
  touch "$build_stamp_path"
  printf '%s\n' "$target_path" > "$target_identity_path"
fi

exec "$binary_path" "$@"
