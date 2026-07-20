#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/_common.sh"

"$script_dir/prepare_smoke_fixture.sh"

docker compose -f "$stack_dir/docker-compose.yml" up -d

printf 'Tasmania local topo stack started on http://127.0.0.1:%s\n' "${LOCAL_TOPO_PORT:-8090}"
