#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/local_slovenia_proxy.sh"

stop_managed_proxy >/dev/null 2>&1 || true
start_managed_proxy
