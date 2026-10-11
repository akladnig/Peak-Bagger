#!/bin/bash
# Run with Bash on macOS. Write operations require --execute.
set -euo pipefail

command_name="${1:-preflight}"
if [ "$#" -gt 0 ]; then shift; fi
destination="$HOME/Services/peak-bagger"
source_disk="/Volumes/Services/docker/DockerDesktop/Docker.raw"
source_topo="/Volumes/Development/mapping/peak_bagger/local_topo/tasmania"
source_mapping="/Volumes/Services/Mapping"
source_version="4.94.0"
target_hostname="mac-mini"
execute=0
with_overpass=0

fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage() {
  printf '%s\n' \
    'Usage: bash tool/migrate_docker_to_mini.sh COMMAND [OPTIONS]' \
    '' \
    'Commands:' \
    '  preflight    Read-only inventory; works on either Mac.' \
    '  stop-source  Stop all source containers and Docker Desktop on the MacBook.' \
    '  copy         On the Mini, copy to internal SSD or retry the same partial bundle.' \
    '  restore      On the Mini, restore the copied VM disk; back up any existing disk.' \
    '  start        Start Docker Desktop and the internally stored topo stack.' \
    '  verify       Check container bind mounts, capabilities, and sample tiles.' \
    '' \
    'Options:' \
    '  --execute                  Perform a write command; otherwise print its plan.' \
    '  --destination PATH         Default: ~/Services/peak-bagger' \
    '  --source-disk PATH         Default: /Volumes/Services/docker/DockerDesktop/Docker.raw' \
    '  --source-topo PATH         Default: external-drive local_topo/tasmania directory' \
    '  --source-mapping PATH      Default: /Volumes/Services/Mapping' \
    '  --source-version VERSION   Default: audited Docker Desktop version 4.94.0' \
    '  --target-hostname NAME     Required target LocalHostName; default: mac-mini' \
    '  --with-overpass             Also copy Overpass configuration/data; keep it stopped.' \
    '  --help'
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --execute) execute=1; shift ;;
    --with-overpass) with_overpass=1; shift ;;
    --destination|--source-disk|--source-topo|--source-mapping|--source-version|--target-hostname)
      [ "$#" -ge 2 ] && [ -n "$2" ] || fail "$1 requires a value"
      case "$1" in
        --destination) destination="$2" ;;
        --source-disk) source_disk="$2" ;;
        --source-topo) source_topo="$2" ;;
        --source-mapping) source_mapping="$2" ;;
        --source-version) source_version="$2" ;;
        --target-hostname) target_hostname="$2" ;;
      esac
      shift 2 ;;
    --help) usage; exit 0 ;;
    *) fail "Unknown option: $1" ;;
  esac
done
case "$command_name" in
  preflight|stop-source|copy|restore|start|verify) ;;
  help|--help|-h) usage; exit 0 ;;
  *) fail "Unknown command: $command_name" ;;
esac
[ "$(uname -s)" = Darwin ] || fail 'This script requires macOS.'
[ "$(uname -m)" = arm64 ] || fail 'This audited migration requires an Apple Silicon Mac.'
case "$destination" in /*) ;; *) fail '--destination must be an absolute path.' ;; esac

docker_cli() {
  local candidate
  for candidate in /Applications/Docker.app/Contents/Resources/bin/docker \
    "$HOME/Applications/Docker.app/Contents/Resources/bin/docker" \
    /opt/homebrew/bin/docker /usr/local/bin/docker; do
    if [ -x "$candidate" ]; then printf '%s\n' "$candidate"; return; fi
  done
  command -v docker || return 1
}

desktop_version() {
  local app
  for app in /Applications/Docker.app "$HOME/Applications/Docker.app"; do
    if [ -f "$app/Contents/Info.plist" ]; then
      /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$app/Contents/Info.plist"
      return
    fi
  done
  return 1
}

disk_location() {
  local settings="$HOME/Library/Group Containers/group.com.docker/settings-store.json"
  local folder=""
  if [ -f "$settings" ]; then
    folder="$(/usr/bin/plutil -extract DataFolder raw -o - "$settings" 2>/dev/null || true)"
  fi
  if [ -n "$folder" ]; then
    printf '%s/Docker.raw\n' "${folder%/}"
  else
    printf '%s/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw\n' "$HOME"
  fi
}

require_stopped() {
  if /usr/bin/pgrep -f '(^|/)com\.docker\.backend([[:space:]]|$)' >/dev/null; then
    fail 'Docker Desktop is running. Fully quit it before copying or restoring its disk.'
  fi
}

require_target() {
  local actual_hostname
  actual_hostname="$(/usr/sbin/scutil --get LocalHostName)"
  [ "$actual_hostname" = "$target_hostname" ] \
    || fail "Run $command_name on the Mini: expected LocalHostName '$target_hostname', got '$actual_hostname'. No files were changed."
}

require_internal() {
  local path="$1"
  while [ ! -e "$path" ]; do path="$(dirname "$path")"; done
  local internal device
  device="$(df -P "$path" | while read -r filesystem rest; do
    if [[ "$filesystem" == /dev/* ]]; then printf '%s\n' "$filesystem"; fi
  done)"
  [ -n "$device" ] || fail "Cannot identify the filesystem containing $1."
  internal="$(/usr/sbin/diskutil info -plist "$device" | /usr/bin/plutil -extract Internal raw -o - -)"
  [ "$internal" = true ] || fail "$1 must be on the internal SSD."
}

allocated_kib() {
  local output size rest
  output="$(/usr/bin/du -sk "$1")"
  read -r size rest <<< "$output"
  printf '%s\n' "$size"
}

require_space() {
  local path="$destination" available required
  while [ ! -e "$path" ]; do path="$(dirname "$path")"; done
  available="$(df -Pk "$path" | while read -r filesystem total used free rest; do
    if [[ "$filesystem" == /dev/* ]]; then printf '%s\n' "$free"; fi
  done)"
  # Source allocation does not bound rsync's destination/temporary allocation.
  # Budget the whole VM disk's logical size even when it is sparse on the source.
  local logical_bytes
  logical_bytes="$(/usr/bin/stat -f '%z' "$source_disk")"
  required=$(((logical_bytes + 1023) / 1024 + $(allocated_kib "$source_topo") + 10 * 1024 * 1024))
  if [ "$with_overpass" = 1 ]; then required=$((required + $(allocated_kib "$source_mapping/overpass-data"))); fi
  [ -n "$available" ] && [ "$available" -ge "$required" ] \
    || fail "Insufficient free space: need $required KiB including 10 GiB headroom."
  printf 'Copy space check: %s KiB needed; %s KiB available.\n' "$required" "$available"
  printf 'VM disk budget uses its full logical size (%s bytes), not source allocated space.\n' "$logical_bytes"
}

require_bundle() {
  [ -f "$destination/migration-version.txt" ] || fail 'No completed migration bundle. Run copy first.'
  [ -f "$destination/topo/tasmania/docker-compose.yml" ] || fail 'Copied topo stack is missing.'
}

report_copy_failure() {
  local status="$?"
  if [ "$status" -ne 0 ]; then
    printf 'ERROR: Copy failed during %s (exit %s). Partial files retained at %s.partial.\n' \
      "$copy_stage" "$status" "$destination" >&2
    printf 'Retry copy with the same --destination and source/Overpass options; no new path is needed.\n' >&2
  fi
}

run_docker() {
  local cli
  cli="$(docker_cli)" || fail 'Docker Desktop is not installed.'
  env -u DOCKER_HOST DOCKER_CONTEXT=desktop-linux "$cli" "$@"
}

verify_stack() {
  local service sources
  for service in gateway tileserver postgis martin; do
    [ "$(run_docker inspect --format '{{.State.Running}}' "tasmania-$service-1")" = true ] \
      || fail "$service is not running."
    sources="$(run_docker inspect --format '{{range .Mounts}}{{if eq .Type "bind"}}{{println .Source}}{{end}}{{end}}' "tasmania-$service-1")"
    printf '%s bind mounts:\n%s\n' "$service" "$sources"
    if [[ "$sources" == *'/Volumes/'* ]]; then
      fail "$service still depends on an external volume. Recreate it from the internal stack."
    fi
  done
  /usr/bin/curl --fail --silent --show-error --max-time 20 http://127.0.0.1:8090/capabilities
  printf '\n'
  local route
  for route in local-topo terrain-relief-shading contour-lines; do
    /usr/bin/curl --fail --silent --show-error --max-time 60 -o /dev/null \
      -w "$route: HTTP %{http_code}, %{size_download} bytes\n" \
      "http://127.0.0.1:8090/tasmania/$route/0/0/0.png"
  done
}

if [ "$command_name" = preflight ]; then
  printf 'Host: %s\nArchitecture: %s\nRAM bytes: %s\n' \
    "$(hostname)" "$(uname -m)" "$(sysctl -n hw.memsize)"
  printf 'LocalHostName: %s\nRequired migration target: %s\n' \
    "$(/usr/sbin/scutil --get LocalHostName)" "$target_hostname"
  printf 'Docker Desktop: %s\nConfigured VM disk: %s\n' \
    "$(desktop_version || printf 'not installed')" "$(disk_location)"
  if cli="$(docker_cli)"; then
    env -u DOCKER_HOST DOCKER_CONTEXT=desktop-linux "$cli" version || true
  fi
  df -h /System/Volumes/Data
  for path in "$source_disk" "$source_topo" "$source_mapping/overpass-data"; do
    if [ -e "$path" ]; then /usr/bin/du -sh "$path"; else printf 'Not attached/present: %s\n' "$path"; fi
  done
  if [ -f "$source_disk" ]; then
    /usr/bin/stat -f 'VM disk logical bytes: %z; allocated 512-byte blocks: %b' "$source_disk"
  fi
  exit 0
fi

if [ "$command_name" = verify ]; then verify_stack; exit 0; fi

if [ "$execute" -ne 1 ]; then
  printf 'PLAN ONLY on %s. Add --execute to perform this command.\n' "$(hostname)"
  case "$command_name" in
    stop-source) printf 'Stop all running containers, then stop Docker Desktop.\n' ;;
    copy)
      printf 'On target %s, sparse-copy %s and %s to %s; reuse %s.partial if present.\n' "$target_hostname" "$source_disk" "$source_topo" "$destination" "$destination"
      if [ "$with_overpass" = 1 ]; then printf 'Also copy %s/docker-compose.yml and overpass-data.\n' "$source_mapping"; fi ;;
    restore) printf 'Back up the existing configured Docker disk, then move the copied disk into %s.\n' "$(disk_location)" ;;
    start) printf 'Start Docker Desktop; recreate project tasmania from %s/topo/tasmania; verify it.\n' "$destination" ;;
  esac
  exit 0
fi

case "$command_name" in
  stop-source)
    [ -f "$source_disk" ] || fail 'Source Docker disk is missing.'
    [ "$(disk_location)" = "$source_disk" ] || fail 'This Mac is not configured to use the source Docker disk.'
    containers=()
    while IFS= read -r id; do [ -z "$id" ] || containers+=("$id"); done < <(run_docker ps -q)
    # Query again outside process substitution so connection failures abort.
    run_docker info >/dev/null
    if [ "${#containers[@]}" -gt 0 ]; then run_docker stop --time 120 "${containers[@]}"; fi
    "$(docker_cli)" desktop stop
    for ((attempt=0; attempt<60; attempt++)); do
      if ! /usr/bin/pgrep -f '(^|/)com\.docker\.backend([[:space:]]|$)' >/dev/null; then
        printf 'Docker Desktop stopped. Close apps using the drive, then eject it.\n'; exit 0
      fi
      sleep 2
    done
    fail 'Docker backend did not stop; do not detach the drive.' ;;
  copy)
    require_target
    require_internal "$destination"
    [ -f "$source_disk" ] || fail 'Attach the source drive first.'
    [ -f "$source_topo/docker-compose.yml" ] || fail 'Source topo stack is missing.'
    [ ! -e "$destination" ] && [ ! -L "$destination" ] || fail 'Destination already exists; choose a new bundle path.'
    [ ! -L "$destination.partial" ] || fail 'Partial bundle is a symbolic link; refusing to follow it.'
    if [ -e "$destination.partial" ]; then
      [ -d "$destination.partial" ] || fail 'Partial bundle is not a directory.'
      printf 'Retrying existing partial bundle at %s.partial.\n' "$destination"
    fi
    # Do not follow redirected staging directories when reusing a partial bundle.
    for path in docker topo topo/tasmania overpass overpass/overpass-data; do
      [ ! -L "$destination.partial/$path" ] || fail "Partial bundle directory $path is a symbolic link."
      if [ -e "$destination.partial/$path" ]; then
        [ -d "$destination.partial/$path" ] || fail "Partial bundle path $path is not a directory."
      fi
    done
    [ ! -L "$destination.partial/migration-version.txt" ] || fail 'Partial bundle version marker is a symbolic link.'
    if [ "$with_overpass" = 1 ]; then
      [ -f "$source_mapping/docker-compose.yml" ] && [ -d "$source_mapping/overpass-data" ] || fail 'Overpass sources are missing.'
    fi
    require_space
    require_stopped
    source_stamp="$(/usr/bin/stat -f '%z:%m' "$source_disk")"
    copy_stage='creating staging directories'
    trap report_copy_failure EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    mkdir -p "$destination.partial/docker" "$destination.partial/topo/tasmania"
    printf 'Copying into %s.partial; rsync -S preserves sparse regions and --partial retains interrupted files.\n' "$destination"
    copy_stage='Docker VM disk copy'
    /usr/bin/rsync -aS --partial --progress "$source_disk" "$destination.partial/docker/Docker.raw"
    copy_stage='topo stack copy'
    /usr/bin/rsync -aS --partial --progress "$source_topo/" "$destination.partial/topo/tasmania/"
    if [ "$with_overpass" = 1 ]; then
      copy_stage='Overpass configuration copy'
      mkdir -p "$destination.partial/overpass/overpass-data"
      /usr/bin/rsync -aS --partial --progress "$source_mapping/docker-compose.yml" "$destination.partial/overpass/"
      copy_stage='Overpass data copy'
      # Archive mode includes runtime sockets/FIFOs, which are not database data.
      # macOS openrsync can fail with mkstempsock on the dispatcher socket paths.
      printf 'Copying Overpass database files; skipping runtime sockets, FIFOs, and devices.\n'
      /usr/bin/rsync -aS --no-specials --no-devices --partial --progress \
        "$source_mapping/overpass-data/" "$destination.partial/overpass/overpass-data/"
    fi
    copy_stage='VM disk validation'
    [ "$source_stamp" = "$(/usr/bin/stat -f '%z:%m' "$source_disk")" ] || fail 'Source disk changed during copying; bundle remains partial.'
    [ "$(/usr/bin/stat -f '%z' "$source_disk")" = "$(/usr/bin/stat -f '%z' "$destination.partial/docker/Docker.raw")" ] || fail 'Copied VM disk size differs; bundle remains partial.'
    copy_stage='bundle finalization'
    printf '%s\n' "$source_version" > "$destination.partial/migration-version.txt"
    mv "$destination.partial" "$destination"
    trap - EXIT INT TERM
    /usr/bin/du -sh "$destination"
    printf 'Copy complete. Source files were retained. Next: restore.\n' ;;
  restore)
    require_bundle
    require_target
    require_stopped
    require_internal "$destination"
    IFS= read -r expected_version < "$destination/migration-version.txt"
    installed_version="$(desktop_version)" || fail "Install Docker Desktop $expected_version first."
    [ "$installed_version" = "$expected_version" ] || fail "Expected Docker Desktop $expected_version; installed $installed_version."
    copied_disk="$destination/docker/Docker.raw"
    [ -f "$copied_disk" ] || fail 'Copied disk is missing or already restored.'
    target_disk="$(disk_location)"
    require_internal "$target_disk"
    [ ! -L "$target_disk" ] || fail 'Target disk is a symbolic link; inspect its storage location first.'
    mkdir -p "$(dirname "$target_disk")"
    backup=""
    if [ -e "$target_disk" ]; then
      backup="$target_disk.before-peak-bagger-$(date +%Y%m%d-%H%M%S)-$$"
      mv "$target_disk" "$backup"
      printf 'Existing target disk retained at %s\n' "$backup"
    fi
    if ! mv "$copied_disk" "$target_disk"; then
      if [ -n "$backup" ]; then mv "$backup" "$target_disk"; fi
      fail 'Restore failed; existing target disk restored if one was present.'
    fi
    printf '%s\n' "$target_disk" > "$destination/restored-disk.txt"
    printf 'VM disk restored to %s. Next: start.\n' "$target_disk" ;;
  start)
    require_bundle
    require_target
    require_internal "$destination"
    [ -f "$destination/restored-disk.txt" ] || fail 'Run restore first.'
    IFS= read -r restored_disk < "$destination/restored-disk.txt"
    [ "$restored_disk" = "$(disk_location)" ] && [ -f "$restored_disk" ] || fail 'Docker disk location changed after restore.'
    cli="$(docker_cli)" || fail 'Docker Desktop is not installed.'
    "$cli" desktop start
    ready=0
    for ((attempt=0; attempt<60; attempt++)); do
      if run_docker info >/dev/null 2>&1; then ready=1; break; fi
      sleep 2
    done
    [ "$ready" = 1 ] || fail 'Docker Desktop did not become ready.'
    # Restored unless-stopped policies can resurrect old Overpass containers.
    # Disable those policies on the target and stop them before serving topo.
    mapping_ids="$(run_docker ps -aq --filter label=com.docker.compose.project=mapping)"
    while IFS= read -r id; do
      if [ -n "$id" ]; then
        run_docker update --restart=no "$id"
        run_docker stop --time 120 "$id"
      fi
    done <<< "$mapping_ids"
    env -u DOCKER_HOST DOCKER_CONTEXT=desktop-linux COMPOSE_PROJECT_NAME=tasmania \
      LOCAL_TOPO_DOCKER_BIN="$cli" LOCAL_TOPO_PORT=8090 \
      /bin/bash "$destination/topo/tasmania/scripts/start_stack.sh" --mode=preview
    verify_stack
    printf 'Topo is serving from internal storage on port 8090. Restored Overpass containers are stopped.\n' ;;
esac
