#!/usr/bin/env bash
set -euo pipefail

csv_path="peak-bagger-peak-data.csv"
create_unmatched_peaks="false"
progress_file="$(mktemp "${TMPDIR:-/tmp}/peakbagger-progress.XXXXXX")"

for arg in "$@"; do
  if [ "$arg" = "--create-unmatched-peaks" ]; then
    create_unmatched_peaks="true"
  else
    csv_path="$arg"
  fi
done

tail -f "$progress_file" &
tail_pid=$!

cleanup() {
  kill "$tail_pid" >/dev/null 2>&1 || true
  wait "$tail_pid" >/dev/null 2>&1 || true
  rm -f "$progress_file"
}

trap cleanup EXIT INT TERM

if [ "$create_unmatched_peaks" = "true" ]; then
  PEAKBAGGER_PROGRESS_FILE="$progress_file" dart run tool/sync_peakbagger_csv.dart --create-unmatched-peaks "$csv_path"
else
  PEAKBAGGER_PROGRESS_FILE="$progress_file" dart run tool/sync_peakbagger_csv.dart "$csv_path"
fi
